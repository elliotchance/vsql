-- # MODE() WITHIN GROUP and PRODUCT are vsql extensions (V405-01 and V405-02),
-- # aggregate functions from PostgreSQL and DuckDB. Neither name is reserved.

/* setup */
CREATE TABLE t (g INT, x INT, s VARCHAR(10), d DATE, n NUMERIC(5, 2));
INSERT INTO t (g, x, s, d, n) VALUES
  (1, 3, 'b', DATE '2024-01-02', 1.50),
  (1, 1, 'a', DATE '2024-01-01', 2.00),
  (1, 3, 'b', DATE '2024-01-02', -0.50),
  (1, 1, 'a', DATE '2024-01-01', NULL),
  (2, 5, 'c', DATE '2024-03-01', 4.00),
  (2, NULL, NULL, NULL, 0.00),
  (2, 2, 'c', DATE '2024-03-01', 1.25);

-- # MODE is the most frequent value. On a tie, it's the first of them in the
-- # order of the sort key, so the smallest with ASC and the largest with DESC.
/* extensions V405-01 */
SELECT MODE() WITHIN GROUP (ORDER BY x), MODE() WITHIN GROUP (ORDER BY x ASC), MODE() WITHIN GROUP (ORDER BY x DESC) FROM t WHERE g = 1;
-- COL1: 1 COL2: 1 COL3: 3

-- # A more frequent value wins, wherever it is in the order.
/* extensions V405-01 */
SELECT MODE() WITHIN GROUP (ORDER BY v), MODE() WITHIN GROUP (ORDER BY v DESC) FROM (VALUES (1), (2), (3), (3), (4), (4), (4), (5)) AS u (v);
-- COL1: 4 COL2: 4

-- # The result has the type of the sort key, which can be any type.
/* extensions V405-01 */
/* types */
SELECT MODE() WITHIN GROUP (ORDER BY s), MODE() WITHIN GROUP (ORDER BY s DESC), MODE() WITHIN GROUP (ORDER BY d DESC), MODE() WITHIN GROUP (ORDER BY n) FROM t;
-- warning 01003: null value eliminated in set function
-- COL1: a (CHARACTER VARYING(10)) COL2: c (CHARACTER VARYING(10)) COL3: 2024-03-01 (DATE) COL4: -0.50 (NUMERIC(5, 2))

-- # Values that are equal with = are the same value.
/* extensions V405-01 */
SELECT MODE() WITHIN GROUP (ORDER BY v) FROM (VALUES (2.0), (1.5), (1.50)) AS u (v);
-- COL1: 1.50

-- # NULLs are ignored, and only NULLs (or no rows) is NULL.
/* extensions V405-01 */
SELECT MODE() WITHIN GROUP (ORDER BY x) FROM t WHERE g = 2;
-- warning 01003: null value eliminated in set function
-- COL1: 2

/* extensions V405-01 */
/* types */
SELECT MODE() WITHIN GROUP (ORDER BY x) FROM t WHERE x IS NULL;
-- warning 01003: null value eliminated in set function
-- COL1: NULL (INTEGER)

/* extensions V405-01 */
/* types */
SELECT MODE() WITHIN GROUP (ORDER BY s) FROM t WHERE g = 3;
-- COL1: NULL (CHARACTER VARYING(10))

-- # With GROUP BY and FILTER.
/* extensions V405-01 */
SELECT g, MODE() WITHIN GROUP (ORDER BY x DESC), MODE() WITHIN GROUP (ORDER BY x DESC) FILTER (WHERE x < 3) FROM t GROUP BY g ORDER BY g;
-- warning 01003: null value eliminated in set function
-- G: 1 COL2: 3 COL3: 1
-- G: 2 COL2: 5 COL3: 2

-- # The name is case-insensitive.
/* extensions V405-01 */
SELECT mode() WITHIN GROUP (ORDER BY x) FROM t WHERE g = 1;
-- COL1: 1

-- # MODE has no arguments, it must have WITHIN GROUP and one sort key.
/* extensions V405-01 */
SELECT MODE(x) WITHIN GROUP (ORDER BY x) FROM t;
-- error 42883: function does not exist: MODE(INTEGER) WITHIN GROUP (ORDER BY INTEGER)

