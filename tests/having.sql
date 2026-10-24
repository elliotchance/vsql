/* setup */
CREATE TABLE t (a INT, b INT);
INSERT INTO t (a, b) VALUES (1, 10);
INSERT INTO t (a, b) VALUES (1, 20);
INSERT INTO t (a, b) VALUES (2, 30);
INSERT INTO t (a, b) VALUES (3, NULL);
INSERT INTO t (a, b) VALUES (3, 40);
INSERT INTO t (a, b) VALUES (3, 50);
CREATE TABLE e (a INT);

EXPLAIN SELECT a, COUNT(*) FROM t GROUP BY a HAVING COUNT(*) > 1;
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (A INTEGER, B INTEGER)
-- EXPLAIN: ORDER BY A ASC
-- EXPLAIN: GROUP BY (":memory:".PUBLIC.T.A INTEGER, COUNT(*) INTEGER)
-- EXPLAIN: WHERE COUNT(*) > 1
-- EXPLAIN: EXPR (A INTEGER, COL2 INTEGER)

SELECT a, COUNT(*) FROM t GROUP BY a HAVING COUNT(*) > 1;
-- A: 1 COL2: 2
-- A: 3 COL2: 3

-- # The aggregate does not need to be in the select list.
SELECT a FROM t GROUP BY a HAVING SUM(b) >= 30;
-- warning 01003: null value eliminated in set function
-- A: 1
-- A: 2
-- A: 3

SELECT a FROM t GROUP BY a HAVING MAX(b) - MIN(b) = 10 AND COUNT(b) = 2;
-- warning 01003: null value eliminated in set function
-- A: 1
-- A: 3

SELECT a, AVG(b) FROM t GROUP BY a HAVING COUNT(DISTINCT b) < 2;
-- warning 01003: null value eliminated in set function
-- A: 2 COL2: 30

-- # A grouping column can be used directly.
SELECT a, SUM(b) FROM t GROUP BY a HAVING a <> 2;
-- warning 01003: null value eliminated in set function
-- A: 1 COL2: 30
-- A: 3 COL2: 90

SELECT a FROM t GROUP BY a HAVING t.a > 1;
-- A: 2
-- A: 3

-- # The HAVING applies after the WHERE.
SELECT a, COUNT(*) FROM t WHERE b > 15 GROUP BY a HAVING COUNT(*) = 1;
-- A: 1 COL2: 1
-- A: 2 COL2: 1

-- # Groups where the condition is FALSE or UNKNOWN are removed.
SELECT a FROM t GROUP BY a HAVING MIN(b) > 0;
-- warning 01003: null value eliminated in set function
-- A: 1
-- A: 2
-- A: 3

SELECT a FROM t GROUP BY a HAVING MIN(b) IS NULL;
-- warning 01003: null value eliminated in set function

SELECT a FROM t GROUP BY a HAVING NULLIF(a, 3) > 0;
-- A: 1
-- A: 2

SELECT a FROM t GROUP BY a HAVING FALSE;

-- # Without a GROUP BY the whole table is one group.
SELECT COUNT(*) FROM t HAVING COUNT(*) > 5;
-- COL1: 6

SELECT COUNT(*) FROM t HAVING COUNT(*) > 6;

SELECT MAX(b) FROM t HAVING MIN(b) = 10;
-- warning 01003: null value eliminated in set function
-- COL1: 50

-- # Even an empty table is one group.
SELECT COUNT(*) FROM e HAVING COUNT(*) = 0;
-- COL1: 0

SELECT 1 FROM e HAVING TRUE;
-- COL1: 1

SELECT COUNT(*) FROM e GROUP BY a HAVING TRUE;

-- # The HAVING can only use grouping columns, outside of an aggregate.
SELECT a FROM t GROUP BY a HAVING b > 1;
-- error 42803: column B must be in the GROUP BY clause or used in an aggregate function

SELECT COUNT(*) FROM t HAVING a > 1;
-- error 42803: column A must be in the GROUP BY clause or used in an aggregate function

SELECT COUNT(*) FROM e HAVING a > 1;
-- error 42803: column A must be in the GROUP BY clause or used in an aggregate function

SELECT a FROM t GROUP BY a HAVING c > 1;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.C

SELECT a FROM t GROUP BY a HAVING a;
-- error 42804: data type mismatch in HAVING: expected BOOLEAN but got INTEGER

SELECT a FROM t GROUP BY a HAVING COUNT(MAX(b)) > 1;
-- error 42601: syntax error: nested set function: COUNT(MAX(B))

-- # HAVING with a join.
CREATE TABLE u (a INT, c VARCHAR(10));
INSERT INTO u (a, c) VALUES (1, 'one');
INSERT INTO u (a, c) VALUES (3, 'three');
SELECT u.c, COUNT(*) FROM t JOIN u ON t.a = u.a GROUP BY u.c HAVING SUM(t.b) > 50;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- warning 01003: null value eliminated in set function
-- C: three COL2: 3

-- # HAVING with ORDER BY and FETCH.
SELECT a, COUNT(*) AS n FROM t GROUP BY a HAVING COUNT(*) < 3 ORDER BY a DESC FETCH FIRST 1 ROW ONLY;
-- A: 2 N: 1

-- # HAVING in a subquery.
SELECT * FROM (SELECT a FROM t GROUP BY a HAVING COUNT(*) > 1) AS s;
-- A: 1
-- A: 3

-- # An asterisk is every column, so each one must be grouped.
SELECT * FROM t GROUP BY a HAVING COUNT(*) > 1;
-- error 42803: column ":memory:".PUBLIC.T.B must be in the GROUP BY clause or used in an aggregate function

SELECT * FROM t HAVING COUNT(*) > 1;
-- error 42803: column ":memory:".PUBLIC.T.A must be in the GROUP BY clause or used in an aggregate function

SELECT * FROM t GROUP BY a;
-- error 42803: column ":memory:".PUBLIC.T.B must be in the GROUP BY clause or used in an aggregate function

SELECT * FROM t GROUP BY b, a HAVING b > 30;
-- A: 3 B: 40
-- A: 3 B: 50

SELECT * FROM (SELECT a FROM t) AS s GROUP BY a HAVING COUNT(*) = 1;
-- A: 2

-- # NEXT VALUE FOR can't be used in a HAVING (a search condition), even when
-- # there are no rows. No value is used.
CREATE SEQUENCE s;
SELECT a FROM t GROUP BY a HAVING a < NEXT VALUE FOR s;
SELECT COUNT(*) FROM t WHERE a > 100 HAVING COUNT(*) < NEXT VALUE FOR s;
VALUES NEXT VALUE FOR s;
-- msg: CREATE SEQUENCE 1
-- error 42601: syntax error: NEXT VALUE FOR cannot be used in HAVING
-- error 42601: syntax error: NEXT VALUE FOR cannot be used in HAVING
-- COL1: 1
