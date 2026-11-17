/* setup */
CREATE TABLE t1 (x INT);
INSERT INTO t1 (x) VALUES (1), (2), (3), (4), (5), (6), (7), (8), (9), (10);
CREATE TABLE t2 (x INT);

-- # FETCH FIRST <n> PERCENT keeps that percentage of the rows, rounded up
-- # (General Rules, 7.b.ii). It needs F866 (Conformance Rules, 23).
/* flags */
SELECT * FROM t1 FETCH FIRST 20 PERCENT ROWS ONLY;
-- flags: F857, F866
-- X: 1
-- X: 2

SELECT * FROM t1 ORDER BY x DESC FETCH NEXT 25 PERCENT ROW ONLY;
-- X: 10
-- X: 9
-- X: 8

SELECT * FROM t1 FETCH FIRST 1 PERCENT ROWS ONLY;
-- X: 1

-- # The percentage can be any numeric, not just an integer (Syntax Rules, 29).
-- # An exact percentage is multiplied exactly, so 0.07 percent of 10000 rows is
-- # 7 rows, not 8.
SELECT * FROM t1 FETCH FIRST 15.5 PERCENT ROWS ONLY;
SELECT * FROM t1 FETCH FIRST 2.5e1 PERCENT ROWS ONLY;
SELECT COUNT(*) FROM (SELECT * FROM t1 AS a, t1 AS b, t1 AS c, t1 AS d FETCH FIRST 0.07 PERCENT ROWS ONLY) AS s;
-- X: 1
-- X: 2
-- X: 1
-- X: 2
-- X: 3
-- COL1: 7

-- # 100 percent or more is every row.
SELECT COUNT(*) FROM (SELECT * FROM t1 FETCH FIRST 100 PERCENT ROWS ONLY) AS s;
SELECT COUNT(*) FROM (SELECT * FROM t1 FETCH FIRST 1e300 PERCENT ROWS ONLY) AS s;
-- COL1: 10
-- COL1: 10

-- # The percentage is of all the rows, before OFFSET skips some of them (General
-- # Rules, 7.b.ii).
SELECT * FROM t1 OFFSET 8 ROWS FETCH FIRST 30 PERCENT ROWS ONLY;
-- X: 9
-- X: 10

SELECT * FROM t1 OFFSET 2 ROWS FETCH FIRST 30 PERCENT ROWS ONLY;
-- X: 3
-- X: 4
-- X: 5

-- # Less than one row is an exception (General Rules, 7.c). That includes 0
-- # percent, a negative percentage, and any percentage of no rows at all.
SELECT * FROM t1 FETCH FIRST 0 PERCENT ROWS ONLY;
SELECT * FROM t1 FETCH FIRST -5 PERCENT ROWS ONLY;
SELECT * FROM t2 FETCH FIRST 50 PERCENT ROWS ONLY;
-- error 2201W: invalid row count in fetch first clause
-- error 2201W: invalid row count in fetch first clause
-- error 2201W: invalid row count in fetch first clause

-- # The percentage must be numeric (Syntax Rules, 29).
SELECT * FROM t1 FETCH FIRST 'a' PERCENT ROWS ONLY;
-- error 42601: syntax error: FETCH FIRST percentage must be numeric, got CHARACTER(1)

-- # It works anywhere a FETCH FIRST can be, such as in a subquery and on
-- # VALUES.
SELECT * FROM (SELECT * FROM t1 ORDER BY x DESC FETCH FIRST 10 PERCENT ROWS ONLY) AS s;
VALUES 1, 2, 3 FETCH FIRST 50 PERCENT ROWS ONLY;
-- X: 10
-- COL1: 1
-- COL1: 2

/* extensions V001-01 */
EXPLAIN SELECT * FROM t1 FETCH FIRST 20 PERCENT ROWS ONLY;
-- EXPLAIN: TABLE ":memory:".PUBLIC.T1 (X INTEGER)
-- EXPLAIN: FETCH FIRST 20 PERCENT ROWS ONLY
-- EXPLAIN: EXPR (":memory:".PUBLIC.T1.X INTEGER)
