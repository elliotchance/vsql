/* setup */
CREATE TABLE t1 (x INT, y VARCHAR(10));
CREATE TABLE t2 (x BIGINT);
CREATE TABLE t3 (x INT);
INSERT INTO t1 (x, y) VALUES (1, 'a'), (2, 'b'), (3, 'c');
INSERT INTO t2 (x) VALUES (2), (3), (4);
INSERT INTO t3 (x) VALUES (2), (NULL);

-- # IN with a subquery is TRUE when any row is equal (E061-11).
SELECT * FROM t1 WHERE x IN (SELECT x FROM t2);
-- X: 2 Y: b
-- X: 3 Y: c

SELECT * FROM t1 WHERE x NOT IN (SELECT x FROM t2);
-- X: 1 Y: a

VALUES 3 IN (SELECT x FROM t2);
-- COL1: TRUE

VALUES 5 IN (SELECT x FROM t2);
-- COL1: FALSE

VALUES 5 NOT IN (SELECT x FROM t2);
-- COL1: TRUE

-- # An empty subquery is FALSE for IN, and TRUE for NOT IN.
VALUES 1 IN (SELECT x FROM t2 WHERE x > 10);
-- COL1: FALSE

VALUES 1 NOT IN (SELECT x FROM t2 WHERE x > 10);
-- COL1: TRUE

VALUES CAST(NULL AS INT) IN (SELECT x FROM t2 WHERE x > 10);
-- COL1: FALSE

-- # A NULL that isn't equal is UNKNOWN, so NOT IN is never TRUE with a NULL.
VALUES 2 IN (SELECT x FROM t3);
-- COL1: TRUE

VALUES 1 IN (SELECT x FROM t3);
-- COL1: UNKNOWN

VALUES 1 NOT IN (SELECT x FROM t3);
-- COL1: UNKNOWN

VALUES 2 NOT IN (SELECT x FROM t3);
-- COL1: FALSE

VALUES CAST(NULL AS INT) IN (SELECT x FROM t2);
-- COL1: UNKNOWN

SELECT * FROM t1 WHERE x NOT IN (SELECT x FROM t3);

-- # The subquery can be any query expression.
VALUES 'b' IN (SELECT y FROM t1 WHERE x > 1 ORDER BY y FETCH FIRST 1 ROW ONLY);
-- COL1: TRUE

VALUES 'c' IN (SELECT y FROM t1 WHERE x > 1 ORDER BY y FETCH FIRST 1 ROW ONLY);
-- COL1: FALSE

VALUES 4 IN (SELECT x FROM t1 UNION SELECT x FROM t2);
-- COL1: TRUE

VALUES 2 IN (SELECT x FROM t1 EXCEPT SELECT x FROM t2);
-- COL1: FALSE

VALUES 5 IN (VALUES 4, 5);
-- COL1: TRUE

VALUES 3 IN (SELECT COUNT(*) FROM t1);
-- COL1: TRUE

VALUES 2 IN (SELECT a FROM (SELECT x + 1 AS a FROM t1) AS q);
-- COL1: TRUE

SELECT * FROM t1 WHERE x IN (SELECT x FROM t2 WHERE x IN (SELECT x FROM t3));
-- X: 2 Y: b

-- # Values of different types can be compared.
VALUES 2.0 IN (SELECT x FROM t2);
-- COL1: TRUE

VALUES 'b ' IN (SELECT y FROM t1);
-- COL1: TRUE

-- # A parenthesized subquery is still a subquery.
VALUES 3 IN ((SELECT x FROM t2));
-- COL1: TRUE

-- # The subquery must have one column.
VALUES 1 IN (SELECT * FROM t1);
-- error 42601: syntax error: subquery must return only one column

VALUES 1 IN (SELECT x, y FROM t1);
-- error 42601: syntax error: subquery must return only one column

VALUES 1 IN (SELECT y FROM t1);
-- error 42883: cannot compare SMALLINT and CHARACTER VARYING(10)

-- # Values that can't be compared are an error, even when they're found.
VALUES 'a' IN (SELECT y FROM t1 UNION ALL SELECT CAST(x AS VARCHAR(10)) FROM t1);
-- COL1: TRUE

EXPLAIN SELECT * FROM t1 WHERE x NOT IN (SELECT x FROM t2 WHERE x > 1);
-- EXPLAIN: TABLE ":memory:".PUBLIC.T1 (X INTEGER, Y CHARACTER VARYING(10))
-- EXPLAIN: WHERE X NOT IN (SELECT X FROM T2 WHERE X > 1)
-- EXPLAIN: EXPR (":memory:".PUBLIC.T1.X INTEGER, ":memory:".PUBLIC.T1.Y CHARACTER VARYING(10))

EXPLAIN VALUES 1 IN (1, 2);
-- EXPLAIN: VALUES (COL1 BOOLEAN) = ROW(1 IN (1, 2))

-- # DELETE and UPDATE find every row before they change any.
DELETE FROM t2 WHERE x IN (SELECT x FROM t2 WHERE x > 2);
SELECT * FROM t2;
-- msg: DELETE 2
-- X: 2

UPDATE t1 SET y = 'z' WHERE x IN (SELECT x + 1 FROM t1);
SELECT * FROM t1;
-- msg: UPDATE 2
-- X: 1 Y: a
-- X: 2 Y: z
-- X: 3 Y: z
