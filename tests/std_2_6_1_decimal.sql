-- # DECIMAL without a precision or scale has a scale of 0 (Syntax Rules, 22),
-- # so 12.7 is truncated to 12 when stored (9.2, General Rules, 3.b.xv.2) or
-- # cast (6.13, General Rules, 8.a.i).
CREATE TABLE foo (bar DECIMAL);
INSERT INTO foo (bar) VALUES (12.7);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- BAR: 12

/* types */
VALUES CAST(12.7 AS DECIMAL);
-- COL1: 12 (DECIMAL)

-- # A value with too many digits before the point is out of range (9.2, General
-- # Rules, 3.b.xv.3), and the other rows are stored. Negating keeps the scale.
CREATE TABLE foo (bar DECIMAL(4, 2));
INSERT INTO foo (bar) VALUES (1.23);
INSERT INTO foo (bar) VALUES (12345);
INSERT INTO foo (bar) VALUES (-1.24);
SELECT * FROM foo;
SELECT -bar FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 22003: numeric value out of range
-- msg: INSERT 1
-- BAR: 1.23
-- BAR: -1.24
-- COL1: -1.23
-- COL1: 1.24

-- # A cast pads or truncates the digits after the point to the new scale (6.13,
-- # General Rules, 8.a.i), but losing a digit before the point is out of range
-- # (6.13, General Rules, 8.a.ii).
VALUES CAST(1.23 AS DECIMAL(10, 6));
-- COL1: 1.230000

VALUES CAST(1.23 AS DECIMAL(10, 2));
-- COL1: 1.23

VALUES CAST(1.23 AS DECIMAL(10, 1));
-- COL1: 1.2

VALUES CAST(1234.5 AS DECIMAL(3, 0));
-- error 22003: numeric value out of range

VALUES CAST(-1.23 AS DECIMAL);
-- COL1: -1

VALUES CAST(-12.34 AS DECIMAL(4, 2));
-- COL1: -12.34

VALUES CAST(-12.34 AS DECIMAL(4, 1));
-- COL1: -12.3

VALUES CAST(-12.34 AS DECIMAL(2, 0));
-- COL1: -12

VALUES CAST(-12.34 AS DECIMAL(3, 2));
-- error 22003: numeric value out of range

-- # Adding or subtracting gives the larger scale (6.29, Syntax Rules, 1.c.ii)
-- # and multiplying adds the scales (6.29, Syntax Rules, 1.c.iii). vsql also
-- # adds the scales for division (6.29, Syntax Rules, 1.c.iv) and truncates the
-- # rest (6.29, General Rules, 5.b), so 1.24 / 1.5 is 0.82666 and a SMALLINT
-- # divisor counts as a scale of 0.
VALUES CAST(1.23 AS DECIMAL(6, 2)) + CAST(1.5 AS DECIMAL(6, 3));
-- COL1: 2.730

VALUES CAST(1.23 AS DECIMAL(6, 2)) - CAST(1.5 AS DECIMAL(6, 3));
-- COL1: -0.270

VALUES CAST(1.23 AS DECIMAL(6, 2)) - CAST(-1.5 AS DECIMAL(6, 3));
-- COL1: 2.730

VALUES CAST(1.23 AS DECIMAL(6, 2)) * CAST(1.5 AS DECIMAL(6, 3));
-- COL1: 1.84500

VALUES CAST(CAST(1.23 AS DECIMAL(6, 2)) * CAST(1.5 AS DECIMAL(6, 3)) AS DECIMAL(6, 4));
-- COL1: 1.8450

VALUES CAST(1.24 AS DECIMAL(6, 2)) / CAST(1.5 AS DECIMAL(6, 3));
-- COL1: 0.82666

VALUES CAST(1.24 AS DECIMAL(6, 3)) / CAST(1.5 AS DECIMAL(6, 2));
-- COL1: 0.82666

VALUES CAST(CAST(1.24 AS DECIMAL(6, 2)) / CAST(1.5 AS DECIMAL(6, 3)) AS DECIMAL(6, 4));
-- COL1: 0.8266

/* types */
VALUES CAST(1.23 AS DECIMAL(3,2)) / 5;
-- COL1: 0.24 (DECIMAL(8, 2))

