/* setup */
CREATE TABLE t (x DOUBLE PRECISION, y VARCHAR(10), n NUMERIC(5, 2), c CHAR(5));
INSERT INTO t (x, y, n, c) VALUES (1e0, 'a', 1.5, 'a'), (1e0, 'a', 1.50, 'a  '), (2e0, 'b', 2, 'b'), (NULL, 'b', NULL, NULL), (2e0, 'c', 2, 'b');

-- # ALL is the same as no set quantifier, so duplicates are included (E091-06).
SELECT COUNT(ALL x), SUM(ALL x), AVG(ALL x), MIN(ALL x), MAX(ALL x) FROM t;
-- warning 01003: null value eliminated in set function
-- COL1: 4 COL2: 6e0 COL3: 1.5e0 COL4: 1e0 COL5: 2e0

SELECT COUNT(x), SUM(x), AVG(x), MIN(x), MAX(x) FROM t;
-- warning 01003: null value eliminated in set function
-- COL1: 4 COL2: 6e0 COL3: 1.5e0 COL4: 1e0 COL5: 2e0

EXPLAIN SELECT SUM(ALL x) FROM t;
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (X DOUBLE PRECISION, Y CHARACTER VARYING(10), N NUMERIC(5, 2), C CHARACTER(5))
-- EXPLAIN: GROUP BY (SUM(X) DOUBLE PRECISION)
-- EXPLAIN: EXPR (COL1 DOUBLE PRECISION)

-- # DISTINCT removes duplicates (after NULLs) before the function (E091-07).
SELECT COUNT(DISTINCT x), SUM(DISTINCT x), AVG(DISTINCT x), MIN(DISTINCT x), MAX(DISTINCT x) FROM t;
-- warning 01003: null value eliminated in set function
-- COL1: 2 COL2: 3e0 COL3: 1.5e0 COL4: 1e0 COL5: 2e0

EXPLAIN SELECT COUNT(DISTINCT x) FROM t;
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (X DOUBLE PRECISION, Y CHARACTER VARYING(10), N NUMERIC(5, 2), C CHARACTER(5))
-- EXPLAIN: GROUP BY (COUNT(DISTINCT X) INTEGER)
-- EXPLAIN: EXPR (COL1 INTEGER)

-- # Values are duplicates if they're equal with =.
SELECT COUNT(DISTINCT n), SUM(DISTINCT n), COUNT(DISTINCT c), COUNT(DISTINCT y) FROM t;
-- warning 01003: null value eliminated in set function
-- COL1: 2 COL2: 3.50 COL3: 2 COL4: 3

-- # The same function with and without DISTINCT are different results.
SELECT SUM(x), SUM(DISTINCT x), COUNT(*), COUNT(DISTINCT x) * 10 FROM t;
-- warning 01003: null value eliminated in set function
-- COL1: 6e0 COL2: 3e0 COL3: 5 COL4: 20

SELECT y, count(distinct x), sum(all x), count(x) FROM t GROUP BY y;
-- warning 01003: null value eliminated in set function
-- Y: a COL2: 1 COL3: 2e0 COL4: 2
-- Y: b COL2: 1 COL3: 2e0 COL4: 1
-- Y: c COL2: 1 COL3: 2e0 COL4: 1

SELECT SUM(DISTINCT x * 2e0) + 1e0 FROM t;
-- warning 01003: null value eliminated in set function
-- COL1: 7e0

-- # Integers, and an empty set.
CREATE TABLE t2 (x INT);
SELECT COUNT(DISTINCT x), SUM(DISTINCT x), AVG(DISTINCT x) FROM t2;
INSERT INTO t2 (x) VALUES (3), (3), (4), (5), (5);
SELECT COUNT(DISTINCT x), SUM(DISTINCT x), AVG(DISTINCT x), SUM(x), AVG(x) FROM t2;
-- msg: CREATE TABLE 1
-- COL1: 0 COL2: NULL COL3: NULL
-- msg: INSERT 5
-- COL1: 3 COL2: 12 COL3: 4 COL4: 20 COL5: 4

SELECT COUNT(DISTINCT *) FROM t;
-- error 42601: syntax error: unexpected "*"

SELECT COUNT(ALL *) FROM t;
-- error 42601: syntax error: unexpected "*"

SELECT SUM(DISTINCT) FROM t;
-- error 42601: syntax error: unexpected ")"

SELECT SUM(DISTINCT ALL x) FROM t;
-- error 42601: syntax error: unexpected ALL
