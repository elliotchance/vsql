/* setup */
CREATE TABLE t1 (x INT, y VARCHAR(10));
CREATE TABLE t2 (x BIGINT, z VARCHAR(20));
CREATE TABLE t3 (x INT);
INSERT INTO t1 (x, y) VALUES (1, 'a'), (2, 'b'), (2, 'b'), (3, NULL), (3, NULL);
INSERT INTO t2 (x, z) VALUES (2, 'b'), (3, NULL), (4, 'd');
CREATE SEQUENCE seq1;

-- # INTERSECT (and INTERSECT DISTINCT) keeps one of each row that's on both
-- # sides, where NULLs are not distinct (F303).
SELECT x, y FROM t1 INTERSECT SELECT x, z FROM t2;
-- X: 2 Y: b
-- X: 3 Y: NULL

SELECT x, y FROM t1 INTERSECT DISTINCT SELECT x, z FROM t2;
-- X: 2 Y: b
-- X: 3 Y: NULL

SELECT y FROM t1 INTERSECT SELECT z FROM t2;
-- Y: b
-- Y: NULL

-- # Duplicates are removed from the left as well.
SELECT x FROM t1 INTERSECT SELECT x FROM t1;
-- X: 1
-- X: 2
-- X: 3

VALUES 2, 2, 2, 3 INTERSECT DISTINCT SELECT x FROM t1;
-- COL1: 2
-- COL1: 3

-- # No rows are on both sides.
SELECT x FROM t1 INTERSECT SELECT x FROM t2 WHERE x > 10;

VALUES 5 INTERSECT SELECT x FROM t1;

-- # INTERSECT ALL keeps the smaller number of duplicates of each row (F305).
SELECT x FROM t1 INTERSECT ALL VALUES 2, 2, 2, 3;
-- X: 2
-- X: 2
-- X: 3

VALUES 2, 2, 2, 3 INTERSECT ALL SELECT x FROM t1;
-- COL1: 2
-- COL1: 2
-- COL1: 3

SELECT x, y FROM t1 INTERSECT ALL SELECT x, y FROM t1;
-- X: 1 Y: a
-- X: 2 Y: b
-- X: 2 Y: b
-- X: 3 Y: NULL
-- X: 3 Y: NULL

SELECT y FROM t1 INTERSECT ALL SELECT z FROM t2;
-- Y: b
-- Y: NULL

-- # INTERSECT is evaluated before UNION and EXCEPT, on either side.
VALUES 1, 2 UNION VALUES 3 INTERSECT VALUES 4;
-- COL1: 1
-- COL1: 2

VALUES 1 EXCEPT VALUES 1, 2 INTERSECT VALUES 2;
-- COL1: 1

VALUES 3 INTERSECT VALUES 3 UNION VALUES 4;
-- COL1: 3
-- COL1: 4

VALUES 1, 2 INTERSECT VALUES 2, 3 EXCEPT VALUES 2, 3 INTERSECT VALUES 3;
-- COL1: 2

-- # INTERSECT operators are evaluated left to right.
VALUES 1, 1, 2 INTERSECT ALL VALUES 1, 1, 2, 2 INTERSECT ALL VALUES 1, 2, 2;
-- COL1: 1
-- COL1: 2

-- # Parentheses change the order.
(VALUES 1, 2 UNION VALUES 3) INTERSECT VALUES 2, 3, 4;
-- COL1: 2
-- COL1: 3

VALUES 1, 2 INTERSECT (VALUES 2 UNION VALUES 1) EXCEPT VALUES 1;
-- COL1: 2

-- # Each column has the combined type of both sides.
VALUES 1 INTERSECT VALUES 1.0;
-- COL1: 1.0

/* types */
SELECT x FROM t1 INTERSECT SELECT x FROM t2;
-- X: 2 (BIGINT)
-- X: 3 (BIGINT)