SELECT MODE() FROM t;
-- error 42883: function does not exist: MODE()

SELECT MODE(x) FROM t;
-- error 42883: function does not exist: MODE(INTEGER)

/* extensions V405-01 */
SELECT MODE() WITHIN GROUP (ORDER BY x, s) FROM t;
-- error 42601: syntax error: MODE must have one sort key

/* extensions V405-01 */
SELECT MODE() WITHIN GROUP (ORDER BY MODE() WITHIN GROUP (ORDER BY x)) FROM t;
-- error 42601: syntax error: nested set function: MODE() WITHIN GROUP (ORDER BY MODE() WITHIN GROUP (ORDER BY X ASC) ASC)

-- # Only MODE can be followed by WITHIN GROUP, of the functions that aren't
-- # reserved words.
SELECT PRODUCT(x) WITHIN GROUP (ORDER BY x) FROM t;
-- error 42883: function does not exist: PRODUCT(INTEGER) WITHIN GROUP (ORDER BY INTEGER)

SELECT FOO() WITHIN GROUP (ORDER BY x) FROM t;
-- error 42883: function does not exist: FOO() WITHIN GROUP (ORDER BY INTEGER)

SELECT "PERCENTILE_CONT"() WITHIN GROUP (ORDER BY x) FROM t;
-- error 42883: function does not exist: PERCENTILE_CONT() WITHIN GROUP (ORDER BY INTEGER)

-- # PRODUCT multiplies the values. Zero and negative values work.
SELECT PRODUCT(x), PRODUCT(-x), PRODUCT(x - 1) FROM t WHERE g = 1;
-- COL1: 9 COL2: 9 COL3: 0

SELECT PRODUCT(v) FROM (VALUES (2), (-3), (4)) AS u (v);
-- COL1: -24

-- # The product of integers is an exact BIGINT, and anything else is a DOUBLE
-- # PRECISION.
/* types */
SELECT PRODUCT(CAST(x AS SMALLINT)), PRODUCT(x), PRODUCT(CAST(x AS BIGINT)), PRODUCT(n), PRODUCT(CAST(n AS DECIMAL(5, 2))), PRODUCT(CAST(x AS REAL)), PRODUCT(CAST(x AS DOUBLE PRECISION)) FROM t WHERE g = 1;
-- warning 01003: null value eliminated in set function
-- COL1: 9 (BIGINT) COL2: 9 (BIGINT) COL3: 9 (BIGINT) COL4: -1.5e0 (DOUBLE PRECISION) COL5: -1.5e0 (DOUBLE PRECISION) COL6: 9e0 (DOUBLE PRECISION) COL7: 9e0 (DOUBLE PRECISION)

-- # A zero product has no sign.
SELECT PRODUCT(n), PRODUCT(-n) FROM t WHERE g = 2;
-- COL1: 0e0 COL2: 0e0

-- # DISTINCT multiplies each value once, and ALL is the same as nothing.
SELECT PRODUCT(DISTINCT x), PRODUCT(ALL x) FROM t WHERE g = 1;
-- COL1: 3 COL2: 9

-- # NULLs are ignored, and only NULLs (or no rows) is NULL.
/* types */
SELECT PRODUCT(x), PRODUCT(n) FROM t WHERE g = 2;
-- warning 01003: null value eliminated in set function
-- COL1: 10 (BIGINT) COL2: 0e0 (DOUBLE PRECISION)

/* types */
SELECT PRODUCT(x), PRODUCT(n) FROM t WHERE g = 3;
-- COL1: NULL (BIGINT) COL2: NULL (DOUBLE PRECISION)

-- # With GROUP BY and FILTER.
SELECT g, PRODUCT(x), PRODUCT(x) FILTER (WHERE x > 1) FROM t GROUP BY g ORDER BY g;
-- warning 01003: null value eliminated in set function
-- G: 1 COL2: 9 COL3: 9
-- G: 2 COL2: 10 COL3: 10

-- # A product of integers that's out of the range of a BIGINT is an error,
-- # whatever the order of the values. The smallest BIGINT is in range.
SELECT PRODUCT(v) FROM (VALUES (CAST(4294967296 AS BIGINT)), (CAST(4294967296 AS BIGINT))) AS u (v);
-- error 22003: numeric value out of range

