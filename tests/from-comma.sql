/* setup */
CREATE TABLE t1 (a INT, x INT);
CREATE TABLE t2 (b INT, x INT);
CREATE TABLE t3 (c INT);
CREATE TABLE empty_t (e INT);
INSERT INTO t1 (a, x) VALUES (1, 10);
INSERT INTO t1 (a, x) VALUES (2, 20);
INSERT INTO t2 (b, x) VALUES (3, 10);
INSERT INTO t2 (b, x) VALUES (4, 40);
INSERT INTO t3 (c) VALUES (5);

-- # Every row of one table with every row of the other.
SELECT a, b FROM t1, t2;
-- A: 1 B: 3
-- A: 1 B: 4
-- A: 2 B: 3
-- A: 2 B: 4

SELECT a, b, c FROM t1, t2, t3;
-- A: 1 B: 3 C: 5
-- A: 1 B: 4 C: 5
-- A: 2 B: 3 C: 5
-- A: 2 B: 4 C: 5

-- # The columns are in the order of the tables, then their definitions.
SELECT * FROM t3, t1;
-- C: 5 A: 1 X: 10
-- C: 5 A: 2 X: 20

SELECT * FROM t2, t3, t1 WHERE a = 1;
-- B: 3 X: 10 C: 5 A: 1 X: 10
-- B: 4 X: 40 C: 5 A: 1 X: 10

SELECT t1.*, t3.* FROM t3, t1 WHERE a = 2;
-- A: 2 X: 20 C: 5

-- # A column that's only in one table can be unqualified, but not one in both.
SELECT a FROM t1, t2 WHERE b = 4;
-- A: 1
-- A: 2

SELECT x FROM t1, t2;
-- error 42702: ambiguous column: X

SELECT a FROM t1, t2 WHERE x = 10;
-- error 42702: ambiguous column: X

SELECT a FROM t1, t2 ORDER BY x;
-- error 42702: ambiguous column: X

SELECT t1.x, t2.x FROM t1, t2 WHERE t2.b = 3;
-- X: 10 X: 10
-- X: 20 X: 10

-- # WHERE is the join condition.
SELECT a, b FROM t1, t2 WHERE t1.x = t2.x;
-- A: 1 B: 3

SELECT a, b, c FROM t1, t2, t3 WHERE t1.x = t2.x AND c = 5;
-- A: 1 B: 3 C: 5

SELECT a, b FROM t1, t2 WHERE t1.x = t2.x AND a = 2;

-- # A table without rows has no combinations.
SELECT * FROM t1, empty_t;

SELECT * FROM empty_t, t1;

SELECT COUNT(*) AS n FROM t1, empty_t;
-- N: 0

-- # Correlation names.
SELECT p.a, q.b FROM t1 AS p, t2 q WHERE p.x = q.x;
-- A: 1 B: 3

SELECT p.c1, q.c3 FROM t1 AS p (c1, c2), t2 AS q (c3, c4) WHERE c2 = c4;
-- C1: 1 C3: 3

SELECT t1.a FROM t1 AS p, t2;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.T1.A

-- # The same table with different correlation names.
SELECT p.a AS p, q.a AS q FROM t1 AS p, t1 AS q WHERE p.a < q.a;
-- P: 1 Q: 2

SELECT p.a AS p, q.a AS q FROM t1 AS p, t1 AS q, t1 AS r WHERE p.a = 1 AND q.a = 2 AND r.a = 1;
-- P: 1 Q: 2

-- # A range variable can only be exposed once.
SELECT * FROM t1, t1;
-- error 42601: syntax error: table name ":memory:".PUBLIC.T1 specified more than once

SELECT * FROM t1, t2, t1;
-- error 42601: syntax error: table name ":memory:".PUBLIC.T1 specified more than once

SELECT * FROM t1, PUBLIC.t1;
-- error 42601: syntax error: table name ":memory:".PUBLIC.T1 specified more than once

SELECT * FROM t1 AS p, t2 AS p;
-- error 42601: syntax error: table name P specified more than once

SELECT * FROM t1 AS t2, t2;
-- error 42601: syntax error: table name T2 specified more than once

SELECT * FROM t2, t1 AS t2;
-- error 42601: syntax error: table name T2 specified more than once

SELECT * FROM t1, t2 JOIN t1 ON TRUE;
-- error 42601: syntax error: table name ":memory:".PUBLIC.T1 specified more than once

SELECT * FROM t1 AS p, t2 JOIN t3 AS p ON TRUE;
-- error 42601: syntax error: table name P specified more than once

SELECT * FROM (SELECT a FROM t1) AS d, t2 AS d;
-- error 42601: syntax error: table name D specified more than once

/* extensions V201-02 */
SELECT * FROM (SELECT a FROM t1), (SELECT b FROM t2);
-- error 42601: syntax error: each subquery in FROM needs its own correlation name

-- # With an explicit join, which binds tighter than a comma.
SELECT a, b, c FROM t1, t2 JOIN t3 ON b = 3;
-- A: 1 B: 3 C: 5
-- A: 2 B: 3 C: 5

SELECT a, b, c FROM t1 JOIN t2 ON t1.x = t2.x, t3;
-- A: 1 B: 3 C: 5

SELECT * FROM t3, t1 JOIN t2 ON t1.x = t2.x;
-- C: 5 A: 1 X: 10 B: 3 X: 10

SELECT a, b, c FROM t3, t1 LEFT JOIN t2 ON t1.x = t2.x;
-- A: 1 B: 3 C: 5
-- A: 2 B: NULL C: 5