/* types */
SELECT y FROM t1 INTERSECT ALL SELECT z FROM t2;
-- Y: b (CHARACTER VARYING(20))
-- Y: NULL (CHARACTER VARYING(20))

-- # Values are duplicates if they're equal with =, so trailing spaces are
-- # ignored.
VALUES CAST('a' AS CHAR(3)) INTERSECT VALUES CAST('a' AS VARCHAR(5));
-- COL1: a

-- # Columns whose types can't be combined are an error (9.5, Syntax Rules,
-- # 3.a.i).
SELECT x FROM t1 INTERSECT SELECT y FROM t1;
-- error 42804: data type mismatch in column 1 of INTERSECT: expected INTEGER but got CHARACTER VARYING(10)

-- # Both sides must have the same number of columns.
SELECT x FROM t1 INTERSECT SELECT x, z FROM t2;
-- error 42601: syntax error: each INTERSECT query must have the same number of columns

-- # The columns are named after the left side.
SELECT x AS a, y FROM t1 INTERSECT SELECT x, z AS b FROM t2;
-- A: 2 Y: b
-- A: 3 Y: NULL

SELECT * FROM t1 INTERSECT SELECT * FROM t2;
-- X: 2 Y: b
-- X: 3 Y: NULL

-- # ORDER BY, OFFSET and FETCH FIRST apply to the whole result.
SELECT x, y FROM t1 INTERSECT SELECT x, z FROM t2 ORDER BY x DESC;
-- X: 3 Y: NULL
-- X: 2 Y: b

SELECT x FROM t1 INTERSECT ALL SELECT x FROM t1 ORDER BY x DESC OFFSET 1 ROW FETCH FIRST 2 ROWS ONLY;
-- X: 3
-- X: 2

SELECT x FROM t1 INTERSECT SELECT x FROM t2 ORDER BY z;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.Z

-- # Each side can have its own ORDER BY, OFFSET and FETCH FIRST.
(SELECT x FROM t1 ORDER BY x DESC FETCH FIRST 1 ROW ONLY) INTERSECT (SELECT x FROM t2 ORDER BY x OFFSET 1 ROW);
-- X: 3

-- # In a subquery.
SELECT * FROM (SELECT x FROM t1 INTERSECT SELECT x FROM t2) AS t ORDER BY x DESC;
-- X: 3
-- X: 2

SELECT t.a FROM (SELECT x, y FROM t1 INTERSECT ALL SELECT x, z FROM t2) AS t (a, b);
-- A: 2
-- A: 3

SELECT COUNT(*) FROM (SELECT x FROM t1 INTERSECT ALL SELECT x FROM t1) AS t;
-- COL1: 5

VALUES 2 IN (SELECT x FROM t1 INTERSECT SELECT x FROM t2);
-- COL1: TRUE

VALUES 1 IN (SELECT x FROM t1 INTERSECT SELECT x FROM t2);
-- COL1: FALSE

VALUES EXISTS (SELECT x FROM t1 INTERSECT SELECT x FROM t2 WHERE x = 4);
-- COL1: FALSE

