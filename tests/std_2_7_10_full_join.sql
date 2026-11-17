-- # ISO/IEC 9075-2:2023, 7.10, <joined table>, General Rules, 5.d
/* setup */
CREATE TABLE t1 (f1 INT, f2 INT);
INSERT INTO t1 (f1, f2) VALUES (123, 1);
INSERT INTO t1 (f1, f2) VALUES (456, 2);
INSERT INTO t1 (f1, f2) VALUES (789, 3);
CREATE TABLE t2 (f3 INT, f4 INT);
INSERT INTO t2 (f3, f4) VALUES (123, 5);
INSERT INTO t2 (f3, f4) VALUES (345, 7);
INSERT INTO t2 (f3, f4) VALUES (789, 6);
INSERT INTO t2 (f3, f4) VALUES (NULL, 8);
CREATE TABLE t0 (f5 INT);

/* define k */
CREATE TABLE k1 (id INT PRIMARY KEY, a INT NOT NULL);
CREATE TABLE k2 (id INT PRIMARY KEY, b INT NOT NULL);
INSERT INTO k1 (id, a) VALUES (1, 10);
INSERT INTO k1 (id, a) VALUES (2, 20);
INSERT INTO k2 (id, b) VALUES (2, 200);
INSERT INTO k2 (id, b) VALUES (3, 300);

/* define u */
CREATE TABLE u1 (x INT, a INT);
CREATE TABLE u2 (x INT, b INT);
INSERT INTO u1 (x, a) VALUES (1, 10);
INSERT INTO u1 (x, a) VALUES (2, 20);
INSERT INTO u1 (x, a) VALUES (NULL, 30);
INSERT INTO u2 (x, b) VALUES (1, 100);
INSERT INTO u2 (x, b) VALUES (3, 300);
INSERT INTO u2 (x, b) VALUES (NULL, 400);

-- # A FULL join is the matching pairs, then each left row that didn't match
-- # (with NULLs for the right side), then each right row that didn't match (with
-- # NULLs for the left side). Every column can be NULL.
/* flags */
SELECT * FROM t1 FULL JOIN t2 ON f1 = f3;
-- flags: F406
-- F1: 123 F2: 1 F3: 123 F4: 5
-- F1: 456 F2: 2 F3: NULL F4: NULL
-- F1: 789 F2: 3 F3: 789 F4: 6
-- F1: NULL F2: NULL F3: 345 F4: 7
-- F1: NULL F2: NULL F3: NULL F4: 8

SELECT * FROM t1 FULL OUTER JOIN t2 ON f1 = f3;
-- F1: 123 F2: 1 F3: 123 F4: 5
-- F1: 456 F2: 2 F3: NULL F4: NULL
-- F1: 789 F2: 3 F3: 789 F4: 6
-- F1: NULL F2: NULL F3: 345 F4: 7
-- F1: NULL F2: NULL F3: NULL F4: 8

