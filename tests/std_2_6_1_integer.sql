-- # INTEGER is a 32-bit binary integer (Syntax Rules, 28). One past either end
-- # of its range is out of range and isn't stored (9.2, General Rules,
-- # 3.b.xv.3), but the limits themselves are.
CREATE TABLE foo (x INTEGER);
INSERT INTO foo (x) VALUES (-2147483649);
INSERT INTO foo (x) VALUES (-2147483648);
INSERT INTO foo (x) VALUES (2147483647);
INSERT INTO foo (x) VALUES (2147483648);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- error 22003: numeric value out of range
-- msg: INSERT 1
-- msg: INSERT 1
-- error 22003: numeric value out of range
-- X: -2147483648
-- X: 2147483647

-- # Casting an INTEGER to SMALLINT fails when the value doesn't fit (6.13,
-- # General Rules, 8.a.ii). Casting it to a larger integer or an approximate
-- # type always works.
CREATE TABLE foo (x INTEGER);
INSERT INTO foo (x) VALUES (123);
SELECT CAST(x AS SMALLINT) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 123

CREATE TABLE foo (x INTEGER);
INSERT INTO foo (x) VALUES (123456);
SELECT CAST(x AS SMALLINT) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 22003: numeric value out of range

CREATE TABLE foo (x INTEGER);
INSERT INTO foo (x) VALUES (123);
SELECT CAST(x AS INTEGER) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 123

CREATE TABLE foo (x INTEGER);
INSERT INTO foo (x) VALUES (123);
SELECT CAST(x AS BIGINT) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 123

CREATE TABLE foo (x INTEGER);
INSERT INTO foo (x) VALUES (123);
SELECT CAST(x AS REAL) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 123e0

CREATE TABLE foo (x INTEGER);
INSERT INTO foo (x) VALUES (123);
SELECT CAST(x AS DOUBLE PRECISION) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 123e0

-- # Arithmetic with a SMALLINT on either side gives an INTEGER. A result beyond
-- # the 32-bit range is out of range rather than wrapping around (6.29, General
-- # Rules, 5.a).
/* types */
VALUES CAST(123 AS INTEGER) + 53;
-- COL1: 176 (INTEGER)

/* types */
VALUES 53 + CAST(123 AS INTEGER);
-- COL1: 176 (INTEGER)

VALUES CAST(500000000 AS INTEGER) + 2000000000;
-- error 22003: numeric value out of range

VALUES 500000000 + CAST(2000000000 AS INTEGER);
-- error 22003: numeric value out of range

/* types */
VALUES CAST(123 AS INTEGER) - 53;
-- COL1: 70 (INTEGER)

/* types */
VALUES 53 - CAST(123 AS INTEGER);
-- COL1: -70 (INTEGER)

VALUES CAST(-2000000000 AS INTEGER) - 500000000;
-- error 22003: numeric value out of range

VALUES -500000000 - CAST(2000000000 AS INTEGER);
-- error 22003: numeric value out of range

/* types */
VALUES CAST(123 AS INTEGER) * 53;
-- COL1: 6519 (INTEGER)

/* types */
VALUES -53 * CAST(123 AS INTEGER);
-- COL1: -6519 (INTEGER)

VALUES CAST(-300000 AS INTEGER) * 200000;
-- error 22003: numeric value out of range

VALUES -300000 * CAST(200000 AS INTEGER);
-- error 22003: numeric value out of range

-- # Integer division keeps the integer type and truncates towards zero (6.29,
-- # General Rules, 5.b). CAST(3.2 AS INTEGER) truncates to 3 and CAST(0.1 AS
-- # INTEGER) to 0 (6.13, General Rules, 8.a.i), so the last divides by zero
-- # (6.29, General Rules, 4).
/* types */
VALUES CAST(123 AS INTEGER) / 53;
-- COL1: 2 (INTEGER)

/* types */
VALUES -123 / CAST(53 AS INTEGER);
-- COL1: -2 (INTEGER)

/* types */
VALUES -90000 / CAST(3.2 AS INTEGER);
-- COL1: -30000 (INTEGER)

VALUES CAST(-30000 AS INTEGER) / 0;
-- error 22012: division by zero

VALUES -90000 / CAST(0.1 AS INTEGER);
-- error 22012: division by zero

-- # Results that fit keep the INTEGER type. -2147483648 has no positive
-- # INTEGER, so multiplying it by -1 or negating it is out of range (6.29,
-- # General Rules, 5.a), and so is dividing it by -1 (6.29, General Rules,
-- # 5.b).
/* types */
VALUES CAST(100000 AS INTEGER) - 1;
-- COL1: 99999 (INTEGER)

/* types */
VALUES CAST(100000 AS INTEGER) * 2;
-- COL1: 200000 (INTEGER)

VALUES CAST(-2147483648 AS INTEGER) * -1;
-- error 22003: numeric value out of range

VALUES -CAST(-2147483648 AS INTEGER);
-- error 22003: numeric value out of range

VALUES -CAST(-2147483647 AS INTEGER);
-- COL1: 2147483647

VALUES CAST(-2147483648 AS INTEGER) / -1;
-- error 22003: numeric value out of range

-- # A string is cast as the numeric literal it holds (6.13, General Rules,
-- # 8.b.ii), so the smallest INTEGER can be written with its sign.
VALUES CAST('-2147483648' AS INTEGER);
-- COL1: -2147483648