SELECT a, b, c FROM t3, t1 RIGHT JOIN t2 ON t1.x = t2.x;
-- A: 1 B: 3 C: 5
-- A: NULL B: 4 C: 5

SELECT a, b, c FROM t3, (t1 JOIN t2 ON t1.x = t2.x);
-- A: 1 B: 3 C: 5

-- # WHERE sees all of the tables.
SELECT a, b, c FROM t1, t2 JOIN t3 ON b = 3 WHERE t1.x = t2.x;
-- A: 1 B: 3 C: 5

-- # A join condition can't see the tables on the other side of a comma.
SELECT * FROM t1, t2 JOIN t3 ON a = c;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.A

SELECT * FROM t1, t2 JOIN t3 ON t1.a = c;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.T1.A

SELECT * FROM t1 JOIN t2 ON c = 5, t3;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.C

SELECT * FROM t1 JOIN t2 ON t3.c = 5, t3;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.T3.C

SELECT * FROM t3 AS p, t1 JOIN t2 ON p.c = a;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.P.C

-- # Nor can a condition in parentheses see the rest of the join.
SELECT * FROM t3 JOIN (t1 JOIN t2 ON c = a) ON TRUE;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.C

-- # A column isn't ambiguous if the other table is outside of the join.
SELECT p.x, q.b FROM t1 AS p, t2 AS q JOIN t1 AS r ON q.x = r.x AND x = 1;
-- error 42702: ambiguous column: X

SELECT d.x AS dx, q.b FROM (SELECT a FROM t1) AS d (x), t2 AS q JOIN t3 ON x = 10;
-- DX: 1 B: 3
-- DX: 2 B: 3

SELECT d.x AS dx, q.b FROM t2 AS q JOIN t3 ON x = 10, (SELECT a FROM t1) AS d (x);
-- DX: 1 B: 3
-- DX: 2 B: 3

-- # Derived tables.
SELECT d.a, c FROM (SELECT a FROM t1) AS d, t3;
-- A: 1 C: 5
-- A: 2 C: 5

SELECT * FROM t3, (SELECT a, x FROM t1) AS d (y, z) WHERE y = 1;
-- C: 5 Y: 1 Z: 10

SELECT c, v FROM t3, (VALUES ROW(7), ROW(8)) AS d (v);
-- C: 5 V: 7
-- C: 5 V: 8

SELECT d.a, e.b FROM (SELECT a, x FROM t1) AS d, (SELECT b, x FROM t2) AS e WHERE d.x = e.x;
-- A: 1 B: 3

/* extensions V201-02 */
SELECT * FROM (SELECT c FROM t3), t3 AS q;
-- C: 5 C: 5

-- # A derived table can't see the other tables in FROM.
SELECT * FROM t3, (SELECT a FROM t1 WHERE a = c) AS d;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.C

SELECT * FROM t3, (SELECT a FROM t1 WHERE a = t3.c) AS d;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.T3.C

SELECT * FROM (SELECT a FROM t1 WHERE a = c) AS d, t3;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.C

-- # Any part of the query can use the tables.
SELECT a, COUNT(*) AS n FROM t1, t2 GROUP BY a HAVING a > 0 ORDER BY a DESC;
-- A: 2 N: 2
-- A: 1 N: 2

SELECT DISTINCT c FROM t1, t3;
-- C: 5

SELECT a, b FROM t1, t2 ORDER BY b DESC, a DESC FETCH FIRST 1 ROW ONLY;
-- A: 2 B: 4

SELECT COUNT(*) AS n FROM t1, t2, t3;
-- N: 4

-- # In a subquery, and as a correlated subquery that sees the outer query.
SELECT c, (SELECT COUNT(*) FROM t1, t2) AS n FROM t3;
-- C: 5 N: 4

SELECT a FROM t1 WHERE EXISTS (SELECT 1 FROM t2, t3 WHERE t2.x = t1.x);
-- A: 1

SELECT a FROM t1 WHERE EXISTS (SELECT 1 FROM t2 JOIN t3 ON t2.x = t1.x, t1 AS q);
-- A: 1

SELECT a FROM t1 WHERE a IN (SELECT 1 FROM t2, t3);
-- A: 1

SELECT a, b FROM t1, t2 WHERE t1.x = t2.x UNION ALL SELECT a, c FROM t1, t3 WHERE a = 2;
-- A: 1 B: 3
-- A: 2 B: 5

/* extensions V001-01 */
EXPLAIN SELECT a FROM t1, t3;
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.T1 (A INTEGER, X INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.T3 (C INTEGER)
-- EXPLAIN: INNER JOIN ON TRUE (":memory:".PUBLIC.T1.A INTEGER, ":memory:".PUBLIC.T1.X INTEGER, ":memory:".PUBLIC.T3.C INTEGER)
-- EXPLAIN: EXPR (A INTEGER)

-- # A cursor over more than one table can only read.
/* extensions V108-01 */
DECLARE c CURSOR FOR SELECT a, b FROM t1, t2 FOR UPDATE;
-- error 42601: syntax error: cursor C is not updatable

/* extensions V108-01 V109-01 V110-01 V112-01 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT a, b FROM t1, t2;
OPEN c;
FETCH c;
DELETE FROM t1 WHERE CURRENT OF c;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- A: 1 B: 3
-- error 34000: invalid cursor name: cursor C is not updatable

-- # There must be a table on both sides of the comma.
SELECT * FROM t1, ;
-- error 42601: syntax error: unexpected $end

SELECT * FROM , t1;
-- error 42601: syntax error: unexpected ","