/* extensions V001-01 */
EXPLAIN SELECT * FROM t1 FULL JOIN t2 ON f1 = f3;
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.T1 (F1 INTEGER, F2 INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.T2 (F3 INTEGER, F4 INTEGER)
-- EXPLAIN: FULL JOIN ON F1 = F3 (":memory:".PUBLIC.T1.F1 INTEGER, ":memory:".PUBLIC.T1.F2 INTEGER, ":memory:".PUBLIC.T2.F3 INTEGER, ":memory:".PUBLIC.T2.F4 INTEGER)
-- EXPLAIN: EXPR (":memory:".PUBLIC.T1.F1 INTEGER, ":memory:".PUBLIC.T1.F2 INTEGER, ":memory:".PUBLIC.T2.F3 INTEGER, ":memory:".PUBLIC.T2.F4 INTEGER)

-- # A row that matches more than one row on the other side is in each pair.
SELECT * FROM t1 FULL JOIN t2 ON f1 < f3 ORDER BY f1, f3;
-- F1: NULL F2: NULL F3: NULL F4: 8
-- F1: NULL F2: NULL F3: 123 F4: 5
-- F1: 123 F2: 1 F3: 345 F4: 7
-- F1: 123 F2: 1 F3: 789 F4: 6
-- F1: 456 F2: 2 F3: 789 F4: 6
-- F1: 789 F2: 3 F3: NULL F4: NULL

-- # Without any matches, it's every row of each side once.
SELECT * FROM t1 FULL JOIN t2 ON FALSE;
-- F1: 123 F2: 1 F3: NULL F4: NULL
-- F1: 456 F2: 2 F3: NULL F4: NULL
-- F1: 789 F2: 3 F3: NULL F4: NULL
-- F1: NULL F2: NULL F3: 123 F4: 5
-- F1: NULL F2: NULL F3: 345 F4: 7
-- F1: NULL F2: NULL F3: 789 F4: 6
-- F1: NULL F2: NULL F3: NULL F4: 8

SELECT * FROM t1 FULL JOIN t0 ON TRUE;
-- F1: 123 F2: 1 F5: NULL
-- F1: 456 F2: 2 F5: NULL
-- F1: 789 F2: 3 F5: NULL

SELECT * FROM t0 FULL JOIN t1 ON TRUE;
-- F5: NULL F1: 123 F2: 1
-- F5: NULL F1: 456 F2: 2
-- F5: NULL F1: 789 F2: 3

-- # WHERE applies to the joined rows, so it can pick the rows that didn't
-- # match on either side.
SELECT * FROM t1 FULL JOIN t2 ON f1 = f3 WHERE f1 IS NULL OR f3 IS NULL;
-- F1: 456 F2: 2 F3: NULL F4: NULL
-- F1: NULL F2: NULL F3: 345 F4: 7
-- F1: NULL F2: NULL F3: NULL F4: 8

SELECT * FROM t1 FULL JOIN t2 ON f1 = f3 WHERE f3 = 345;
-- F1: NULL F2: NULL F3: 345 F4: 7

SELECT * FROM t1 FULL JOIN t2 ON f1 = f3 WHERE f1 = 456;
-- F1: 456 F2: 2 F3: NULL F4: NULL

-- # A PRIMARY KEY isn't used to find the matching rows, since every row of
-- # both sides is needed. Columns that are NOT NULL in the tables can be NULL.
/* include k */
SELECT * FROM k1 FULL JOIN k2 ON k1.id = k2.id;
-- ID: 1 A: 10 ID: NULL B: NULL
-- ID: 2 A: 20 ID: 2 B: 200
-- ID: NULL A: NULL ID: 3 B: 300

/* include k */
/* extensions V001-01 */
EXPLAIN SELECT * FROM k1 FULL JOIN k2 ON k1.id = k2.id;
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.K1 (ID INTEGER NOT NULL, A INTEGER NOT NULL)
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.K2 (ID INTEGER NOT NULL, B INTEGER NOT NULL)
-- EXPLAIN: FULL JOIN ON K1.ID = K2.ID (":memory:".PUBLIC.K1.ID INTEGER, ":memory:".PUBLIC.K1.A INTEGER, ":memory:".PUBLIC.K2.ID INTEGER, ":memory:".PUBLIC.K2.B INTEGER)
-- EXPLAIN: EXPR (":memory:".PUBLIC.K1.ID INTEGER, ":memory:".PUBLIC.K1.A INTEGER, ":memory:".PUBLIC.K2.ID INTEGER, ":memory:".PUBLIC.K2.B INTEGER)

/* include k */
/* extensions V001-01 */
EXPLAIN SELECT * FROM k1 FULL JOIN k2 ON k1.id = k2.id WHERE k1.id = 1;
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.K1 (ID INTEGER NOT NULL, A INTEGER NOT NULL)
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.K2 (ID INTEGER NOT NULL, B INTEGER NOT NULL)
-- EXPLAIN: FULL JOIN ON K1.ID = K2.ID (":memory:".PUBLIC.K1.ID INTEGER, ":memory:".PUBLIC.K1.A INTEGER, ":memory:".PUBLIC.K2.ID INTEGER, ":memory:".PUBLIC.K2.B INTEGER)
-- EXPLAIN: WHERE K1.ID = 1
-- EXPLAIN: EXPR (":memory:".PUBLIC.K1.ID INTEGER, ":memory:".PUBLIC.K1.A INTEGER, ":memory:".PUBLIC.K2.ID INTEGER, ":memory:".PUBLIC.K2.B INTEGER)

/* include k */
SELECT * FROM k1 FULL JOIN k2 ON k1.id = k2.id WHERE k1.id = 1;
-- ID: 1 A: 10 ID: NULL B: NULL

-- # With USING, the common column is the value of whichever side isn't NULL. It
-- # can only be NULL when a side can be.
/* include u */
SELECT * FROM u1 FULL JOIN u2 USING (x);
-- X: 1 A: 10 B: 100
-- X: 2 A: 20 B: NULL
-- X: NULL A: 30 B: NULL
-- X: 3 A: NULL B: 300
-- X: NULL A: NULL B: 400

/* include k */
/* extensions V001-01 */
EXPLAIN SELECT * FROM k1 FULL JOIN k2 USING (id);
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.K1 (ID INTEGER NOT NULL, A INTEGER NOT NULL)
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.K2 (ID INTEGER NOT NULL, B INTEGER NOT NULL)
-- EXPLAIN: FULL JOIN ON ":memory:".PUBLIC.K1.ID = ":memory:".PUBLIC.K2.ID ($USING2.ID INTEGER NOT NULL, ":memory:".PUBLIC.K1.A INTEGER, ":memory:".PUBLIC.K2.B INTEGER)
-- EXPLAIN: EXPR ($USING2.ID INTEGER NOT NULL, ":memory:".PUBLIC.K1.A INTEGER, ":memory:".PUBLIC.K2.B INTEGER)

/* include k */
SELECT * FROM k1 FULL JOIN k2 USING (id);
-- ID: 1 A: 10 B: NULL
-- ID: 2 A: 20 B: 200
-- ID: 3 A: NULL B: 300

/* include k */
/* include u */
/* extensions V001-01 */
EXPLAIN SELECT * FROM k1 FULL JOIN u2 ON TRUE FULL JOIN k2 USING (b);
-- EXPLAIN: $1:
-- EXPLAIN:   $1:
-- EXPLAIN:     TABLE ":memory:".PUBLIC.K1 (ID INTEGER NOT NULL, A INTEGER NOT NULL)
-- EXPLAIN:   $2:
-- EXPLAIN:     TABLE ":memory:".PUBLIC.U2 (X INTEGER, B INTEGER)
-- EXPLAIN:   FULL JOIN ON TRUE (":memory:".PUBLIC.K1.ID INTEGER, ":memory:".PUBLIC.K1.A INTEGER, ":memory:".PUBLIC.U2.X INTEGER, ":memory:".PUBLIC.U2.B INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.K2 (ID INTEGER NOT NULL, B INTEGER NOT NULL)
-- EXPLAIN: FULL JOIN ON ":memory:".PUBLIC.U2.B = ":memory:".PUBLIC.K2.B ($USING3.B INTEGER, ":memory:".PUBLIC.K1.ID INTEGER, ":memory:".PUBLIC.K1.A INTEGER, ":memory:".PUBLIC.U2.X INTEGER, ":memory:".PUBLIC.K2.ID INTEGER)
-- EXPLAIN: EXPR ($USING3.B INTEGER, ":memory:".PUBLIC.K1.ID INTEGER, ":memory:".PUBLIC.K1.A INTEGER, ":memory:".PUBLIC.U2.X INTEGER, ":memory:".PUBLIC.K2.ID INTEGER)

-- # FULL joins can be nested and mixed with other joins.
/* include u */
SELECT f1, f3, x, b FROM t1 FULL JOIN t2 ON f1 = f3 LEFT JOIN u2 ON f4 = x + 4 ORDER BY f1, f3;
-- F1: NULL F3: NULL X: NULL B: NULL
-- F1: NULL F3: 345 X: 3 B: 300
-- F1: 123 F3: 123 X: 1 B: 100
-- F1: 456 F3: NULL X: NULL B: NULL
-- F1: 789 F3: 789 X: NULL B: NULL

/* include u */
SELECT f1, a, b FROM t1 FULL JOIN (u1 FULL JOIN u2 USING (x)) ON f1 = a * 10 + 23 ORDER BY f1, a, b;
-- F1: NULL A: NULL B: 300
-- F1: NULL A: NULL B: 400
-- F1: NULL A: 20 B: NULL
-- F1: NULL A: 30 B: NULL
-- F1: 123 A: 10 B: 100
-- F1: 456 A: NULL B: NULL
-- F1: 789 A: NULL B: NULL

/* include u */
SELECT COUNT(*) FROM t1 FULL JOIN t2 ON f1 = f3 FULL JOIN u1 ON f2 = x;
-- COL1: 6

-- # A FULL join in a subquery.
/* extensions V001-01 */
EXPLAIN SELECT * FROM t0 WHERE EXISTS (SELECT * FROM t1 FULL JOIN t2 ON f1 = f3);
-- EXPLAIN: TABLE ":memory:".PUBLIC.T0 (F5 INTEGER)
-- EXPLAIN: WHERE EXISTS (SELECT * FROM T1 FULL JOIN T2 ON F1 = F3)
-- EXPLAIN: EXPR (":memory:".PUBLIC.T0.F5 INTEGER)

-- # FULL needs JOIN.
SELECT * FROM t1 FULL t2 ON TRUE;
-- error 42601: syntax error: unexpected identifier at line 1, column 23 near "FROM t1 FULL t2 ON", expecting JOIN

-- # NATURAL FULL JOIN is a FULL JOIN with USING, and CROSS JOIN can be on its
-- # left.
/* include u */
/* flags */
SELECT * FROM u1 NATURAL FULL JOIN u2 ORDER BY x, a, b;
-- flags: F405, F406
-- X: NULL A: NULL B: 400
-- X: NULL A: 30 B: NULL
-- X: 1 A: 10 B: 100
-- X: 2 A: 20 B: NULL
-- X: 3 A: NULL B: 300

/* include u */
SELECT COUNT(*) FROM t1 CROSS JOIN t2 FULL JOIN u1 ON f2 = x;
-- COL1: 13