SELECT PRODUCT(v) FROM (VALUES (CAST(4611686018427387904 AS BIGINT)), (CAST(2 AS BIGINT))) AS u (v);
-- error 22003: numeric value out of range

SELECT PRODUCT(v) FROM (VALUES (CAST(4611686018427387904 AS BIGINT)), (CAST(-2 AS BIGINT))) AS u (v);
-- COL1: -9223372036854775808

SELECT PRODUCT(v) FROM (VALUES (CAST(-9223372036854775808 AS BIGINT)), (CAST(1 AS BIGINT))) AS u (v);
-- COL1: -9223372036854775808

SELECT PRODUCT(v) FROM (VALUES (CAST(-9223372036854775808 AS BIGINT)), (CAST(-1 AS BIGINT))) AS u (v);
-- error 22003: numeric value out of range

SELECT PRODUCT(v) FROM (VALUES (CAST(9223372036854775807 AS BIGINT)), (CAST(9223372036854775807 AS BIGINT)), (CAST(0 AS BIGINT))) AS u (v);
-- COL1: 0

SELECT PRODUCT(v) FROM (VALUES (1e200), (1e200)) AS u (v);
-- error 22003: numeric value out of range

-- # A value that isn't a number is an error.
SELECT PRODUCT(s) FROM t;
-- error 42883: function does not exist: PRODUCT(CHARACTER VARYING(10))

SELECT product(DISTINCT s IS NULL) FROM t;
-- error 42883: function does not exist: PRODUCT(BOOLEAN)

-- # Only an aggregate function can have DISTINCT or FILTER.
SELECT ROUND(DISTINCT x) FROM t;
-- error 42601: syntax error: ROUND is not an aggregate function

SELECT ROUND(x) FILTER (WHERE x > 0) FROM t;
-- error 42601: syntax error: ROUND is not an aggregate function

-- # A column or a table can be called mode or product.
CREATE TABLE mode (mode INT, product INT);
INSERT INTO mode (mode, product) VALUES (1, 2), (1, 3);
/* extensions V405-01 */
SELECT mode, product, MODE() WITHIN GROUP (ORDER BY mode), PRODUCT(product) FROM mode GROUP BY mode, product ORDER BY product;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- MODE: 1 PRODUCT: 2 COL3: 1 COL4: 2
-- MODE: 1 PRODUCT: 3 COL3: 1 COL4: 3

CREATE TABLE product (x INT);
INSERT INTO product (x) VALUES (6);
SELECT PRODUCT(x) FROM product;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 6

-- # PRODUCT is an aggregate function wherever SUM is.
SELECT * FROM t WHERE PRODUCT(x) > 1;
-- error 42601: syntax error: an aggregate function cannot be used in WHERE

SELECT SUM(PRODUCT(x)) FROM t;
-- error 42601: syntax error: nested set function: SUM(PRODUCT(X))

SELECT g, PRODUCT(x) FROM t;
-- error 42803: column G must be in the GROUP BY clause or used in an aggregate function

CREATE TABLE c (a INT CHECK (PRODUCT(a) > 0));
-- error 42601: syntax error: an aggregate function cannot be used in a CHECK constraint

/* extensions V202-03 */
SELECT g FROM t GROUP BY g HAVING PRODUCT(x) > 6 ORDER BY PRODUCT(x);
-- warning 01003: null value eliminated in set function
-- G: 1
-- G: 2

-- # The flagger.
/* flags */
/* extensions V202-03 */
SELECT PRODUCT(x) FROM t ORDER BY PRODUCT(x);
-- flags: F868, V202-03, V405-02
-- warning 01003: null value eliminated in set function
-- COL1: 90

/* flags */
/* extensions V202-03 */
SELECT g FROM t GROUP BY g ORDER BY PRODUCT(DISTINCT x);
-- flags: F868, V202-03, V405-02
-- warning 01003: null value eliminated in set function
-- G: 1
-- G: 2

/* flags */
/* extensions V405-01 */
SELECT MODE() WITHIN GROUP (ORDER BY x), PRODUCT(x) FROM t WHERE g = 1;
-- flags: V405-01, V405-02
-- COL1: 1 COL2: 9
