/* setup */
CREATE TABLE t1 (x INT, y VARCHAR(10));
CREATE TABLE t2 (x BIGINT, z VARCHAR(20));
INSERT INTO t1 (x, y) VALUES (1, 'a'), (2, 'b'), (2, 'b'), (3, NULL), (3, NULL);
INSERT INTO t2 (x, z) VALUES (2, 'b'), (3, NULL), (4, 'd');
CREATE SEQUENCE seq1;

-- # UNION ALL keeps every row, the left rows first (E071-02).
SELECT x, y FROM t1 UNION ALL SELECT x, z FROM t2;
-- X: 1 Y: a
-- X: 2 Y: b
-- X: 2 Y: b
-- X: 3 Y: NULL
-- X: 3 Y: NULL
-- X: 2 Y: b
-- X: 3 Y: NULL
-- X: 4 Y: d

-- # UNION (and UNION DISTINCT) keeps one of each row, where NULLs are not distinct (E071-01).
SELECT x, y FROM t1 UNION SELECT x, z FROM t2;
-- X: 1 Y: a
-- X: 2 Y: b
-- X: 3 Y: NULL
-- X: 4 Y: d

SELECT x, y FROM t1 UNION DISTINCT SELECT x, z FROM t2;
-- X: 1 Y: a
-- X: 2 Y: b
-- X: 3 Y: NULL
-- X: 4 Y: d

SELECT y FROM t1 UNION SELECT z FROM t2;
-- Y: a
-- Y: b
-- Y: NULL
-- Y: d

-- # Duplicates are removed from the left as well.
SELECT x FROM t1 UNION SELECT x FROM t1;
-- X: 1
-- X: 2
-- X: 3

-- # EXCEPT (and EXCEPT DISTINCT) keeps one of each left row that isn't on the right (E071-03).
SELECT x, y FROM t1 EXCEPT SELECT x, z FROM t2;
-- X: 1 Y: a

SELECT x FROM t1 EXCEPT DISTINCT VALUES 1;
-- X: 2
-- X: 3

SELECT x FROM t1 EXCEPT SELECT x FROM t1;

-- # EXCEPT ALL removes one left row for each right row (F304).
SELECT x, y FROM t1 EXCEPT ALL SELECT x, z FROM t2;
-- X: 1 Y: a
-- X: 2 Y: b
-- X: 3 Y: NULL

SELECT x FROM t1 EXCEPT ALL VALUES 2, 2, 2, 3;
-- X: 1
-- X: 3

-- # The operators are evaluated left to right.
VALUES 1, 2 UNION VALUES 3 EXCEPT VALUES 1;
-- COL1: 2
-- COL1: 3

VALUES 1, 2 EXCEPT VALUES 1 UNION VALUES 1;
-- COL1: 2
-- COL1: 1

-- # Parentheses change the order.
VALUES 1, 2 UNION (VALUES 3 EXCEPT VALUES 1);
-- COL1: 1
-- COL1: 2
-- COL1: 3

(VALUES 1);
-- COL1: 1

-- # Each column has the combined type of both sides (E071-05).
VALUES 1 UNION ALL VALUES 2.5;
-- COL1: 1.0
-- COL1: 2.5

VALUES 1 UNION VALUES 1.0;
-- COL1: 1.0

/* types */
SELECT x FROM t1 UNION SELECT x FROM t2;
-- X: 1 (BIGINT)
-- X: 2 (BIGINT)
-- X: 3 (BIGINT)
-- X: 4 (BIGINT)

/* types */
SELECT y FROM t1 UNION ALL SELECT z FROM t2;
-- Y: a (CHARACTER VARYING(20))
-- Y: b (CHARACTER VARYING(20))
-- Y: b (CHARACTER VARYING(20))
-- Y: NULL (CHARACTER VARYING(20))
-- Y: NULL (CHARACTER VARYING(20))
-- Y: b (CHARACTER VARYING(20))
-- Y: NULL (CHARACTER VARYING(20))
-- Y: d (CHARACTER VARYING(20))

/* types */
VALUES 1 UNION VALUES 1.5E0;
-- COL1: 1e0 (DOUBLE PRECISION)
-- COL1: 1.5e0 (DOUBLE PRECISION)

-- # Values are duplicates if they're equal with =, so trailing spaces are ignored.
VALUES CAST('a' AS CHAR(3)) UNION VALUES CAST('a' AS VARCHAR(5));
-- COL1: a

SELECT x FROM t1 UNION SELECT y FROM t1;
-- error 42804: data type mismatch in column 1 of UNION: expected INTEGER but got CHARACTER VARYING(10)

VALUES ROW(1, 'a') EXCEPT VALUES ROW('a', 1);
-- error 42804: data type mismatch in column 1 of EXCEPT: expected SMALLINT but got CHARACTER(1)

-- # Both sides must have the same number of columns.
SELECT x FROM t1 UNION SELECT x, z FROM t2;
-- error 42601: syntax error: each UNION query must have the same number of columns

SELECT x, y FROM t1 EXCEPT SELECT x FROM t2;
-- error 42601: syntax error: each EXCEPT query must have the same number of columns

