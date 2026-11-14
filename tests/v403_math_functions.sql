-- # ROUND, TRUNC, SIGN, PI, RANDOM, ATAN2, DEGREES, RADIANS and CBRT are vsql
-- # extensions (V403-02 to V403-10), the mathematical functions that most other
-- # databases have but the standard doesn't.

/* setup */
CREATE TABLE t (x INT, n NUMERIC(5, 3), d DOUBLE PRECISION, p INT);
INSERT INTO t (x, n, d, p) VALUES (1, 12.345, 1.5e0, 1);

-- # ROUND of an exact number rounds half away from zero. Without decimal places
-- # the scale is 0, and there's one more digit because rounding up may need it.
/* types */
VALUES ROW(ROUND(9.5), ROUND(-9.5), ROUND(9.4), ROUND(-9.4));
-- COL1: 10 (NUMERIC(2)) COL2: -10 (NUMERIC(2)) COL3: 9 (NUMERIC(2)) COL4: -9 (NUMERIC(2))

-- # With constant decimal places, they're the scale of the result.
/* types */
VALUES ROW(ROUND(1.255, 2), ROUND(-1.255, 2), ROUND(1.254, 2));
-- COL1: 1.26 (NUMERIC(4, 2)) COL2: -1.26 (NUMERIC(4, 2)) COL3: 1.25 (NUMERIC(4, 2))

-- # Negative decimal places round to the left of the decimal point.
/* types */
VALUES ROW(ROUND(1250, -2), ROUND(-1249, -2), ROUND(999, -3), ROUND(5, -4));
-- COL1: 1300 (NUMERIC(5)) COL2: -1200 (NUMERIC(5)) COL3: 1000 (NUMERIC(5)) COL4: 0 (NUMERIC(5))

-- # More decimal places than the scale doesn't change the number, even a huge
-- # number of them.
/* types */
VALUES ROW(ROUND(1.256, 10), ROUND(5, 9223372036854775807), ROUND(5, -9223372036854775807));
-- COL1: 1.256 (NUMERIC(4, 3)) COL2: 5 (NUMERIC(5)) COL3: 0 (NUMERIC(5))

-- # Decimal places that aren't a constant can't be the scale, so the scale of
-- # the number is kept.
/* types */
SELECT ROUND(n, p), ROUND(n, 2), ROUND(n, -1), ROUND(n) FROM t;
-- COL1: 12.300 (NUMERIC(5, 3)) COL2: 12.35 (NUMERIC(5, 2)) COL3: 10 (NUMERIC(3)) COL4: 12 (NUMERIC(3))

-- # An integer is converted to a NUMERIC, and a DECIMAL returns a NUMERIC.
/* types */
SELECT ROUND(x), ROUND(CAST(n AS DECIMAL(5, 3)), 1), ROUND(CAST(9.99 AS NUMERIC(3, 2)), 1) FROM t;
-- COL1: 1 (NUMERIC(10)) COL2: 12.3 (NUMERIC(4, 1)) COL3: 10.0 (NUMERIC(3, 1))

-- # A NUMERIC without a precision has no precision after rounding.
/* types */
SELECT ROUND(CAST(n AS NUMERIC), 1) FROM t;
-- COL1: 12 (NUMERIC)

-- # ROUND of an approximate number also rounds half away from zero.
/* types */
VALUES ROW(ROUND(1.5e0), ROUND(-2.5e0), ROUND(1.2345e0, 2), ROUND(12345e0, -2));
-- COL1: 2e0 (DOUBLE PRECISION) COL2: -3e0 (DOUBLE PRECISION) COL3: 1.23e0 (DOUBLE PRECISION) COL4: 12300e0 (DOUBLE PRECISION)

-- # A DOUBLE PRECISION that is too large to have a fraction, or decimal places
-- # beyond what it can hold, doesn't change.
SELECT ROUND(d, 400), ROUND(d, -400), ROUND(1e300, 20) FROM t;
-- COL1: 1.5e0 COL2: 0e0 COL3: 1e+300

SELECT ROUND(1e300, -300) FROM t;
-- COL1: 1e+300

SELECT ROUND(1.7e308, -308) FROM t;
-- error 22003: numeric value out of range

-- # TRUNC truncates towards zero.
/* types */
VALUES ROW(TRUNC(9.99), TRUNC(-9.99), TRUNC(-1.259, 2), TRUNC(CAST(NULL AS NUMERIC(1, 1))), TRUNC(1999, -3));
-- COL1: 9 (NUMERIC(1)) COL2: -9 (NUMERIC(1)) COL3: -1.25 (NUMERIC(3, 2)) COL4: NULL (NUMERIC(1)) COL5: 1000 (NUMERIC(5))

/* types */
VALUES ROW(TRUNC(-1.99e0), TRUNC(1.99e0, 1), TRUNC(1999e0, -3));
-- COL1: -1e0 (DOUBLE PRECISION) COL2: 1.9e0 (DOUBLE PRECISION) COL3: 1000e0 (DOUBLE PRECISION)

