-- # A cast between NUMERIC and DECIMAL without a size (such as for the argument
-- # of a function) changes the type, but keeps the precision and scale.
/* types */
VALUES MOD(CAST(7.5 AS DECIMAL(2,1)), CAST(2 AS NUMERIC(1)));
-- COL1: 1.5 (NUMERIC(2, 1))

/* types */
VALUES FLOOR(CAST(1.5 AS DECIMAL(2,1)));
-- COL1: 1 (NUMERIC(2))

-- # A cast without a size has a scale of 0, and the declared type is the target
-- # type.
/* types */
VALUES CAST(CAST(1.25 AS DECIMAL(3,2)) AS NUMERIC);
-- COL1: 1 (NUMERIC)

/* types */
VALUES CAST(CAST(1.25 AS NUMERIC(3,2)) AS DECIMAL);
-- COL1: 1 (DECIMAL)

-- # The digits that don't fit in the scale are truncated, however many there
-- # are.
/* types */
VALUES CAST(2.250 AS DECIMAL);
VALUES CAST(-2.250 AS NUMERIC);
VALUES CAST(9.99999 AS NUMERIC(3, 1));
-- COL1: 2 (DECIMAL)
-- COL1: -2 (NUMERIC)
-- COL1: 9.9 (NUMERIC(3, 1))

CREATE TABLE t (i DECIMAL, j DECIMAL(5, 2), k NUMERIC);
INSERT INTO t (i, j, k) VALUES (2.250, 2.250, 2.250);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- I: 2 J: 2.25 K: 2

-- # An approximate number is converted from the shortest decimal that is the
-- # same number, however small or large it is.
VALUES CAST(0.0001e0 AS DECIMAL(10, 8)), CAST(0.00001e0 AS DECIMAL(10, 8)), CAST(-1.5e-5 AS NUMERIC(10, 8));
-- COL1: 0.00010000
-- COL1: 0.00001000
-- COL1: -0.00001500

VALUES CAST(1.5e-5 AS NUMERIC), CAST('1.5e-5' AS NUMERIC(10, 8));
-- COL1: 0
-- COL1: 0.00001500

VALUES CAST(1.5e22 AS NUMERIC(30, 2)), CAST(123456789012345678901234.0e0 AS NUMERIC(30, 2));
-- COL1: 15000000000000000000000.00
-- COL1: 123456789012345690000000.00

-- # A string is cast as the literal it contains, so an approximate one is a
-- # DOUBLE PRECISION first. One that's too large for a DOUBLE PRECISION is out
-- # of range, even if the NUMERIC or DECIMAL could hold it, and one that's too
-- # small is zero.
VALUES CAST('1e308' AS NUMERIC(309)) = CAST(1e308 AS NUMERIC(309));
-- COL1: TRUE

VALUES CAST('123456789012345678901234.0e0' AS NUMERIC(30, 2));
-- COL1: 123456789012345690000000.00

VALUES CAST('1e309' AS NUMERIC(400));
-- error 22003: numeric value out of range

VALUES CAST('-1e400' AS DECIMAL(500));
-- error 22003: numeric value out of range

VALUES CAST('1e-400' AS NUMERIC(10, 2));
-- COL1: 0.00

VALUES CAST('-1e-400' AS DECIMAL(10, 2));
-- COL1: 0.00

-- # Operators keep the precision and scale of both sides.
/* types */
VALUES CAST(1.25 AS DECIMAL(3,2)) + CAST(1.5 AS NUMERIC(2,1));
-- COL1: 2.75 (DECIMAL(4, 2))

-- # A NUMERIC or DECIMAL without a precision has no limit on the number of
-- # digits.
CREATE TABLE foo (n NUMERIC, d DECIMAL);
INSERT INTO foo (n, d) VALUES (123456789012345678901234567890123456789012345.6, -98765432109876543210987654321098765432109876.5);
SELECT n, d, n * 1000 FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- N: 123456789012345678901234567890123456789012345 D: -98765432109876543210987654321098765432109876 COL3: 123456789012345678901234567890123456789012345000

/* types */
VALUES CAST(123456789012345678901234567890123456789012345 AS NUMERIC) + 1;
-- COL1: 123456789012345678901234567890123456789012346 (NUMERIC)
