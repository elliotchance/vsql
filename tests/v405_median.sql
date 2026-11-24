-- # MEDIAN is a vsql extension (V405-03), an aggregate function from Oracle,
-- # Snowflake and DuckDB. It's the same as PERCENTILE_CONT(0.5) WITHIN GROUP
-- # (ORDER BY CAST(x AS DOUBLE PRECISION)). The name isn't reserved.

/* setup */
CREATE TABLE t (g INT, x INT, s VARCHAR(10), n NUMERIC(5, 2), f DOUBLE PRECISION);
INSERT INTO t (g, x, s, n, f) VALUES
  (1, 3, 'b', 1.50, 2.5e0),
  (1, 1, 'a', 2.00, -1e0),
  (1, 7, 'b', -0.50, 4e0),
  (1, NULL, 'a', NULL, NULL),
  (2, 5, 'c', 4.00, 1e0),
  (2, 2, 'c', 1.25, 3e0);

-- # The middle value of an odd number of values, in any order.
/* types */
SELECT MEDIAN(x), MEDIAN(n), MEDIAN(f) FROM t WHERE g = 1;
-- warning 01003: null value eliminated in set function
-- COL1: 3e0 (DOUBLE PRECISION) COL2: 1.5e0 (DOUBLE PRECISION) COL3: 2.5e0 (DOUBLE PRECISION)

-- # The average of the middle two values of an even number of values. The
-- # median of integers isn't truncated, unlike PERCENTILE_CONT(0.5).
SELECT MEDIAN(x), PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY x), MEDIAN(n), MEDIAN(f) FROM t WHERE g = 2;
-- COL1: 3.5e0 COL2: 3e0 COL3: 2.625e0 COL4: 2e0

VALUES (SELECT MEDIAN(x) FROM (VALUES 1, 2) AS u (x));
-- COL1: 1.5e0

-- # Negative values, and a single value.
SELECT MEDIAN(v) FROM (VALUES (-4), (-1), (-2), (-10)) AS u (v);
-- COL1: -3e0

SELECT MEDIAN(v) FROM (VALUES (CAST(-7 AS SMALLINT))) AS u (v);
-- COL1: -7e0

-- # Any number can be used.
/* types */
SELECT MEDIAN(CAST(x AS SMALLINT)), MEDIAN(CAST(x AS BIGINT)), MEDIAN(CAST(n AS DECIMAL(5, 2))), MEDIAN(CAST(f AS REAL)), MEDIAN(CAST(x AS DECFLOAT)) FROM t WHERE g = 2;
-- COL1: 3.5e0 (DOUBLE PRECISION) COL2: 3.5e0 (DOUBLE PRECISION) COL3: 2.625e0 (DOUBLE PRECISION) COL4: 2e0 (DOUBLE PRECISION) COL5: 3.5e0 (DOUBLE PRECISION)

-- # NULLs are ignored, and only NULLs (or no rows) is NULL.
/* types */
SELECT MEDIAN(x) FROM t WHERE x IS NULL;
-- warning 01003: null value eliminated in set function
-- COL1: NULL (DOUBLE PRECISION)

/* types */
SELECT MEDIAN(n) FROM t WHERE g = 3;
-- COL1: NULL (DOUBLE PRECISION)

-- # With GROUP BY, FILTER and HAVING.
SELECT g, MEDIAN(x), MEDIAN(x) FILTER (WHERE x < 5) FROM t GROUP BY g HAVING MEDIAN(x) > 1 ORDER BY g;
-- warning 01003: null value eliminated in set function
-- G: 1 COL2: 3e0 COL3: 2e0
-- G: 2 COL2: 3.5e0 COL3: 2e0

-- # In a correlated subquery.
SELECT g, (SELECT MEDIAN(u.x) FROM t AS u WHERE u.g = t.g) FROM t WHERE x = 1;
-- warning 01003: null value eliminated in set function
-- G: 1 COL2: 3e0

-- # The name is case-insensitive, and ALL is the same as nothing.
SELECT median(x), MEDIAN(ALL x) FROM t WHERE g = 2;
-- COL1: 3.5e0 COL2: 3.5e0

-- # DISTINCT isn't allowed.
SELECT MEDIAN(DISTINCT x) FROM t;
-- error 42601: syntax error: MEDIAN cannot be used with DISTINCT

-- # A value that isn't a number is an error.
SELECT MEDIAN(s) FROM t;
-- error 42883: function does not exist: MEDIAN(CHARACTER VARYING(10))

SELECT MEDIAN(x > 1) FROM t;
-- error 42883: function does not exist: MEDIAN(BOOLEAN)

-- # MEDIAN has one argument, and isn't an ordered set function.
SELECT MEDIAN(x, x) FROM t;
-- error 42883: function does not exist: MEDIAN(INTEGER, INTEGER)

SELECT MEDIAN(x) WITHIN GROUP (ORDER BY x) FROM t;
-- error 42883: function does not exist: MEDIAN(INTEGER) WITHIN GROUP (ORDER BY INTEGER)

-- # MEDIAN is an aggregate function wherever SUM is.
SELECT * FROM t WHERE MEDIAN(x) > 1;
-- error 42601: syntax error: an aggregate function cannot be used in WHERE

SELECT SUM(MEDIAN(x)) FROM t;
-- error 42601: syntax error: nested set function: SUM(MEDIAN(X))

SELECT g, MEDIAN(x) FROM t;
-- error 42803: column G must be in the GROUP BY clause or used in an aggregate function

-- # A column or a table can be called median.
CREATE TABLE median (median INT);
INSERT INTO median (median) VALUES (1), (4);
SELECT MEDIAN(median) FROM median;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- COL1: 2.5e0

-- # The flagger.
/* flags */
SELECT MEDIAN(x) FROM t WHERE g = 2;
-- flags: V405-03
-- COL1: 3.5e0

/* flags */
/* extensions V202-03 */
SELECT g FROM t GROUP BY g ORDER BY MEDIAN(x) DESC;
-- flags: F868, V202-03, V405-03
-- warning 01003: null value eliminated in set function
-- G: 2
-- G: 1