-- # The columns are named after the left side.
SELECT x AS a, y FROM t1 UNION SELECT x, z AS b FROM t2;
-- A: 1 Y: a
-- A: 2 Y: b
-- A: 3 Y: NULL
-- A: 4 Y: d

SELECT x, x FROM t1 UNION SELECT x, x + 1 FROM t2;
-- X: 1 X: 1
-- X: 2 X: 2
-- X: 3 X: 3
-- X: 2 X: 3
-- X: 3 X: 4
-- X: 4 X: 5

-- # ORDER BY, OFFSET and FETCH FIRST apply to the whole result.
SELECT x, y FROM t1 UNION SELECT x, z FROM t2 ORDER BY x DESC;
-- X: 4 Y: d
-- X: 3 Y: NULL
-- X: 2 Y: b
-- X: 1 Y: a

SELECT x, y FROM t1 UNION SELECT x, z FROM t2 ORDER BY y DESC, x OFFSET 1 ROW FETCH FIRST 2 ROWS ONLY;
-- X: 2 Y: b
-- X: 1 Y: a

SELECT x FROM t1 UNION SELECT x FROM t2 ORDER BY x * -1;
-- X: 4
-- X: 3
-- X: 2
-- X: 1

VALUES 2, 1 UNION VALUES 3 ORDER BY COL1;
-- COL1: 1
-- COL1: 2
-- COL1: 3

-- # ORDER BY can only use the columns of the result.
SELECT x AS a FROM t1 UNION SELECT x AS b FROM t2 ORDER BY b;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.B

SELECT x FROM t1 UNION SELECT x FROM t2 ORDER BY y;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.Y

SELECT x FROM t1 UNION SELECT x FROM t2 ORDER BY t1.x;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.T1.X

-- # Each side can have its own ORDER BY, OFFSET and FETCH FIRST (F855, F856, F863).
(SELECT x FROM t1 ORDER BY x DESC FETCH FIRST 1 ROW ONLY) UNION ALL (SELECT x FROM t2 ORDER BY x OFFSET 2 ROWS);
-- X: 3
-- X: 4

(SELECT x FROM t1 ORDER BY x DESC OFFSET 1 ROW) EXCEPT ALL VALUES 3 ORDER BY x;
-- X: 1
-- X: 2
-- X: 2

-- # A query with an ORDER BY in parentheses.
(SELECT x FROM t2 ORDER BY x DESC);
-- X: 4
-- X: 3
-- X: 2

(VALUES 1, 2, 3 FETCH FIRST 2 ROWS ONLY) ORDER BY COL1 DESC;
-- COL1: 2
-- COL1: 1

-- # In a subquery (E071-06).
SELECT * FROM (SELECT x FROM t1 UNION SELECT x FROM t2) AS t ORDER BY x;
-- X: 1
-- X: 2
-- X: 3
-- X: 4

SELECT t.a FROM (SELECT x, y FROM t1 EXCEPT SELECT x, z FROM t2) AS t (a, b);
-- A: 1

SELECT * FROM ((SELECT x FROM t1) UNION (SELECT x FROM t2 FETCH FIRST 1 ROW ONLY)) AS t;
-- X: 1
-- X: 2
-- X: 3

SELECT COUNT(*) FROM (SELECT x FROM t1 UNION ALL SELECT x FROM t2) AS t;
-- COL1: 8

EXPLAIN SELECT x FROM t1 UNION SELECT x FROM t2 ORDER BY x;
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.T1 (X INTEGER, Y CHARACTER VARYING(10))
-- EXPLAIN:   EXPR (X INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.T2 (X BIGINT, Z CHARACTER VARYING(20))
-- EXPLAIN:   EXPR (X BIGINT)
-- EXPLAIN: UNION DISTINCT (X BIGINT)
-- EXPLAIN: ORDER BY X ASC

EXPLAIN VALUES 1 EXCEPT ALL VALUES 2 UNION ALL VALUES 3;
-- EXPLAIN: $1:
-- EXPLAIN:   $1:
-- EXPLAIN:     VALUES (COL1 SMALLINT) = ROW(1)
-- EXPLAIN:   $2:
-- EXPLAIN:     VALUES (COL1 SMALLINT) = ROW(2)
-- EXPLAIN:   EXCEPT ALL (COL1 SMALLINT)
-- EXPLAIN: $2:
-- EXPLAIN:   VALUES (COL1 SMALLINT) = ROW(3)
-- EXPLAIN: UNION ALL (COL1 SMALLINT)

-- # Each row from either side is only evaluated once.
SELECT NEXT VALUE FOR seq1 FROM t2 UNION ALL SELECT NEXT VALUE FOR seq1 FROM t2;
-- COL1: 1
-- COL1: 2
-- COL1: 3
-- COL1: 4
-- COL1: 5
-- COL1: 6

-- # An error from either side.
SELECT x FROM t1 UNION SELECT 1 / 0 FROM t2;
-- error 22012: division by zero

SELECT x FROM t1 UNION SELECT foo FROM t2;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.FOO

-- # The combined type has enough precision for both sides.
VALUES CAST(1 AS NUMERIC(2, 1)) UNION VALUES CAST(123 AS NUMERIC(3, 0));
-- COL1: 1.0
-- COL1: 123.0