-- # A DECIMAL has exactly the scale of its type (#223), so 1.23 / 5 is 0.24,
-- # not 0.246, before it's cast.
/* types */
VALUES CAST(CAST(1.23 AS DECIMAL(3,2)) / 5 AS DECIMAL(4, 3));
-- COL1: 0.240 (DECIMAL(4, 3))

-- # 1.23 / 5 is truncated to 0.24 before it's multiplied, so the result is
-- # 1.20, not 1.23 (explained in docs/numbers.rst).
VALUES CAST(1.23 AS DECIMAL(3,2)) / 5 * 5;
-- COL1: 1.20

-- # 1.23 / 11 keeps a scale of 2, so it's 0.11 (docs/numbers.rst).
VALUES CAST(1.23 AS DECIMAL(3,2)) / 11;
-- COL1: 0.11

-- # The division is a DECIMAL(8, 6), so it's 0.714285 before the cast, which
-- # truncates it to 0.7142 rather than rounding (docs/numbers.rst).
VALUES CAST(CAST(5 AS DECIMAL(3,2)) / CAST(7 AS DECIMAL(5,4)) AS DECIMAL(5,4));
-- COL1: 0.7142

-- # The result types from docs/numbers.rst: the sum is a DECIMAL(9, 3) and the
-- # product a DECIMAL(12, 5).
/* types */
VALUES CAST(10.24 AS DECIMAL(4,2)) + CAST(12.123 AS DECIMAL(8,3));
-- COL1: 22.363 (DECIMAL(9, 3))

/* types */
VALUES CAST(10.24 AS DECIMAL(4,2)) * CAST(12.123 AS DECIMAL(8,3));
-- COL1: 124.13952 (DECIMAL(12, 5))

-- # 1 / 3 with two scale-1 operands keeps two places, and casting to a larger
-- # scale doesn't bring the dropped digits back.
VALUES CAST(1 AS DECIMAL(2,1)) / CAST(3 AS DECIMAL(2,1));
-- COL1: 0.33

VALUES CAST(CAST(1 AS DECIMAL(2,1)) / CAST(3 AS DECIMAL(2,1)) AS DECIMAL(10, 8));
-- COL1: 0.33000000

-- # DECIMAL and NUMERIC give the same values.
VALUES CAST(CAST(1 AS NUMERIC(2,1)) / CAST(3 AS NUMERIC(2,1)) AS NUMERIC(10, 8));
-- COL1: 0.33000000

-- # A DECIMAL compares by value with integers, a large DECIMAL with a BIGINT,
-- # and with approximate numbers (8.2, General Rules, 2). It can also be cast
-- # or assigned to REAL or DOUBLE PRECISION.
VALUES CAST(8.25 AS DECIMAL(5,2)) > 1;
-- COL1: TRUE

VALUES 1 < CAST(8.25 AS DECIMAL(5,2));
-- COL1: TRUE

VALUES CAST(8 AS DECIMAL(5,2)) = 8;
-- COL1: TRUE

VALUES CAST(100.5 AS DECIMAL(5,1)) > 99;
-- COL1: TRUE

VALUES CAST(9223372036854775807 AS DECIMAL(19,0)) > CAST(9223372036854775806 AS BIGINT);
-- COL1: TRUE

VALUES CAST(8.25 AS DECIMAL(5,2)) > 1e0;
-- COL1: TRUE

VALUES CAST(CAST(8.25 AS DECIMAL(5,2)) AS DOUBLE PRECISION);
-- COL1: 8.25e0

VALUES CAST(CAST(8.25 AS DECIMAL(5,2)) AS REAL);
-- COL1: 8.25e0

CREATE TABLE t (d DOUBLE PRECISION, x DECIMAL(5,2));
INSERT INTO t (d, x) VALUES (0, 8.25);
UPDATE t SET d = x;
SELECT * FROM t WHERE x > 8;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: UPDATE 1
-- D: 8.25e0 X: 8.25

-- # DEC is another spelling of DECIMAL.
/* types */
CREATE TABLE foo (a DEC, b DEC(5), c DEC(5, 2));
INSERT INTO foo (a, b, c) VALUES (12.7, 12345, -1.25);
SELECT * FROM foo;
VALUES CAST(1.25 AS DEC(4, 3));
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- A: 12 (DECIMAL) B: 12345 (DECIMAL(5)) C: -1.25 (DECIMAL(5, 2))
-- COL1: 1.250 (DECIMAL(4, 3))
