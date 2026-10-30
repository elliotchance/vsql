/* setup */
CREATE TABLE t1 (a INT);
INSERT INTO t1 (a) VALUES (1);
INSERT INTO t1 (a) VALUES (2);
INSERT INTO t1 (a) VALUES (3);
CREATE TABLE t2 (x INT);
INSERT INTO t2 (x) VALUES (1);
INSERT INTO t2 (x) VALUES (2);
CREATE TABLE t3 (y INT);
INSERT INTO t3 (y) VALUES (1);
INSERT INTO t3 (y) VALUES (3);

SELECT * FROM t1 LEFT JOIN t2 ON a = x LEFT JOIN t3 ON a = y;
-- A: 1 X: 1 Y: 1
-- A: 2 X: 2 Y: NULL
-- A: 3 X: NULL Y: 3

/* extensions V001-01 */
EXPLAIN SELECT * FROM t1 LEFT JOIN t2 ON a = x LEFT JOIN t3 ON a = y;
-- EXPLAIN: $1:
-- EXPLAIN:   $1:
-- EXPLAIN:     TABLE ":memory:".PUBLIC.T1 (A INTEGER)
-- EXPLAIN:   $2:
-- EXPLAIN:     TABLE ":memory:".PUBLIC.T2 (X INTEGER)
-- EXPLAIN:   LEFT JOIN ON A = X (":memory:".PUBLIC.T1.A INTEGER, ":memory:".PUBLIC.T2.X INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.T3 (Y INTEGER)
-- EXPLAIN: LEFT JOIN ON A = Y (":memory:".PUBLIC.T1.A INTEGER, ":memory:".PUBLIC.T2.X INTEGER, ":memory:".PUBLIC.T3.Y INTEGER)
-- EXPLAIN: EXPR (":memory:".PUBLIC.T1.A INTEGER, ":memory:".PUBLIC.T2.X INTEGER, ":memory:".PUBLIC.T3.Y INTEGER)

SELECT * FROM t1 LEFT JOIN t2 ON a = x JOIN t3 ON a <> y;
-- A: 1 X: 1 Y: 3
-- A: 2 X: 2 Y: 1
-- A: 2 X: 2 Y: 3
-- A: 3 X: NULL Y: 1

SELECT * FROM t1 LEFT JOIN t2 ON a = x LEFT JOIN t3 ON a = y WHERE a > 1;
-- A: 2 X: 2 Y: NULL
-- A: 3 X: NULL Y: 3

SELECT t1.a, t2.x, t3.y FROM t1 LEFT JOIN t2 ON t1.a = t2.x JOIN t3 ON t2.x = t3.y;
-- A: 1 X: 1 Y: 1

SELECT * FROM t1 RIGHT JOIN t2 ON a = x RIGHT JOIN t3 ON x = y;
-- A: 1 X: 1 Y: 1
-- A: NULL X: NULL Y: 3

SELECT * FROM t1 JOIN t2 JOIN t3 ON x = y ON a = x;
-- A: 1 X: 1 Y: 1

SELECT * FROM t1 LEFT JOIN (t2 JOIN t3 ON x = y) ON a = x;
-- A: 1 X: 1 Y: 1
-- A: 2 X: NULL Y: NULL
-- A: 3 X: NULL Y: NULL

SELECT * FROM ((t1 LEFT JOIN t2 ON a = x)) LEFT JOIN t3 ON a = y;
-- A: 1 X: 1 Y: 1
-- A: 2 X: 2 Y: NULL
-- A: 3 X: NULL Y: 3

SELECT * FROM (t1 JOIN t2 ON a = x);
-- A: 1 X: 1
-- A: 2 X: 2

SELECT COUNT(*) FROM t1 JOIN t2 ON TRUE JOIN t3 ON TRUE;
-- COL1: 12

SELECT * FROM t1 JOIN t2 JOIN t3 ON a = y ON a = x;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.T1.A

SELECT * FROM t1 JOIN t1 ON TRUE;
-- error 42601: syntax error: table name ":memory:".PUBLIC.T1 specified more than once

SELECT * FROM t1 JOIN t2 ON a = x LEFT JOIN t1 ON TRUE;
-- error 42601: syntax error: table name ":memory:".PUBLIC.T1 specified more than once

SELECT * FROM (SELECT a FROM t1) AS s JOIN (SELECT x FROM t2) AS s ON TRUE;
-- error 42601: syntax error: table name S specified more than once

SELECT * FROM (SELECT a FROM t1) JOIN (SELECT x FROM t2) ON TRUE;
-- error 42601: syntax error: a subquery in FROM must have a correlation name, such as (SELECT ...) AS t

SELECT * FROM (SELECT a FROM t1) AS r JOIN (SELECT x FROM t2) AS s ON a = x;
-- A: 1 X: 1
-- A: 2 X: 2
