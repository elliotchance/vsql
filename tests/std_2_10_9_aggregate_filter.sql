/* setup */
CREATE TABLE t (g INT, x INT);
INSERT INTO t (g, x) VALUES (1, 1), (1, 2), (1, NULL), (2, 5), (2, -3);
CREATE TABLE products (city VARCHAR(20), price FLOAT);
INSERT INTO products (city, price) VALUES ('New York', 8.05e0), ('New York', 18.05e0), ('San Francisco', 7.5e0), ('San Francisco', 17.5e0), ('San Francisco', NULL);

-- # FILTER only passes the rows where its condition is True to the function
-- # (General Rules, 4.a), and doesn't change the other functions. The row where
-- # x is NULL is filtered out, so there's no NULL to eliminate.
SELECT COUNT(*), COUNT(*) FILTER (WHERE x > 1), SUM(x) FILTER (WHERE x > 1), SUM(x) FROM t;
-- warning 01003: null value eliminated in set function
-- COL1: 5 COL2: 2 COL3: 7 COL4: 5

SELECT COUNT(*) FILTER (WHERE x > 1), SUM(x) FILTER (WHERE x > 1), MIN(x) FILTER (WHERE x > 1) FROM t;
-- COL1: 2 COL2: 7 COL3: 2

-- # With GROUP BY, each group is filtered separately. A group with no rows left
-- # is NULL (or 0 for COUNT), and DISTINCT is applied to the rows that are
-- # left.
SELECT g, COUNT(*) FILTER (WHERE x IS NULL), MAX(x) FILTER (WHERE x < 0), AVG(DISTINCT x) FILTER (WHERE g = 1) FROM t GROUP BY g;
-- warning 01003: null value eliminated in set function
-- G: 1 COL2: 1 COL3: NULL COL4: 1
-- G: 2 COL2: 0 COL3: -3 COL4: NULL

SELECT COUNT(x) FILTER (WHERE x IS NULL), COUNT(ALL x) FILTER (WHERE g = 2), COUNT(DISTINCT g) FILTER (WHERE x > 0) FROM t;
-- warning 01003: null value eliminated in set function
-- COL1: 0 COL2: 2 COL3: 2

SELECT SUM(x) FILTER (WHERE x > 100), COUNT(*) FILTER (WHERE x > 100) FROM t;
-- COL1: NULL COL2: 0

-- # A filtered function can be used in an expression. A NULL x is neither > 1
-- # nor <= 1, so it's in neither count.
SELECT COUNT(*) FILTER (WHERE x > 1) + COUNT(*) FILTER (WHERE x <= 1) FROM t;
-- COL1: 4

-- # Only True passes the filter, so FALSE and UNKNOWN pass no rows.
SELECT COUNT(*) FILTER (WHERE TRUE), COUNT(*) FILTER (WHERE FALSE), COUNT(*) FILTER (WHERE UNKNOWN) FROM t;
-- COL1: 5 COL2: 0 COL3: 0

-- # A filtered function can be used in HAVING, and in ORDER BY (V202-03).
SELECT g FROM t GROUP BY g HAVING COUNT(*) FILTER (WHERE x > 0) > 1;
-- G: 1

/* extensions V202-03 */
SELECT g, SUM(x) FILTER (WHERE x > 0) FROM t GROUP BY g ORDER BY SUM(x) FILTER (WHERE x > 0) DESC;
-- G: 2 COL2: 5
-- G: 1 COL2: 3

-- # The filter can use any column of the group, including a grouping column.
SELECT g, SUM(x) FILTER (WHERE g > 1) FROM t GROUP BY g;
-- G: 1 COL2: NULL
-- G: 2 COL2: 2

-- # In a subquery, the filter can use the subquery's columns. Its columns are
-- # aggregated like the argument's, so SUM(t1.x) with a filter on t2 is
-- # computed over the rows of t2: two rows pass, so it's twice t1.x.
SELECT g, (SELECT COUNT(*) FILTER (WHERE t2.x > t2.g) FROM t t2) FROM t t1 GROUP BY g;
-- G: 1 COL2: 2
-- G: 2 COL2: 2

SELECT (SELECT SUM(t1.x) FILTER (WHERE t2.x > 1) FROM t t2) FROM t t1;
-- warning 01003: null value eliminated in set function
-- COL1: 2
-- COL1: 4
-- COL1: NULL
-- COL1: 10
-- COL1: -6

-- # A NULL price is in neither filter.
SELECT city, COUNT(*) FILTER (WHERE price > 10e0), AVG(price) FILTER (WHERE price < 10e0) FROM products GROUP BY city;
-- CITY: New York COL2: 1 COL3: 8.05e0
-- CITY: San Francisco COL2: 1 COL3: 7.5e0

-- # FILTER is kept when the plan is shown.
/* extensions V001-01 */
EXPLAIN SELECT COUNT(*) FILTER (WHERE x > 1), SUM(x) FILTER (WHERE x > 1) FROM t;
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (G INTEGER, X INTEGER)
-- EXPLAIN: GROUP BY (COUNT(*) FILTER (WHERE X > 1) INTEGER, SUM(X) FILTER (WHERE X > 1) BIGINT)
-- EXPLAIN: EXPR (COL1 INTEGER, COL2 BIGINT)

-- # The filter must be a boolean, and can't contain an aggregate function (6.9,
-- # Syntax Rules, 5), a subquery or an outer reference (Syntax Rules, 8).
SELECT COUNT(*) FILTER (WHERE x) FROM t;
-- error 42804: data type mismatch in FILTER: expected BOOLEAN but got INTEGER

SELECT SUM(x) FILTER (WHERE COUNT(*) > 1) FROM t;
-- error 42601: syntax error: nested set function: SUM(X) FILTER (WHERE COUNT(*) > 1)

SELECT COUNT(*) FILTER (WHERE SUM(x) > 1) FROM t;
-- error 42601: syntax error: nested set function: COUNT(*) FILTER (WHERE SUM(X) > 1)

SELECT SUM(x) FILTER (WHERE x IN (SELECT x FROM t)) FROM t;
-- error 42601: syntax error: a subquery cannot be used in an aggregate function

SELECT (SELECT COUNT(*) FILTER (WHERE t1.x > 1) FROM t t2) FROM t t1;
-- error 42601: syntax error: outer reference in FILTER: T1.X

SELECT (SELECT MAX(t2.x) FILTER (WHERE t1.x > 1) FROM t t2) FROM t t1;
-- error 42601: syntax error: outer reference in FILTER: T1.X

-- # Only an aggregate function can have a FILTER, and it needs WHERE.
SELECT x FILTER (WHERE x > 1) FROM t;
-- error 42601: syntax error: unexpected FILTER at line 1, column 10 near "SELECT x FILTER ("

SELECT ABS(x) FILTER (WHERE x > 1) FROM t;
-- error 42601: syntax error: unexpected FILTER at line 1, column 15 near "(x) FILTER ("

SELECT COUNT(*) FILTER (x > 1) FROM t;
-- error 42601: syntax error: unexpected identifier at line 1, column 25 near ") FILTER (x >", expecting WHERE

-- # A filtered function is still an aggregate function: it can't be in WHERE,
-- # and the query is grouped, so other columns must be grouping columns.
SELECT x FROM t WHERE COUNT(*) FILTER (WHERE x > 1) > 0;
-- error 42601: syntax error: an aggregate function cannot be used in WHERE

SELECT g, COUNT(*) FILTER (WHERE x > 0) FROM t;
-- error 42803: column G must be in the GROUP BY clause or used in an aggregate function
