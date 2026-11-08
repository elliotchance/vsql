-- # BIGINT is a 64-bit binary integer (Syntax Rules, 28), so values next to
-- # either end of its range are stored and read back exactly.
CREATE TABLE foo (x BIGINT);
INSERT INTO foo (x) VALUES (-9223372036854775807);
INSERT INTO foo (x) VALUES (9223372036854775807);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- X: -9223372036854775807
-- X: 9223372036854775807

-- # Casting a BIGINT to a smaller integer type works while the value fits,
-- # otherwise it's out of range (6.13, General Rules, 8.a.ii). Any BIGINT can
-- # be cast to REAL or DOUBLE PRECISION, but a number can't be cast to a
-- # BOOLEAN at all (6.13, Syntax Rules, 7).
CREATE TABLE foo (x BIGINT);
INSERT INTO foo (x) VALUES (123);
SELECT CAST(x AS SMALLINT) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 123

CREATE TABLE foo (x BIGINT);
INSERT INTO foo (x) VALUES (1000000000000);
SELECT CAST(x AS SMALLINT) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 22003: numeric value out of range

CREATE TABLE foo (x BIGINT);
INSERT INTO foo (x) VALUES (123456);
SELECT CAST(x AS INTEGER) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 123456

CREATE TABLE foo (x BIGINT);
INSERT INTO foo (x) VALUES (1000000000000);
SELECT CAST(x AS INT) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 22003: numeric value out of range

CREATE TABLE foo (x BIGINT);
INSERT INTO foo (x) VALUES (1000000000000);
SELECT CAST(x AS BIGINT) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 1000000000000

CREATE TABLE foo (x BIGINT);
INSERT INTO foo (x) VALUES (1000000000000);
SELECT CAST(x AS REAL) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 1e+12

CREATE TABLE foo (x BIGINT);
INSERT INTO foo (x) VALUES (1000000000000);
SELECT CAST(x AS DOUBLE PRECISION) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 1e+12

CREATE TABLE foo (x BIGINT);
INSERT INTO foo (x) VALUES (1000000000000);
SELECT CAST(x AS BOOLEAN) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 42846: cannot coerce BIGINT to BOOLEAN

-- # Arithmetic with a SMALLINT on either side gives a BIGINT. A result beyond
-- # the 64-bit range is out of range rather than wrapping around (6.29, General
-- # Rules, 5.a).
/* types */
VALUES CAST(123 AS BIGINT) + 53;
-- COL1: 176 (BIGINT)

/* types */
VALUES 53 + CAST(123 AS BIGINT);
-- COL1: 176 (BIGINT)

VALUES CAST(5000000000000000000 AS BIGINT) + 5000000000000000000;
-- error 22003: numeric value out of range

VALUES 5000000000000000000 + CAST(5000000000000000000 AS BIGINT);
-- error 22003: numeric value out of range

/* types */
VALUES CAST(123 AS BIGINT) - 53;
-- COL1: 70 (BIGINT)

/* types */
VALUES 53 - CAST(123 AS BIGINT);
-- COL1: -70 (BIGINT)

VALUES CAST(-5000000000000000000 AS BIGINT) - 5000000000000000000;
-- error 22003: numeric value out of range

VALUES -5000000000000000000 - CAST(5000000000000000000 AS BIGINT);
-- error 22003: numeric value out of range

/* types */
VALUES CAST(123 AS BIGINT) * 53;
-- COL1: 6519 (BIGINT)

/* types */
VALUES -53 * CAST(123 AS BIGINT);
-- COL1: -6519 (BIGINT)

VALUES CAST(-5000000000000000000 AS BIGINT) * 200000;
-- error 22003: numeric value out of range

-- # Results past the 32-bit range, or right at the 64-bit limits (including
-- # -9223372036854775808, which has no positive BIGINT), are fine.
VALUES CAST(3000000000 AS BIGINT) + 1;
-- COL1: 3000000001

VALUES CAST(-3000000000 AS BIGINT) - 1;
-- COL1: -3000000001

VALUES CAST(9000000000 AS BIGINT) * 2;
-- COL1: 18000000000

VALUES CAST(9223372036854775806 AS BIGINT) + 1;
-- COL1: 9223372036854775807

VALUES CAST(-9223372036854775807 AS BIGINT) - 1;
-- COL1: -9223372036854775808

VALUES CAST(4611686018427387904 AS BIGINT) * -2;
-- COL1: -9223372036854775808

VALUES -5000000000000000000 * CAST(5000000000000000000 AS BIGINT);
-- error 22003: numeric value out of range

-- # Integer division keeps the integer type and truncates towards zero (6.29,
-- # General Rules, 5.b). CAST(3.2 AS BIGINT) truncates to 3 and CAST(0.1 AS
-- # BIGINT) to 0 (6.13, General Rules, 8.a.i), so the last divides by zero
-- # (6.29, General Rules, 4).
/* types */
VALUES CAST(123 AS BIGINT) / 53;
-- COL1: 2 (BIGINT)

/* types */
VALUES -123 / CAST(53 AS BIGINT);
-- COL1: -2 (BIGINT)

/* types */
VALUES -5000000000000000000 / CAST(3.2 AS BIGINT);
-- COL1: -1666666666666666666 (BIGINT)

VALUES CAST(-5000000000000000000 AS BIGINT) / 0;
-- error 22012: division by zero

VALUES -5000000000000000000 / CAST(0.1 AS BIGINT);
-- error 22012: division by zero

-- # -9223372036854775808 can't be negated (6.29, General Rules, 5.a) or divided
-- # by -1 (6.29, General Rules, 5.b), because the result is one more than the
-- # largest BIGINT.
VALUES -CAST(-9223372036854775808 AS BIGINT);
-- error 22003: numeric value out of range

VALUES -CAST(-9223372036854775807 AS BIGINT);
-- COL1: 9223372036854775807

VALUES CAST(-9223372036854775808 AS BIGINT) / -1;
-- error 22003: numeric value out of range
