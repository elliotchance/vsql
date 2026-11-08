/* setup */
CREATE TABLE t1 (x INT, y VARCHAR(10));
CREATE TABLE t2 (x INT);
CREATE TABLE t3 (x INT);
INSERT INTO t1 (x, y) VALUES (1, 'a'), (2, 'b'), (3, 'c');
INSERT INTO t3 (x) VALUES (2), (NULL);

-- # ALL is TRUE when the comparison is TRUE for every row (E061-07, E061-12).
VALUES 0 < ALL (SELECT x FROM t1);
-- COL1: TRUE

VALUES 1 < ALL (SELECT x FROM t1);
-- COL1: FALSE

VALUES 3 >= ALL (SELECT x FROM t1);
-- COL1: TRUE

VALUES 2 >= ALL (SELECT x FROM t1);
-- COL1: FALSE

VALUES 4 > ALL (SELECT x FROM t1);
-- COL1: TRUE

VALUES 1 <= ALL (SELECT x FROM t1);
-- COL1: TRUE

VALUES 4 <> ALL (SELECT x FROM t1);
-- COL1: TRUE

VALUES 2 <> ALL (SELECT x FROM t1);
-- COL1: FALSE

VALUES 2 = ALL (SELECT x FROM t1 WHERE x = 2);
-- COL1: TRUE

VALUES 2 = ALL (SELECT x FROM t1);
-- COL1: FALSE

-- # SOME (or ANY) is TRUE when the comparison is TRUE for any row.
VALUES 2 = SOME (SELECT x FROM t1);
-- COL1: TRUE

VALUES 4 = ANY (SELECT x FROM t1);
-- COL1: FALSE

VALUES 3 > SOME (SELECT x FROM t1);
-- COL1: TRUE

VALUES 1 > ANY (SELECT x FROM t1);
-- COL1: FALSE

VALUES 3 < SOME (SELECT x FROM t1);
-- COL1: FALSE

VALUES 1 >= ANY (SELECT x FROM t1);
-- COL1: TRUE

VALUES 3 <= SOME (SELECT x FROM t1);
-- COL1: TRUE

VALUES 2 <> ANY (SELECT x FROM t1);
-- COL1: TRUE

-- # An empty subquery is TRUE for ALL, and FALSE for SOME.
VALUES 1 = ALL (SELECT x FROM t2);
-- COL1: TRUE

VALUES CAST(NULL AS INT) = ALL (SELECT x FROM t2);
-- COL1: TRUE

VALUES 1 = SOME (SELECT x FROM t2);
-- COL1: FALSE

VALUES CAST(NULL AS INT) = ANY (SELECT x FROM t2);
-- COL1: FALSE

-- # A NULL is UNKNOWN, unless another row decides the result.
VALUES 1 < ALL (SELECT x FROM t3);
-- COL1: UNKNOWN

VALUES 3 < ALL (SELECT x FROM t3);
-- COL1: FALSE

VALUES 2 = ANY (SELECT x FROM t3);
-- COL1: TRUE

VALUES 1 = ANY (SELECT x FROM t3);
-- COL1: UNKNOWN

VALUES CAST(NULL AS INT) > ALL (SELECT x FROM t1);
-- COL1: UNKNOWN

SELECT * FROM t1 WHERE x > ALL (SELECT x FROM t3);

SELECT * FROM t1 WHERE NOT (x < ALL (SELECT x FROM t3));
-- X: 2 Y: b
-- X: 3 Y: c

SELECT * FROM t1 WHERE x >= ALL (SELECT x FROM t1);
-- X: 3 Y: c

SELECT x, x < SOME (SELECT x FROM t1) AS s FROM t1;
-- X: 1 S: TRUE
-- X: 2 S: TRUE
-- X: 3 S: FALSE

-- # The subquery can be any query expression.
VALUES 'b' < ALL (SELECT y FROM t1 WHERE x > 2 UNION VALUES 'd');
-- COL1: TRUE

VALUES 3 = ALL (SELECT MAX(x) FROM t1);
-- COL1: TRUE

VALUES 3 = ANY (VALUES 1, 2 + 1);
-- COL1: TRUE

VALUES 2 = ANY ((SELECT x FROM t1));
-- COL1: TRUE

-- # The subquery must have one column, with values that can be compared.
VALUES 1 = ALL (SELECT * FROM t1);
-- error 42601: syntax error: subquery must return only one column

VALUES 1 = ANY (SELECT x, x FROM t1);
-- error 42601: syntax error: subquery must return only one column

VALUES 1 < ALL (SELECT y FROM t1);
-- error 42883: cannot compare SMALLINT and CHARACTER VARYING(10)

VALUES 1 < ANY (SELECT y FROM t1);
-- error 42883: cannot compare SMALLINT and CHARACTER VARYING(10)

VALUES 1 < ALL (SELECT foo FROM t2);
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.FOO

-- # The subquery isn't optional.
VALUES 1 = ALL (1, 2);
-- error 42601: syntax error: unexpected number, expecting SELECT or TABLE or VALUES or "("

/* extensions V001-01 */
EXPLAIN SELECT * FROM t1 WHERE x > ALL (SELECT x FROM t2) AND x = ANY (SELECT x FROM t3);
-- EXPLAIN: TABLE ":memory:".PUBLIC.T1 (X INTEGER, Y CHARACTER VARYING(10))
-- EXPLAIN: WHERE X > ALL (SELECT X FROM T2) AND X = SOME (SELECT X FROM T3)
-- EXPLAIN: EXPR (":memory:".PUBLIC.T1.X INTEGER, ":memory:".PUBLIC.T1.Y CHARACTER VARYING(10))
