-- # NUMERIC without a precision or scale has a scale of 0 (Syntax Rules, 22),
-- # so 12.7 is truncated to 12 when stored (9.2, General Rules, 3.b.xv.2) or
-- # cast (6.13, General Rules, 8.a.i).
CREATE TABLE foo (bar NUMERIC);
INSERT INTO foo (bar) VALUES (12.7);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- BAR: 12

/* types */
VALUES CAST(12.7 AS NUMERIC);
-- COL1: 12 (NUMERIC)

-- # A value with too many digits before the point is out of range (9.2, General
-- # Rules, 3.b.xv.3), and the other rows are stored. Negating keeps the scale.
CREATE TABLE foo (bar NUMERIC(4, 2));
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

-- # An exact literal can leave out the 0 before the point, and is shown with
-- # exactly its scale (5.3, Syntax Rules, 22).
VALUES 0.001;
VALUES .23;
VALUES -.23;
-- COL1: 0.001
-- COL1: 0.23
-- COL1: -0.23

-- # A cast pads or truncates the digits after the point to the new scale (6.13,
-- # General Rules, 8.a.i), but losing a digit before the point is out of range
-- # (6.13, General Rules, 8.a.ii).
VALUES CAST(1.23 AS NUMERIC(10, 6));
VALUES CAST(1.23 AS NUMERIC(10, 2));
VALUES CAST(1.23 AS NUMERIC(10, 1));
VALUES CAST(1234.5 AS NUMERIC(3, 0));
VALUES CAST(-1.23 AS NUMERIC);
VALUES CAST(-12.34 AS NUMERIC(4, 2));
VALUES CAST(-12.34 AS NUMERIC(4, 1));
VALUES CAST(-12.34 AS NUMERIC(2, 0));
VALUES CAST(-12.34 AS NUMERIC(3, 2));
-- COL1: 1.230000
-- COL1: 1.23
-- COL1: 1.2
-- error 22003: numeric value out of range
-- COL1: -1
-- COL1: -12.34
-- COL1: -12.3
-- COL1: -12
-- error 22003: numeric value out of range

-- # Adding or subtracting gives the larger scale (6.30, Syntax Rules, 1.c.ii)
-- # and multiplying adds the scales (6.30, Syntax Rules, 1.c.iii). The scale
-- # of a division is implementation-defined (6.30, Syntax Rules, 1.c.iv): vsql
-- # keeps the larger scale, but at least 16 digits, and truncates the rest
-- # (6.30, General Rules, 5.b), so 1.24 / 1.5 is 0.8266666666666666.
VALUES CAST(1.23 AS NUMERIC(6, 2)) + CAST(1.5 AS NUMERIC(6, 3));
VALUES CAST(1.23 AS NUMERIC(6, 2)) - CAST(1.5 AS NUMERIC(6, 3));
VALUES CAST(1.23 AS NUMERIC(6, 2)) - CAST(-1.5 AS NUMERIC(6, 3));
VALUES CAST(1.23 AS NUMERIC(6, 2)) * CAST(1.5 AS NUMERIC(6, 3));
VALUES CAST(CAST(1.23 AS NUMERIC(6, 2)) * CAST(1.5 AS NUMERIC(6, 3)) AS NUMERIC(6, 4));
VALUES CAST(1.24 AS NUMERIC(6, 2)) / CAST(1.5 AS NUMERIC(6, 3));
VALUES CAST(1.24 AS NUMERIC(6, 3)) / CAST(1.5 AS NUMERIC(6, 2));
VALUES CAST(CAST(1.24 AS NUMERIC(6, 2)) / CAST(1.5 AS NUMERIC(6, 3)) AS NUMERIC(6, 4));
VALUES CAST(1.23 AS NUMERIC(3,2)) / 5;
-- COL1: 2.730
-- COL1: -0.270
-- COL1: 2.730
-- COL1: 1.84500
-- COL1: 1.8450
-- COL1: 0.8266666666666666
-- COL1: 0.8266666666666666
-- COL1: 0.8266
-- COL1: 0.2460000000000000

-- # NUMERIC on its own has a scale of 0, but the division still has a scale of
-- # 16, so it's 0.7142 after the cast.
VALUES CAST(CAST(5 AS NUMERIC(3,2)) / CAST(7 AS NUMERIC) AS NUMERIC(5,4));
-- COL1: 0.7142

-- # The sum has a scale of 3 and the product a scale of 5.
VALUES CAST(10.24 AS NUMERIC(4,2)) + CAST(12.123 AS NUMERIC(8,3));
VALUES CAST(10.24 AS NUMERIC(4,2)) * CAST(12.123 AS NUMERIC(8,3));
-- COL1: 22.363
-- COL1: 124.13952

-- # 2.00 / 3 is truncated to 0.6666666666666666 before it's multiplied, so the
-- # result is 1.9999999999999998, not 2 (explained in docs/numbers.rst).
VALUES CAST(2.00 AS NUMERIC(3,2)) / CAST(3 AS NUMERIC) * CAST(3 AS NUMERIC);
-- COL1: 1.9999999999999998

-- # Dividing a NUMERIC(3, 2) by a NUMERIC(5, 4) has a scale of 16, and room for
-- # 5 digits before the decimal point (3 - 2 + 4).
/* types */
VALUES CAST(5 AS NUMERIC(3,2)) / CAST(7 AS NUMERIC(5,4));
-- COL1: 0.7142857142857142 (NUMERIC(21, 16))

-- # An operand with a larger scale keeps it, and the integer part has room for
-- # a divisor as small as 0.0001.
/* types */
VALUES CAST(1 AS NUMERIC(20, 18)) / CAST(3 AS NUMERIC(5, 4));
VALUES CAST(99.99 AS NUMERIC(4, 2)) / CAST(0.0001 AS NUMERIC(5, 4));
VALUES CAST(-1 AS NUMERIC(2, 1)) / CAST(3 AS NUMERIC(2, 1));
VALUES CAST(1 AS NUMERIC(2, 1)) / CAST(-3 AS NUMERIC(2, 1));
-- COL1: 0.333333333333333333 (NUMERIC(24, 18))
-- COL1: 999900.0000000000000000 (NUMERIC(22, 16))
-- COL1: -0.3333333333333333 (NUMERIC(18, 16))
-- COL1: -0.3333333333333333 (NUMERIC(18, 16))

-- # The example from docs/numbers.rst: casting to a larger scale doesn't bring
-- # the dropped digits back.
VALUES CAST(CAST(2 AS NUMERIC(3,2)) / 3 AS NUMERIC(20,18));
-- COL1: 0.666666666666666600

-- # 1 / 3 with two scale-1 operands keeps 16 places, and casting to a smaller
-- # scale truncates them.
VALUES CAST(1 AS NUMERIC(2,1)) / CAST(3 AS NUMERIC(2,1));
VALUES CAST(CAST(1 AS NUMERIC(2,1)) / CAST(3 AS NUMERIC(2,1)) AS NUMERIC(10, 8));
-- COL1: 0.3333333333333333
-- COL1: 0.33333333

-- # A string is cast as the numeric literal it holds, which can be an
-- # approximate literal with an exponent (6.13, General Rules, 8.b.ii).
/* types */
VALUES CAST('1.5e-3' AS NUMERIC(10, 4));
-- COL1: 0.0015 (NUMERIC(10, 4))

/* types */
VALUES CAST('15e2' AS NUMERIC(10, 4));
-- COL1: 1500.0000 (NUMERIC(10, 4))
