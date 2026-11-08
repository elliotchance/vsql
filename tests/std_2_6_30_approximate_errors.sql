-- # Infinity and NaN aren't SQL values, so a result that's too large for the
-- # type is out of range, and functions check their arguments.
VALUES CAST(1e300 AS REAL);
-- error 22003: numeric value out of range

CREATE TABLE t (r REAL);
INSERT INTO t (r) VALUES (1e300);
-- msg: CREATE TABLE 1
-- error 22003: numeric value out of range

-- # A literal too large for a DOUBLE PRECISION is out of range (5.3, Syntax
-- # Rules, 23), but one too small rounds to zero (5.3, General Rules, 5).
VALUES 1e400;
-- error 22003: numeric value out of range

VALUES 1e-400;
-- COL1: 0e0

-- # A CAST that would lose every significant digit is out of range (6.13,
-- # General Rules, 9.a.ii).
VALUES CAST(1e-50 AS REAL);
-- error 22003: numeric value out of range

-- # A result with an exponent outside the range of its type is out of range
-- # (6.29, General Rules, 6), and so is EXP or POWER (General Rules, 13.b).
VALUES 1e308 * 10e0;
-- error 22003: numeric value out of range

VALUES CAST(3e38 AS REAL) * CAST(2e0 AS REAL);
-- error 22003: numeric value out of range

VALUES EXP(1000e0);
-- error 22003: numeric value out of range

VALUES POWER(10e0, 400e0);
-- error 22003: numeric value out of range

-- # SQRT(x) is POWER(x, 0.5) (Syntax Rules, 19), so a negative is an invalid
-- # argument for the power function (General Rules, 14.e).
VALUES SQRT(-1e0);
-- error 2201F: invalid argument for power function

-- # LN of zero or a negative is an invalid argument (General Rules, 12.b).
-- # LOG10 is a LOG with base 10 (Syntax Rules, 15), which is out of range
-- # instead (General Rules, 11.b).
VALUES LN(0e0);
-- error 2201E: invalid argument for natural logarithm

VALUES LN(-1e0);
-- error 2201E: invalid argument for natural logarithm

VALUES LOG10(0e0);
-- error 22003: numeric value out of range

VALUES LOG10(-5e0);
-- error 22003: numeric value out of range

-- # POWER of zero to a negative, or of a negative to a fraction, is invalid
-- # (General Rules, 14.b and 14.e). A negative to a whole number, or zero to
-- # zero or more, is fine (General Rules, 14.c, 14.d, 14.f and 14.g).
VALUES POWER(0e0, -1e0);
-- error 2201F: invalid argument for power function

VALUES POWER(-8e0, 0.5e0);
-- error 2201F: invalid argument for power function

VALUES ROW(POWER(-2e0, 3e0), POWER(-2e0, 2e0), POWER(0e0, 0e0), POWER(0e0, 2e0));
-- COL1: -8e0 COL2: 4e0 COL3: 1e0 COL4: 0e0

-- # ASIN and ACOS are only defined from -1 to 1 (General Rules, 10.b.i.1 and
-- # 10.b.ii.1).
VALUES ASIN(2e0);
-- error 22003: numeric value out of range

VALUES ACOS(-2e0);
-- error 22003: numeric value out of range

VALUES ROW(ASIN(1e0), ACOS(-1e0));
-- COL1: 1.570796326795e0 COL2: 3.14159265359e0

-- # A result that isn't zero, but is too small for the type, is also out of
-- # range.
VALUES 1e-300 * 1e-300;
-- error 22003: numeric value out of range

VALUES 1e-300 / 1e300;
-- error 22003: numeric value out of range

VALUES CAST(1e-30 AS REAL) * CAST(1e-30 AS REAL);
-- error 22003: numeric value out of range

VALUES CAST(1e-30 AS REAL) / CAST(1e30 AS REAL);
-- error 22003: numeric value out of range

VALUES EXP(-1000e0);
-- error 22003: numeric value out of range

VALUES POWER(10e0, -400e0);
-- error 22003: numeric value out of range

-- # A denormal is in the range, and a result of zero is still zero.
VALUES ROW(1e-160 * 1e-160 > 0e0, 0e0 * 1e-300, 0e0 / 1e300, POWER(0e0, 2e0));
-- COL1: TRUE COL2: 0e0 COL3: 0e0 COL4: 0e0

VALUES CAST(0e0 AS REAL) * CAST(1e-30 AS REAL);
-- COL1: 0e0
