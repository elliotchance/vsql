-- # RANDOM(min, max), RANDOM_NORMAL and RANDOM_BINARY are vsql extensions
-- # (V403-24 to V403-26). The values are random, so the tests check their
-- # types, ranges and distributions instead.

/* define many */
CREATE TABLE ten (x INT);
INSERT INTO ten (x) VALUES (1), (2), (3), (4), (5), (6), (7), (8), (9), (10);
CREATE TABLE many AS (SELECT a.x FROM ten a, ten b, ten c, ten d) WITH DATA;

-- # RANDOM(min, max) has the declared type of min and max combined, like a
-- # CASE or a UNION.
/* types */
VALUES ROW(RANDOM(1.00, 1.00), RANDOM(CAST(2.5 AS DECIMAL(4, 2)), 2.5), RANDOM(1, 1.5) BETWEEN 1 AND 1.5);
-- COL1: 1.00 (NUMERIC(3, 2)) COL2: 2.50 (DECIMAL(4, 2)) COL3: TRUE (BOOLEAN)

/* types */
VALUES ROW(RANDOM(1, 1), RANDOM(5000000000, 5000000000), RANDOM(CAST(7 AS SMALLINT), CAST(7 AS SMALLINT)), RANDOM(0.00, 0.00), RANDOM(0, 0));
-- COL1: 1 (INTEGER) COL2: 5000000000 (BIGINT) COL3: 7 (SMALLINT) COL4: 0.00 (NUMERIC(3, 2)) COL5: 0 (INTEGER)

/* types */
VALUES ROW(RANDOM(2.5E0, 2.5E0), RANDOM(CAST(1.5 AS REAL), CAST(1.5 AS REAL)), RANDOM(1, 1E0), RANDOM(CAST(1.5 AS DECFLOAT(16)), CAST(1.5 AS DECFLOAT(16))));
-- COL1: 2.5e0 (DOUBLE PRECISION) COL2: 1.5e0 (REAL) COL3: 1e0 (DOUBLE PRECISION) COL4: 1.5 (DECFLOAT(16))

-- # An exact number is from min to max, including both ends, with the scale of
-- # the result. Every value is equally likely, so both ends of a small range
-- # are reached.
/* include many */
SELECT MIN(r), MAX(r), COUNT(DISTINCT r) FROM (SELECT RANDOM(1, 2) AS r FROM many) t;
SELECT MIN(r), MAX(r), COUNT(DISTINCT r) FROM (SELECT RANDOM(1.00, 1.05) AS r FROM many) t;
SELECT MIN(r) >= -3, MAX(r) <= 3, COUNT(DISTINCT r) FROM (SELECT RANDOM(CAST(-3 AS SMALLINT), CAST(3 AS SMALLINT)) AS r FROM many) t;
SELECT MIN(r) >= -0.5, MAX(r) <= 0.5, COUNT(DISTINCT r) FROM (SELECT RANDOM(CAST(-0.5 AS DECIMAL(3, 1)), CAST(0.5 AS DECIMAL(3, 1))) AS r FROM many) t;
-- COL1: 1 COL2: 2 COL3: 2
-- COL1: 1.00 COL2: 1.05 COL3: 6
-- COL1: TRUE COL2: TRUE COL3: 7
-- COL1: TRUE COL2: TRUE COL3: 11

-- # A NUMERIC without a precision uses the larger scale of the two values.
/* types */
VALUES RANDOM(CAST(5 AS NUMERIC), ABS(CAST(5 AS NUMERIC)));
-- COL1: 5 (NUMERIC)

-- # The whole range of a BIGINT doesn't overflow.
/* include many */
SELECT COUNT(*) FROM many WHERE RANDOM(-9223372036854775808, 9223372036854775807) BETWEEN -9223372036854775808 AND 9223372036854775807;
SELECT COUNT(*) FROM many WHERE RANDOM(9223372036854775806, 9223372036854775807) >= 9223372036854775806;
-- COL1: 10000
-- COL1: 10000

-- # An approximate number (or a DECFLOAT) is at least min and less than max.
/* include many */
SELECT MIN(r) >= 0, MAX(r) < 100 FROM (SELECT RANDOM(0E0, 100E0) AS r FROM many) t;
SELECT MIN(r) >= 1, MAX(r) < 1.0001 FROM (SELECT RANDOM(CAST(1 AS REAL), CAST(1.0001 AS REAL)) AS r FROM many) t;
SELECT MIN(r) >= -1, MAX(r) < 1 FROM (SELECT RANDOM(CAST(-1 AS DECFLOAT), CAST(1 AS DECFLOAT)) AS r FROM many) t;
SELECT MIN(r) >= -1E308, MAX(r) < 1E308 FROM (SELECT RANDOM(-1E308, 1E308) AS r FROM many) t;
-- COL1: TRUE COL2: TRUE
-- COL1: TRUE COL2: TRUE
-- COL1: TRUE COL2: TRUE
-- COL1: TRUE COL2: TRUE

