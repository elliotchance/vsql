/* setup */
CREATE TABLE t1 (f1 INT, f2 INT);
INSERT INTO t1 (f1, f2) VALUES (123, 1);
INSERT INTO t1 (f1, f2) VALUES (456, 2);
INSERT INTO t1 (f1, f2) VALUES (789, 3);
INSERT INTO t1 (f1, f2) VALUES (234, 4);
CREATE TABLE t2 (f3 INT, f4 INT);
INSERT INTO t2 (f3, f4) VALUES (123, 5);
INSERT INTO t2 (f3, f4) VALUES (789, 6);
INSERT INTO t2 (f3, f4) VALUES (345, 7);

EXPLAIN SELECT * FROM t1 LEFT JOIN t2 ON TRUE;
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE PUBLIC.T1 (PUBLIC.T1.F1 INTEGER, PUBLIC.T1.F2 INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE PUBLIC.T2 (PUBLIC.T2.F3 INTEGER, PUBLIC.T2.F4 INTEGER)
-- EXPLAIN: LEFT JOIN ON TRUE (PUBLIC.T1.F1 INTEGER, PUBLIC.T1.F2 INTEGER, PUBLIC.T2.F3 INTEGER, PUBLIC.T2.F4 INTEGER)
-- EXPLAIN: EXPR (F1 INTEGER, F2 INTEGER, F3 INTEGER, F4 INTEGER)

SELECT * FROM t1 LEFT JOIN t2 ON TRUE;
-- F1: 123 F2: 1 F3: 123 F4: 5
-- F1: 123 F2: 1 F3: 789 F4: 6
-- F1: 123 F2: 1 F3: 345 F4: 7
-- F1: 456 F2: 2 F3: 123 F4: 5
-- F1: 456 F2: 2 F3: 789 F4: 6
-- F1: 456 F2: 2 F3: 345 F4: 7
-- F1: 789 F2: 3 F3: 123 F4: 5
-- F1: 789 F2: 3 F3: 789 F4: 6
-- F1: 789 F2: 3 F3: 345 F4: 7
-- F1: 234 F2: 4 F3: 123 F4: 5
-- F1: 234 F2: 4 F3: 789 F4: 6
-- F1: 234 F2: 4 F3: 345 F4: 7

EXPLAIN SELECT * FROM t1 LEFT JOIN t2 ON f1 = f3;
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE PUBLIC.T1 (PUBLIC.T1.F1 INTEGER, PUBLIC.T1.F2 INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE PUBLIC.T2 (PUBLIC.T2.F3 INTEGER, PUBLIC.T2.F4 INTEGER)
-- EXPLAIN: LEFT JOIN ON PUBLIC.T1.F1 = PUBLIC.T2.F3 (PUBLIC.T1.F1 INTEGER, PUBLIC.T1.F2 INTEGER, PUBLIC.T2.F3 INTEGER, PUBLIC.T2.F4 INTEGER)
-- EXPLAIN: EXPR (F1 INTEGER, F2 INTEGER, F3 INTEGER, F4 INTEGER)

SELECT * FROM t1 LEFT JOIN t2 ON f1 = f3;
-- F1: 123 F2: 1 F3: 123 F4: 5
-- F1: 456 F2: 2 F3: NULL F4: NULL
-- F1: 789 F2: 3 F3: 789 F4: 6
-- F1: 234 F2: 4 F3: NULL F4: NULL

EXPLAIN SELECT * FROM t1 LEFT JOIN t2 ON f1 = f3 ORDER BY f3, f1;
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE PUBLIC.T1 (PUBLIC.T1.F1 INTEGER, PUBLIC.T1.F2 INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE PUBLIC.T2 (PUBLIC.T2.F3 INTEGER, PUBLIC.T2.F4 INTEGER)
-- EXPLAIN: LEFT JOIN ON PUBLIC.T1.F1 = PUBLIC.T2.F3 (PUBLIC.T1.F1 INTEGER, PUBLIC.T1.F2 INTEGER, PUBLIC.T2.F3 INTEGER, PUBLIC.T2.F4 INTEGER)
-- EXPLAIN: ORDER BY PUBLIC.T2.F3 ASC, PUBLIC.T1.F1 ASC
-- EXPLAIN: EXPR (F1 INTEGER, F2 INTEGER, F3 INTEGER, F4 INTEGER)

SELECT * FROM t1 LEFT JOIN t2 ON f1 = f3 ORDER BY f3, f1;
-- F1: 234 F2: 4 F3: NULL F4: NULL
-- F1: 456 F2: 2 F3: NULL F4: NULL
-- F1: 123 F2: 1 F3: 123 F4: 5
-- F1: 789 F2: 3 F3: 789 F4: 6

EXPLAIN SELECT * FROM t1 LEFT OUTER JOIN t2 ON TRUE;
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE PUBLIC.T1 (PUBLIC.T1.F1 INTEGER, PUBLIC.T1.F2 INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE PUBLIC.T2 (PUBLIC.T2.F3 INTEGER, PUBLIC.T2.F4 INTEGER)
-- EXPLAIN: LEFT JOIN ON TRUE (PUBLIC.T1.F1 INTEGER, PUBLIC.T1.F2 INTEGER, PUBLIC.T2.F3 INTEGER, PUBLIC.T2.F4 INTEGER)
-- EXPLAIN: EXPR (F1 INTEGER, F2 INTEGER, F3 INTEGER, F4 INTEGER)

EXPLAIN SELECT * FROM t1 LEFT JOIN t2 ON f1 > f3;
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE PUBLIC.T1 (PUBLIC.T1.F1 INTEGER, PUBLIC.T1.F2 INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE PUBLIC.T2 (PUBLIC.T2.F3 INTEGER, PUBLIC.T2.F4 INTEGER)
-- EXPLAIN: LEFT JOIN ON PUBLIC.T1.F1 > PUBLIC.T2.F3 (PUBLIC.T1.F1 INTEGER, PUBLIC.T1.F2 INTEGER, PUBLIC.T2.F3 INTEGER, PUBLIC.T2.F4 INTEGER)
-- EXPLAIN: EXPR (F1 INTEGER, F2 INTEGER, F3 INTEGER, F4 INTEGER)

SELECT * FROM t1 LEFT JOIN t2 ON f1 > f3;
-- F1: 123 F2: 1 F3: NULL F4: NULL
-- F1: 456 F2: 2 F3: 123 F4: 5
-- F1: 456 F2: 2 F3: 345 F4: 7
-- F1: 789 F2: 3 F3: 123 F4: 5
-- F1: 789 F2: 3 F3: 345 F4: 7
-- F1: 234 F2: 4 F3: 123 F4: 5
