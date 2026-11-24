-- # BIT_AND, BIT_OR and BIT_XOR are vsql extensions (V405-04, V405-05 and
-- # V405-06), aggregate functions from PostgreSQL, MySQL, BigQuery and DuckDB.
-- # None of the names are reserved.

/* setup */
CREATE TABLE t (g INT, x INT, s SMALLINT, b BIGINT, n NUMERIC(5, 2), c VARCHAR(10));
INSERT INTO t (g, x, s, b, n, c) VALUES
  (1, 12, 12, 12, 1.50, 'a'),
  (1, 10, 10, 10, 2.00, 'b'),
  (1, NULL, NULL, NULL, NULL, NULL),
  (1, 6, 6, 6, 0.50, 'c'),
  (2, 5, 5, 5, 4.00, 'd'),
  (2, 5, 5, 5, 1.25, 'e'),
  (2, 3, 3, 3, 1.25, 'f');

-- # The bits that are set in every value, in any value, and in an odd number
-- # of values.
SELECT BIT_AND(x), BIT_OR(x), BIT_XOR(x) FROM t WHERE g = 1;
-- warning 01003: null value eliminated in set function
-- COL1: 0 COL2: 14 COL3: 0

SELECT BIT_AND(x), BIT_OR(x), BIT_XOR(x) FROM t WHERE g = 2;
-- COL1: 1 COL2: 7 COL3: 3

-- # The result has the type of the argument, which is an integer.
/* types */
SELECT BIT_AND(s), BIT_OR(s), BIT_XOR(s), BIT_AND(x), BIT_OR(x), BIT_XOR(x), BIT_AND(b), BIT_OR(b), BIT_XOR(b) FROM t WHERE g = 2;
-- COL1: 1 (SMALLINT) COL2: 7 (SMALLINT) COL3: 3 (SMALLINT) COL4: 1 (INTEGER) COL5: 7 (INTEGER) COL6: 3 (INTEGER) COL7: 1 (BIGINT) COL8: 7 (BIGINT) COL9: 3 (BIGINT)

-- # Negative values are two's complement.
SELECT BIT_AND(v), BIT_OR(v), BIT_XOR(v) FROM (VALUES (-1), (6)) AS u (v);
-- COL1: 6 COL2: -1 COL3: -7

/* types */
SELECT BIT_AND(v), BIT_OR(v), BIT_XOR(v) FROM (VALUES (CAST(-32768 AS SMALLINT)), (CAST(32767 AS SMALLINT))) AS u (v);
-- COL1: 0 (SMALLINT) COL2: -1 (SMALLINT) COL3: -1 (SMALLINT)

/* types */
SELECT BIT_AND(v), BIT_OR(v), BIT_XOR(v) FROM (VALUES (CAST(-9223372036854775808 AS BIGINT)), (CAST(-1 AS BIGINT))) AS u (v);
-- COL1: -9223372036854775808 (BIGINT) COL2: -1 (BIGINT) COL3: 9223372036854775807 (BIGINT)

/* types */
SELECT BIT_AND(v), BIT_OR(v), BIT_XOR(v) FROM (VALUES (-2147483648), (-2)) AS u (v);
-- COL1: -2147483648 (INTEGER) COL2: -2 (INTEGER) COL3: 2147483646 (INTEGER)

-- # A single value is itself.
SELECT BIT_AND(v), BIT_OR(v), BIT_XOR(v) FROM (VALUES (-5)) AS u (v);
-- COL1: -5 COL2: -5 COL3: -5

-- # NULLs are ignored, and only NULLs (or no rows) is NULL, unlike MySQL.
/* types */
SELECT BIT_AND(x), BIT_OR(s), BIT_XOR(b) FROM t WHERE x IS NULL;
-- warning 01003: null value eliminated in set function
-- COL1: NULL (INTEGER) COL2: NULL (SMALLINT) COL3: NULL (BIGINT)

