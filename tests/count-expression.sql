/* setup */
CREATE TABLE t (x INT, y VARCHAR(10), c CHAR(3), b BOOLEAN, d DATE, ts TIMESTAMP, n NUMERIC(5, 2), f DOUBLE PRECISION, s SMALLINT, g BIGINT, r REAL);
INSERT INTO t (x, y, c, b, d, ts, n, f, s, g, r) VALUES (1, 'a', 'abc', TRUE, DATE '2022-01-01', TIMESTAMP '2022-01-01 10:00:00', 1.5, 1.5e0, 1, 1, 1.5e0);
INSERT INTO t (x, y, c, b, d, ts, n, f, s, g, r) VALUES (2, 'b', 'def', FALSE, DATE '2022-01-02', TIMESTAMP '2022-01-02 10:00:00', 2.5, 2.5e0, 2, 2, 2.5e0);
INSERT INTO t (x) VALUES (NULL);

/* types */
SELECT COUNT(x), COUNT(y), COUNT(c), COUNT(b), COUNT(d), COUNT(ts) FROM t;
-- warning 01003: null value eliminated in set function
-- COL1: 2 (INTEGER) COL2: 2 (INTEGER) COL3: 2 (INTEGER) COL4: 2 (INTEGER) COL5: 2 (INTEGER) COL6: 2 (INTEGER)

SELECT COUNT(n), COUNT(f), COUNT(s), COUNT(g), COUNT(r) FROM t;
-- warning 01003: null value eliminated in set function
-- COL1: 2 COL2: 2 COL3: 2 COL4: 2 COL5: 2

SELECT COUNT(1), COUNT('a'), COUNT(*) FROM t;
-- COL1: 3 COL2: 3 COL3: 3

SELECT COUNT(x + 1), COUNT(UPPER(y)) FROM t;
-- warning 01003: null value eliminated in set function
-- COL1: 2 COL2: 2

SELECT b, COUNT(y) FROM t GROUP BY b;
-- warning 01003: null value eliminated in set function
-- B: UNKNOWN COL2: 0
-- B: FALSE COL2: 1
-- B: TRUE COL2: 1

SELECT COUNT(x) FROM t WHERE x > 10;
-- COL1: 0

-- # Several aggregate functions on a table with 8 or more columns.

CREATE TABLE wide (a DOUBLE PRECISION, b DOUBLE PRECISION, c INT, c2 INT, c3 INT, c4 INT, c5 INT, c6 INT);
INSERT INTO wide (a, b) VALUES (1.5e0, 2.5e0);
INSERT INTO wide (a, b) VALUES (3.5e0, 4.5e0);
SELECT SUM(a), SUM(b), AVG(a), AVG(b) FROM wide;
SELECT c, SUM(a), SUM(b) FROM wide GROUP BY c;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- COL1: 5e0 COL2: 7e0 COL3: 2.5e0 COL4: 3.5e0
-- C: NULL COL2: 5e0 COL3: 7e0
