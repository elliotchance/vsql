/* setup */
CREATE TABLE t1 (x INT, y VARCHAR(10));
CREATE TABLE t2 (x INT);
INSERT INTO t1 (x, y) VALUES (1, 'a'), (2, 'b'), (3, 'c');
CREATE SEQUENCE seq1;

-- # A subquery in a comparison is the value of its one row (E061-09).
SELECT * FROM t1 WHERE x = (SELECT MAX(x) FROM t1);
-- X: 3 Y: c

SELECT * FROM t1 WHERE (SELECT MIN(x) FROM t1) < x;
-- X: 2 Y: b
-- X: 3 Y: c

SELECT * FROM t1 WHERE y <> (SELECT y FROM t1 WHERE x = 2);
-- X: 1 Y: a
-- X: 3 Y: c

VALUES (SELECT COUNT(*) FROM t1) = 3;
-- COL1: TRUE

VALUES (SELECT x FROM t1 WHERE x = 1) < (SELECT x FROM t1 WHERE x = 2);
-- COL1: TRUE

-- # A subquery without any rows is NULL.
SELECT * FROM t1 WHERE x = (SELECT x FROM t2);

VALUES 1 = (SELECT x FROM t2);
-- COL1: UNKNOWN

/* types */
VALUES (SELECT y FROM t1 WHERE x > 3);
-- COL1: NULL (CHARACTER VARYING(10))

-- # It's an error if there's more than one row, but only when it's evaluated.
SELECT * FROM t1 WHERE x = (SELECT x FROM t1);
-- error 21000: cardinality violation: more than one row returned by a subquery used as an expression

SELECT * FROM t2 WHERE x = (SELECT x FROM t1);

-- # A subquery can be used as any other value (F471).
/* types */
VALUES (SELECT MAX(x) FROM t1);
-- COL1: 3 (INTEGER)

/* types */
VALUES (SELECT y FROM t1 WHERE x = 2);
-- COL1: b (CHARACTER VARYING(10))

SELECT x, (SELECT MAX(x) FROM t1) - x AS d FROM t1;
-- X: 1 D: 2
-- X: 2 D: 1
-- X: 3 D: 0

VALUES ((SELECT MAX(x) FROM t1) + 1) * 2;
-- COL1: 8

VALUES (SELECT (SELECT COUNT(*) FROM t1) FROM t1 WHERE x = 1);
-- COL1: 3

VALUES CASE WHEN (SELECT COUNT(*) FROM t2) = 0 THEN 'empty' ELSE (SELECT y FROM t1 WHERE x = 1) END;
-- COL1: empty

VALUES 2 BETWEEN (SELECT MIN(x) FROM t1) AND (SELECT MAX(x) FROM t1);
-- COL1: TRUE

VALUES COALESCE((SELECT x FROM t2), 0);
-- COL1: 0

VALUES ROW((SELECT MIN(x) FROM t1), (SELECT MAX(x) FROM t1));
-- COL1: 1 COL2: 3

SELECT x FROM t1 ORDER BY (SELECT MAX(x) FROM t1) - x;
-- X: 3
-- X: 2
-- X: 1

SELECT y, COUNT(*) FROM t1 GROUP BY y HAVING COUNT(*) = (SELECT MIN(x) FROM t1);
-- Y: a COL2: 1
-- Y: b COL2: 1
-- Y: c COL2: 1

SELECT y, (SELECT MAX(x) FROM t1) AS m FROM t1 GROUP BY y;
-- Y: a M: 3
-- Y: b M: 3
-- Y: c M: 3

-- # An aggregate function can't contain a subquery.
SELECT MAX((SELECT MIN(x) FROM t1) + x) FROM t1;
-- error 42601: syntax error: a subquery cannot be used in an aggregate function

SELECT a.x, b.x FROM t1 AS a INNER JOIN t1 AS b ON b.x = (SELECT MAX(x) FROM t1);
-- X: 1 X: 3
-- X: 2 X: 3
-- X: 3 X: 3

-- # The subquery must have one column.
VALUES (SELECT * FROM t1);
-- error 42601: syntax error: subquery must return only one column

VALUES 1 = (SELECT x, y FROM t1);
-- error 42601: syntax error: subquery must return only one column

-- # INSERT finds every value before any rows are written.
INSERT INTO t2 (x) VALUES ((SELECT COUNT(*) FROM t2)), ((SELECT COUNT(*) FROM t2) + 10);
SELECT * FROM t2;
-- msg: INSERT 2
-- X: 0
-- X: 10

-- # UPDATE finds every new value before any rows are changed.
UPDATE t1 SET x = (SELECT MAX(x) FROM t1) + 1;
SELECT * FROM t1;
-- msg: UPDATE 3
-- X: 4 Y: a
-- X: 4 Y: b
-- X: 4 Y: c

UPDATE t1 SET y = (SELECT y FROM t1 WHERE x = 3) WHERE x < (SELECT MAX(x) FROM t1);
SELECT * FROM t1;
-- msg: UPDATE 2
-- X: 1 Y: c
-- X: 2 Y: c
-- X: 3 Y: c

UPDATE t1 SET x = (SELECT x FROM t1);
-- error 21000: cardinality violation: more than one row returned by a subquery used as an expression

UPDATE t1 SET x = (SELECT x FROM t2) WHERE x > 5;
-- warning 02000: no data
-- msg: UPDATE 0

UPDATE t1 SET x = (SELECT y FROM t1 WHERE x = 1) WHERE x > 5;
-- error 42846: cannot coerce CHARACTER VARYING(10) to INTEGER

-- # NEXT VALUE FOR can't be used in a subquery, but has one value for each row.
VALUES (SELECT NEXT VALUE FOR seq1 FROM t1 WHERE x = 1);
-- error 42601: syntax error: NEXT VALUE FOR cannot be used in a subquery

SELECT NEXT VALUE FOR seq1 AS a, (SELECT COUNT(*) FROM t1) AS b, NEXT VALUE FOR seq1 AS c FROM t1;
-- A: 1 B: 3 C: 1
-- A: 2 B: 3 C: 2
-- A: 3 B: 3 C: 3

-- # A parameter can be used in a subquery.
/* set foo 2 */
SELECT * FROM t1 WHERE x = (SELECT x FROM t1 WHERE x = :foo);
-- X: 2 Y: b

EXPLAIN SELECT x, (SELECT MAX(x) FROM t2) FROM t1 WHERE y = (SELECT y FROM t1 WHERE x = 1);
-- EXPLAIN: TABLE ":memory:".PUBLIC.T1 (X INTEGER, Y CHARACTER VARYING(10))
-- EXPLAIN: WHERE Y = (SELECT Y FROM T1 WHERE X = 1)
-- EXPLAIN: EXPR (X INTEGER, COL2 INTEGER)