/* types */
SELECT BIT_AND(x), BIT_OR(x), BIT_XOR(x) FROM t WHERE g = 3;
-- COL1: NULL (INTEGER) COL2: NULL (INTEGER) COL3: NULL (INTEGER)

-- # DISTINCT uses each value once, which only changes BIT_XOR. ALL is the same
-- # as nothing.
SELECT BIT_AND(DISTINCT x), BIT_OR(DISTINCT x), BIT_XOR(DISTINCT x), BIT_XOR(ALL x) FROM t WHERE g = 2;
-- COL1: 1 COL2: 7 COL3: 6 COL4: 3

-- # With GROUP BY, FILTER and HAVING.
SELECT g, BIT_OR(x), BIT_XOR(x) FILTER (WHERE x > 4) FROM t GROUP BY g HAVING BIT_AND(x) < 2 ORDER BY g;
-- warning 01003: null value eliminated in set function
-- G: 1 COL2: 14 COL3: 0
-- G: 2 COL2: 7 COL3: 0

-- # In a correlated subquery.
SELECT g, (SELECT BIT_OR(u.x) FROM t AS u WHERE u.g = t.g) FROM t WHERE x = 3;
-- G: 2 COL2: 7

-- # The names are case-insensitive.
SELECT bit_and(x), Bit_Or(x), bit_xor(x) FROM t WHERE g = 2;
-- COL1: 1 COL2: 7 COL3: 3

-- # The value must be an integer.
SELECT BIT_AND(n) FROM t;
-- error 42883: function does not exist: BIT_AND(NUMERIC(5, 2))

SELECT BIT_OR(CAST(x AS DOUBLE PRECISION)) FROM t;
-- error 42883: function does not exist: BIT_OR(DOUBLE PRECISION)

SELECT BIT_XOR(c) FROM t;
-- error 42883: function does not exist: BIT_XOR(CHARACTER VARYING(10))

SELECT BIT_AND(x > 1) FROM t;
-- error 42883: function does not exist: BIT_AND(BOOLEAN)

-- # They're aggregate functions wherever SUM is.
SELECT * FROM t WHERE BIT_OR(x) > 1;
-- error 42601: syntax error: an aggregate function cannot be used in WHERE

SELECT SUM(BIT_AND(x)) FROM t;
-- error 42601: syntax error: nested set function: SUM(BIT_AND(X))

-- # A column or a table can be called bit_and, bit_or or bit_xor.
CREATE TABLE bit_or (bit_and INT, bit_xor INT);
INSERT INTO bit_or (bit_and, bit_xor) VALUES (1, 2), (4, 2);
SELECT BIT_OR(bit_and), BIT_XOR(bit_xor) FROM bit_or;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- COL1: 5 COL2: 0

-- # The flagger.
/* flags */
SELECT BIT_AND(x), BIT_OR(x), BIT_XOR(x) FROM t WHERE g = 2;
-- flags: V405-04, V405-05, V405-06
-- COL1: 1 COL2: 7 COL3: 3

/* flags */
/* extensions V202-03 */
SELECT g FROM t GROUP BY g ORDER BY BIT_OR(x);
-- flags: F868, V202-03, V405-05
-- warning 01003: null value eliminated in set function
-- G: 2
-- G: 1

-- # The examples in the docs.
SELECT BIT_AND(x) FROM (VALUES (12), (10), (14)) AS t (x);
-- COL1: 8

SELECT BIT_OR(x) FROM (VALUES (1), (4), (8)) AS t (x);
-- COL1: 13

SELECT g, BIT_OR(x) FROM (VALUES (1, 1), (1, 2), (2, 4)) AS t (g, x) GROUP BY g ORDER BY g;
-- G: 1 COL2: 3
-- G: 2 COL2: 4

SELECT BIT_XOR(x), BIT_XOR(DISTINCT x) FROM (VALUES (5), (5), (3)) AS t (x);
-- COL1: 3 COL2: 6
