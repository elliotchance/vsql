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

-- # Joins without parentheses go from left to right, so a later ON can use the
-- # columns of every table before it (Syntax Rules, 11.a.ii). Each left join
-- # keeps every row of T1.
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

-- # A later inner join, and the WHERE, still see the rows that an earlier left
-- # join filled with NULLs.
SELECT * FROM t1 LEFT JOIN t2 ON a = x JOIN t3 ON a <> y;
-- A: 1 X: 1 Y: 3
-- A: 2 X: 2 Y: 1
-- A: 2 X: 2 Y: 3
-- A: 3 X: NULL Y: 1

SELECT * FROM t1 LEFT JOIN t2 ON a = x LEFT JOIN t3 ON a = y WHERE a > 1;
-- A: 2 X: 2 Y: NULL
-- A: 3 X: NULL Y: 3

-- # A comparison with a NULL from a left join is never TRUE, so a later inner
-- # join on it drops those rows.
SELECT t1.a, t2.x, t3.y FROM t1 LEFT JOIN t2 ON t1.a = t2.x JOIN t3 ON t2.x = t3.y;
-- A: 1 X: 1 Y: 1

-- # Right joins chain the same way, keeping every row of the last table.
SELECT * FROM t1 RIGHT JOIN t2 ON a = x RIGHT JOIN t3 ON x = y;
-- A: 1 X: 1 Y: 1
-- A: NULL X: NULL Y: 3

-- # ON clauses pair with the joins from the inside out, so here t2 JOIN t3 ON
-- # x = y is joined first, as if it were in parentheses. Extra parentheses
-- # change nothing.
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

-- # ON TRUE keeps every combination: 3 x 2 x 2 rows.
SELECT COUNT(*) FROM t1 JOIN t2 ON TRUE JOIN t3 ON TRUE;
-- COL1: 12

-- # The ON of a nested join can only see the two tables it joins, so A of T1
-- # isn't known there.
SELECT * FROM t1 JOIN t2 JOIN t3 ON a = y ON a = x;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.A

-- # A table or correlation name can only be used once in the same FROM, even
-- # further along a chain of joins.
SELECT * FROM t1 JOIN t1 ON TRUE;
-- error 42601: syntax error: table name ":memory:".PUBLIC.T1 specified more than once

SELECT * FROM t1 JOIN t2 ON a = x LEFT JOIN t1 ON TRUE;
-- error 42601: syntax error: table name ":memory:".PUBLIC.T1 specified more than once

SELECT * FROM (SELECT a FROM t1) AS s JOIN (SELECT x FROM t2) AS s ON TRUE;
-- error 42601: syntax error: table name S specified more than once

-- # As an extension, a derived table can leave out its correlation name, but
-- # two of them can't both leave it out.
/* extensions V201-02 */
SELECT * FROM (SELECT a FROM t1) JOIN (SELECT x FROM t2) ON TRUE;
-- error 42601: syntax error: each subquery in FROM needs its own correlation name

/* extensions V201-02 */
SELECT * FROM (SELECT a FROM t1) JOIN (SELECT x FROM t2) AS s ON a = x;
-- A: 1 X: 1
-- A: 2 X: 2