-- # EXPLAIN shows each side as a numbered subplan. INTERSECT binds tighter, so
-- # it's nested under the UNION.
/* extensions V001-01 */
EXPLAIN SELECT x FROM t1 INTERSECT ALL SELECT x FROM t2 ORDER BY x;
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.T1 (X INTEGER, Y CHARACTER VARYING(10))
-- EXPLAIN:   EXPR (X INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.T2 (X BIGINT, Z CHARACTER VARYING(20))
-- EXPLAIN:   EXPR (X BIGINT)
-- EXPLAIN: INTERSECT ALL (X BIGINT)
-- EXPLAIN: ORDER BY X ASC

/* extensions V001-01 */
EXPLAIN VALUES 1 UNION VALUES 2 INTERSECT VALUES 3;
-- EXPLAIN: $1:
-- EXPLAIN:   VALUES (COL1 SMALLINT) = ROW(1)
-- EXPLAIN: $2:
-- EXPLAIN:   $1:
-- EXPLAIN:     VALUES (COL1 SMALLINT) = ROW(2)
-- EXPLAIN:   $2:
-- EXPLAIN:     VALUES (COL1 SMALLINT) = ROW(3)
-- EXPLAIN:   INTERSECT DISTINCT (COL1 SMALLINT)
-- EXPLAIN: UNION DISTINCT (COL1 SMALLINT)

-- # A query that's printed keeps the parentheses around a UNION or EXCEPT on
-- # either side of an INTERSECT, and adds them around an INTERSECT under a
-- # UNION. DISTINCT is left out, as it's the default (Syntax Rules, 6).
/* extensions V001-01 */
EXPLAIN VALUES EXISTS ((VALUES 1 UNION VALUES 2) INTERSECT ALL VALUES 2 INTERSECT (VALUES 3 EXCEPT VALUES 4) UNION VALUES 5 INTERSECT DISTINCT VALUES 5);
-- EXPLAIN: VALUES (COL1 BOOLEAN) = ROW(EXISTS ((VALUES 1 UNION VALUES 2) INTERSECT ALL VALUES 2 INTERSECT (VALUES 3 EXCEPT VALUES 4) UNION (VALUES 5 INTERSECT VALUES 5)))

-- # In an INSERT.
INSERT INTO t3 SELECT x FROM t1 INTERSECT SELECT x FROM t2;
INSERT INTO t3 (x) VALUES 10, 11 INTERSECT VALUES 11, 12;
INSERT INTO t3 VALUES 20, 21 INTERSECT ALL VALUES 20, 21 INTERSECT VALUES 21 UNION VALUES 22;
INSERT INTO t3 SELECT x FROM t1 INTERSECT ALL SELECT x FROM t1 ORDER BY x DESC FETCH FIRST 1 ROW ONLY;
SELECT * FROM t3;
-- msg: INSERT 2
-- msg: INSERT 1
-- msg: INSERT 2
-- msg: INSERT 1
-- X: 2
-- X: 3
-- X: 11
-- X: 21
-- X: 22
-- X: 3

-- # A cursor for an INTERSECT can't be updated.
/* extensions V108-01 */
DECLARE c CURSOR FOR SELECT x FROM t1 INTERSECT SELECT x FROM t2 FOR UPDATE;
-- error 42601: syntax error: cursor C is not updatable

-- # NEXT VALUE FOR can't be used on either side. No value is used.
SELECT NEXT VALUE FOR seq1 FROM t2 INTERSECT SELECT x FROM t2;
SELECT x FROM t2 UNION (SELECT x FROM t2 INTERSECT SELECT NEXT VALUE FOR seq1 FROM t2);
SELECT NEXT VALUE FOR seq1 FROM t2;
-- error 42601: syntax error: NEXT VALUE FOR cannot be used in INTERSECT
-- error 42601: syntax error: NEXT VALUE FOR cannot be used in UNION
-- COL1: 1
-- COL1: 2
-- COL1: 3

-- # An error from either side.
SELECT x FROM t1 INTERSECT SELECT 1 / 0 FROM t2;
-- error 22012: division by zero

-- # INTERSECT is flagged with F303, INTERSECT ALL also with F305 and INTERSECT
-- # DISTINCT also with T551.
/* flags */
SELECT x FROM t1 INTERSECT SELECT x FROM t2;
-- flags: F303
-- X: 2
-- X: 3

/* flags */
SELECT x FROM t1 INTERSECT DISTINCT SELECT x FROM t2;
-- flags: F303, T551
-- X: 2
-- X: 3

/* flags */
SELECT x FROM t1 INTERSECT ALL SELECT x FROM t2;
-- flags: F303, F305
-- X: 2
-- X: 3

/* flags */
SELECT x FROM t1 UNION SELECT x FROM t1 INTERSECT DISTINCT SELECT x FROM t2;
-- flags: F303, T551
-- X: 1
-- X: 2
-- X: 3
