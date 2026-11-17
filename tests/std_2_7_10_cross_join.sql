-- # ISO/IEC 9075-2:2023, 7.10, <joined table>, General Rules, 1.a
/* setup */
CREATE TABLE t1 (a INTEGER, b VARCHAR(10));
CREATE TABLE t2 (c INTEGER);
CREATE TABLE t3 (d INTEGER, e INTEGER);
CREATE TABLE t0 (f INTEGER);
INSERT INTO t1 (a, b) VALUES (1, 'one');
INSERT INTO t1 (a, b) VALUES (2, 'two');
INSERT INTO t2 (c) VALUES (10);
INSERT INTO t2 (c) VALUES (20);
INSERT INTO t2 (c) VALUES (30);
INSERT INTO t3 (d, e) VALUES (10, 100);
INSERT INTO t3 (d, e) VALUES (30, 300);

-- # Every row of the left side is paired with every row of the right side,
-- # the same as a comma in FROM. The columns are the left side's, then the right
-- # side's.
/* flags */
SELECT * FROM t1 CROSS JOIN t2 ORDER BY a, c;
-- flags: F407
-- A: 1 B: one C: 10
-- A: 1 B: one C: 20
-- A: 1 B: one C: 30
-- A: 2 B: two C: 10
-- A: 2 B: two C: 20
-- A: 2 B: two C: 30

SELECT * FROM t1, t2 ORDER BY a, c;
-- A: 1 B: one C: 10
-- A: 1 B: one C: 20
-- A: 1 B: one C: 30
-- A: 2 B: two C: 10
-- A: 2 B: two C: 20
-- A: 2 B: two C: 30

-- # It has no join condition, so WHERE picks the rows.
SELECT a, c FROM t1 CROSS JOIN t2 WHERE c = a * 10 ORDER BY a;
-- A: 1 C: 10
-- A: 2 C: 20

-- # A side without rows means there are no rows.
SELECT * FROM t1 CROSS JOIN t0;

SELECT * FROM t0 CROSS JOIN t1;

SELECT COUNT(*) FROM t1 CROSS JOIN t0;
-- COL1: 0

-- # Joins are from left to right, so a later join can use any table before it.
SELECT a, c, e FROM t1 CROSS JOIN t2 JOIN t3 ON c = d ORDER BY a, c;
-- A: 1 C: 10 E: 100
-- A: 1 C: 30 E: 300
-- A: 2 C: 10 E: 100
-- A: 2 C: 30 E: 300

SELECT COUNT(*) FROM t1 CROSS JOIN t2 CROSS JOIN t3;
-- COL1: 12

SELECT a, c, e FROM t1 LEFT JOIN t3 ON a = d CROSS JOIN t2 WHERE c = 20 ORDER BY a;
-- A: 1 C: 20 E: NULL
-- A: 2 C: 20 E: NULL

-- # The right side is a table, a derived table or a parenthesized join.
SELECT a, c, e FROM t1 CROSS JOIN (t2 JOIN t3 ON c = d) ORDER BY a, c;
-- A: 1 C: 10 E: 100
-- A: 1 C: 30 E: 300
-- A: 2 C: 10 E: 100
-- A: 2 C: 30 E: 300

SELECT a, c, e FROM t1 CROSS JOIN ((t2 JOIN t3 ON c = d)) WHERE a = 2 ORDER BY c;
-- A: 2 C: 10 E: 100
-- A: 2 C: 30 E: 300

SELECT x.a, y.a AS a2 FROM t1 AS x CROSS JOIN t1 AS y ORDER BY x.a, y.a;
-- A: 1 A2: 1
-- A: 1 A2: 2
-- A: 2 A2: 1
-- A: 2 A2: 2

SELECT a, n FROM t1 CROSS JOIN (VALUES 5, 6) AS v (n) ORDER BY a, n;
-- A: 1 N: 5
-- A: 1 N: 6
-- A: 2 N: 5
-- A: 2 N: 6

SELECT * FROM (t1 CROSS JOIN t2) WHERE a = 1 AND c = 10;
-- A: 1 B: one C: 10

-- # A column name that's on both sides must be qualified.
SELECT a FROM t1 CROSS JOIN t1 AS y;
-- error 42702: ambiguous column: A

-- # The same table can't be used twice without a correlation name.
SELECT * FROM t1 CROSS JOIN t1;
-- error 42601: syntax error: table name ":memory:".PUBLIC.T1 specified more than once

-- # CROSS JOIN has no ON or USING.
SELECT * FROM t1 CROSS JOIN t2 ON a = c;
-- error 42601: syntax error: unexpected ON at line 1, column 32 near "CROSS JOIN t2 ON a"