-- # The decimal places must be an integer, and NULL decimal places are NULL.
SELECT ROUND(1.5, 1.5) FROM t;
-- error 42883: function does not exist: ROUND(NUMERIC(2, 1), NUMERIC(2, 1))

/* types */
SELECT ROUND(1.5, CAST(NULL AS INT)), ROUND(CAST(NULL AS INT)) FROM t;
-- COL1: NULL (NUMERIC(2, 1)) COL2: NULL (NUMERIC(10))

SELECT ROUND(1, 2, 3) FROM t;
-- error 42883: function does not exist: ROUND(SMALLINT, SMALLINT, SMALLINT)

SELECT TRUNC('a') FROM t;
-- error 42883: function does not exist: TRUNC(CHARACTER(1))

-- # SIGN is -1, 0 or 1. An integer keeps its type.
/* types */
VALUES ROW(SIGN(-5), SIGN(0), SIGN(CAST(7 AS INTEGER)), SIGN(CAST(-7 AS BIGINT)));
-- COL1: -1 (SMALLINT) COL2: 0 (SMALLINT) COL3: 1 (INTEGER) COL4: -1 (BIGINT)

/* types */
VALUES ROW(SIGN(-2.5), SIGN(0.0), SIGN(2.5));
-- COL1: -1 (NUMERIC(1)) COL2: 0 (NUMERIC(1)) COL3: 1 (NUMERIC(1))

/* types */
VALUES ROW(SIGN(-2.5e0), SIGN(0e0), SIGN(2.5e0), SIGN(CAST(1 AS REAL)));
-- COL1: -1e0 (DOUBLE PRECISION) COL2: 0e0 (DOUBLE PRECISION) COL3: 1e0 (DOUBLE PRECISION) COL4: 1e0 (DOUBLE PRECISION)

-- # PI has no arguments.
/* types */
VALUES PI();
-- COL1: 3.14159265359e0 (DOUBLE PRECISION)

SELECT PI(1) FROM t;
-- error 42883: function does not exist: PI(SMALLINT)

-- # RANDOM is at least 0 and less than 1. It's a different value each time, so
-- # it can't be in a CHECK.
/* types */
SELECT RANDOM() >= 0 AND RANDOM() < 1 AS ok FROM t;
-- OK: TRUE (BOOLEAN)

CREATE TABLE c (a DOUBLE PRECISION, CHECK (a < RANDOM()));
-- error 42601: syntax error: non-deterministic function RANDOM cannot be used in a CHECK constraint

-- # The other functions are deterministic, so they can be.
CREATE TABLE c (a DOUBLE PRECISION, CHECK (a < PI()));
-- msg: CREATE TABLE 1

-- # ATAN2(Y, X) is the angle of the point (X, Y), between -π and π.
/* types */
VALUES ROW(ATAN2(1, 1), ATAN2(1, -1), ATAN2(-1, -1), ATAN2(0, 0));
-- COL1: 0.785398163397e0 (DOUBLE PRECISION) COL2: 2.356194490192e0 (DOUBLE PRECISION) COL3: -2.356194490192e0 (DOUBLE PRECISION) COL4: 0e0 (DOUBLE PRECISION)

-- # DEGREES and RADIANS convert between them.
/* types */
VALUES ROW(DEGREES(PI()), RADIANS(180), DEGREES(-1), RADIANS(0.5));
-- COL1: 180e0 (DOUBLE PRECISION) COL2: 3.14159265359e0 (DOUBLE PRECISION) COL3: -57.295779513082e0 (DOUBLE PRECISION) COL4: 0.00872664626e0 (DOUBLE PRECISION)

VALUES DEGREES(1e307);
-- error 22003: numeric value out of range

-- # CBRT is the cube root, which can be negative.
/* types */
VALUES ROW(CBRT(27), CBRT(-8), CBRT(2));
-- COL1: 3e0 (DOUBLE PRECISION) COL2: -2e0 (DOUBLE PRECISION) COL3: 1.259921049895e0 (DOUBLE PRECISION)

-- # None of the names are reserved.
CREATE TABLE round (round INT, trunc INT, sign INT, pi INT, random INT, atan2 INT, degrees INT, radians INT, cbrt INT);
INSERT INTO round (round, trunc, sign, pi, random, atan2, degrees, radians, cbrt) VALUES (1, 2, 3, 4, 5, 6, 7, 8, 9);
SELECT round, cbrt FROM round;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- ROUND: 1 CBRT: 9

-- # The flagger.
/* flags */
SELECT ROUND(n), TRUNC(n), SIGN(n), PI(), RANDOM() < 1, ATAN2(d, d), DEGREES(d), RADIANS(d), CBRT(d) FROM t;
-- flags: T031, V403-02, V403-03, V403-04, V403-05, V403-06, V403-07, V403-08, V403-09, V403-10
-- COL1: 12 COL2: 12 COL3: 1 COL4: 3.14159265359e0 COL5: TRUE COL6: 0.785398163397e0 COL7: 85.943669269623e0 COL8: 0.02617993878e0 COL9: 1.144714242553e0
