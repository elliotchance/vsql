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
-- COL1: 1.230000

VALUES CAST(1.23 AS NUMERIC(10, 2));
-- COL1: 1.23

VALUES CAST(1.23 AS NUMERIC(10, 1));
-- COL1: 1.2

VALUES CAST(1234.5 AS NUMERIC(3, 0));
-- error 22003: numeric value out of range

VALUES CAST(-1.23 AS NUMERIC);
-- COL1: -1

VALUES CAST(-12.34 AS NUMERIC(4, 2));
-- COL1: -12.34

VALUES CAST(-12.34 AS NUMERIC(4, 1));
-- COL1: -12.3

VALUES CAST(-12.34 AS NUMERIC(2, 0));
-- COL1: -12

VALUES CAST(-12.34 AS NUMERIC(3, 2));
-- error 22003: numeric value out of range

-- # Adding or subtracting gives the larger scale (6.29, Syntax Rules, 1.c.ii)
-- # and multiplying adds the scales (6.29, Syntax Rules, 1.c.iii). vsql also
-- # adds the scales for division (6.29, Syntax Rules, 1.c.iv) and truncates the
-- # rest (6.29, General Rules, 5.b), so 1.24 / 1.5 is 0.82666 and 1.23 / 5 is
-- # 0.24.
VALUES CAST(1.23 AS NUMERIC(6, 2)) + CAST(1.5 AS NUMERIC(6, 3));
-- COL1: 2.730

VALUES CAST(1.23 AS NUMERIC(6, 2)) - CAST(1.5 AS NUMERIC(6, 3));
-- COL1: -0.270

VALUES CAST(1.23 AS NUMERIC(6, 2)) - CAST(-1.5 AS NUMERIC(6, 3));
-- COL1: 2.730

VALUES CAST(1.23 AS NUMERIC(6, 2)) * CAST(1.5 AS NUMERIC(6, 3));
-- COL1: 1.84500

VALUES CAST(CAST(1.23 AS NUMERIC(6, 2)) * CAST(1.5 AS NUMERIC(6, 3)) AS NUMERIC(6, 4));
-- COL1: 1.8450

VALUES CAST(1.24 AS NUMERIC(6, 2)) / CAST(1.5 AS NUMERIC(6, 3));
-- COL1: 0.82666

VALUES CAST(1.24 AS NUMERIC(6, 3)) / CAST(1.5 AS NUMERIC(6, 2));
-- COL1: 0.82666

VALUES CAST(CAST(1.24 AS NUMERIC(6, 2)) / CAST(1.5 AS NUMERIC(6, 3)) AS NUMERIC(6, 4));
-- COL1: 0.8266

VALUES CAST(1.23 AS NUMERIC(3,2)) / 5;
-- COL1: 0.24

-- # NUMERIC on its own has a scale of 0, so the division has a scale of 2 (2 +
-- # 0) and is 0.71 before the cast, not 0.7142 (docs/numbers.rst).
VALUES CAST(CAST(5 AS NUMERIC(3,2)) / CAST(7 AS NUMERIC) AS NUMERIC(5,4));
-- COL1: 0.7100

-- # The sum has a scale of 3 and the product a scale of 5.
VALUES CAST(10.24 AS NUMERIC(4,2)) + CAST(12.123 AS NUMERIC(8,3));
-- COL1: 22.363

VALUES CAST(10.24 AS NUMERIC(4,2)) * CAST(12.123 AS NUMERIC(8,3));
-- COL1: 124.13952

-- # 1.23 / 5 is truncated to 0.24 before it's multiplied, so the result is
-- # 1.20, not 1.23 (explained in docs/numbers.rst).
VALUES CAST(1.23 AS NUMERIC(3,2)) / CAST(5 AS NUMERIC) * CAST(5 AS NUMERIC);
-- COL1: 1.20

-- # Dividing a NUMERIC(3, 2) by a NUMERIC(5, 4) has a scale of 6 (2 + 4).
VALUES CAST(5 AS NUMERIC(3,2)) / CAST(7 AS NUMERIC(5,4));
-- COL1: 0.714285

-- # The same test again (a copy of the one above).
VALUES CAST(1.23 AS NUMERIC(3,2)) / CAST(5 AS NUMERIC) * CAST(5 AS NUMERIC);
-- COL1: 1.20

-- # 1 / 3 with two scale-1 operands keeps two places, and casting to a larger
-- # scale doesn't bring the dropped digits back.
VALUES CAST(1 AS NUMERIC(2,1)) / CAST(3 AS NUMERIC(2,1));
-- COL1: 0.33

VALUES CAST(CAST(1 AS NUMERIC(2,1)) / CAST(3 AS NUMERIC(2,1)) AS NUMERIC(10, 8));
-- COL1: 0.33000000

-- # A string is cast as the numeric literal it holds, which can be an
-- # approximate literal with an exponent (6.13, General Rules, 8.b.ii).
/* types */
VALUES CAST('1.5e-3' AS NUMERIC(10, 4));
-- COL1: 0.0015 (NUMERIC(10, 4))

/* types */
VALUES CAST('15e2' AS NUMERIC(10, 4));
-- COL1: 1500.0000 (NUMERIC(10, 4))