-- # NULL is NULL.
/* types */
VALUES ROW(RANDOM(CAST(NULL AS INT), 1), RANDOM(1.5, CAST(NULL AS NUMERIC(2, 1))), RANDOM(CAST(NULL AS DOUBLE PRECISION), 1E0));
-- COL1: NULL (INTEGER) COL2: NULL (NUMERIC(2, 1)) COL3: NULL (DOUBLE PRECISION)

-- # min can't be greater than max.
VALUES RANDOM(6, 1);
VALUES RANDOM(1.5, 1.4);
VALUES RANDOM(2E0, 1E0);
VALUES RANDOM(CAST(2 AS DECFLOAT), CAST(1 AS DECFLOAT));
-- error 22023: invalid parameter value: RANDOM minimum 6 is greater than maximum 1
-- error 22023: invalid parameter value: RANDOM minimum 1.5 is greater than maximum 1.4
-- error 22023: invalid parameter value: RANDOM minimum 2e0 is greater than maximum 1e0
-- error 22023: invalid parameter value: RANDOM minimum 2 is greater than maximum 1

-- # Only numbers can be a range.
VALUES RANDOM('a', 'b');
-- error 42883: function does not exist: RANDOM(CHARACTER(1), CHARACTER(1))

-- # RANDOM_NORMAL is a DOUBLE PRECISION with a mean of 0 and a standard
-- # deviation of 1, unless they're given.
/* types */
VALUES ROW(RANDOM_NORMAL() < 1000, RANDOM_NORMAL(100) > -1000, RANDOM_NORMAL(100, 0), RANDOM_NORMAL(-2.5, 0E0));
-- COL1: TRUE (BOOLEAN) COL2: TRUE (BOOLEAN) COL3: 100e0 (DOUBLE PRECISION) COL4: -2.5e0 (DOUBLE PRECISION)

/* include many */
SELECT ABS(AVG(r)) < 0.2, ABS(STDDEV_POP(r) - 1) < 0.2 FROM (SELECT RANDOM_NORMAL() AS r FROM many) t;
SELECT ABS(AVG(r) - 5) < 0.2, ABS(STDDEV_POP(r) - 1) < 0.2 FROM (SELECT RANDOM_NORMAL(5) AS r FROM many) t;
SELECT ABS(AVG(r) - 100) < 3, ABS(STDDEV_POP(r) - 15) < 3 FROM (SELECT RANDOM_NORMAL(100, 15) AS r FROM many) t;
-- COL1: TRUE COL2: TRUE
-- COL1: TRUE COL2: TRUE
-- COL1: TRUE COL2: TRUE

/* types */
VALUES ROW(RANDOM_NORMAL(CAST(NULL AS DOUBLE PRECISION)), RANDOM_NORMAL(1, CAST(NULL AS DOUBLE PRECISION)));
-- COL1: NULL (DOUBLE PRECISION) COL2: NULL (DOUBLE PRECISION)

VALUES RANDOM_NORMAL(0, -1);
-- error 22023: invalid parameter value: RANDOM_NORMAL standard deviation must not be negative

-- # RANDOM_BINARY(n) is n random bytes, a BINARY VARYING(n) when n is a
-- # constant.
/* types */
VALUES ROW(RANDOM_BINARY(0), OCTET_LENGTH(RANDOM_BINARY(1)), OCTET_LENGTH(RANDOM_BINARY(16)), RANDOM_BINARY(16) <> RANDOM_BINARY(16));
-- COL1:  (BINARY VARYING(0)) COL2: 1 (INTEGER) COL3: 16 (INTEGER) COL4: TRUE (BOOLEAN)

/* types */
SELECT OCTET_LENGTH(RANDOM_BINARY(x)), RANDOM_BINARY(CAST(NULL AS INT)) FROM (VALUES 1000) t (x);
-- COL1: 1000 (INTEGER) COL2: NULL (BINARY VARYING(10485760))

VALUES RANDOM_BINARY(-1);
VALUES RANDOM_BINARY(10485761);
VALUES RANDOM_BINARY(1.5);
-- error 22023: invalid parameter value: RANDOM_BINARY length must be from 0 to 10485760
-- error 22023: invalid parameter value: RANDOM_BINARY length must be from 0 to 10485760
-- error 42883: function does not exist: RANDOM_BINARY(NUMERIC(2, 1))

-- # They're a different value each time, so they can't be in a CHECK.
CREATE TABLE c (a INT, CHECK (a < RANDOM(1, 6)));
CREATE TABLE c (a DOUBLE PRECISION, CHECK (a < RANDOM_NORMAL()));
CREATE TABLE c (a VARBINARY(10), CHECK (a <> RANDOM_BINARY(10)));
-- error 42601: syntax error: non-deterministic function RANDOM cannot be used in a CHECK constraint
-- error 42601: syntax error: non-deterministic function RANDOM_NORMAL cannot be used in a CHECK constraint
-- error 42601: syntax error: non-deterministic function RANDOM_BINARY cannot be used in a CHECK constraint

-- # The flagger.
/* include many */
/* flags */
SELECT RANDOM(1, 1), RANDOM_NORMAL(2, 0), OCTET_LENGTH(RANDOM_BINARY(3)) FROM ten WHERE x = 1;
-- flags: V403-24, V403-25, V403-26
-- COL1: 1 COL2: 2e0 COL3: 3
