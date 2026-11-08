-- # A negative number is cast with a leading minus sign. A CHAR is padded with
-- # spaces, and both CHAR and VARCHAR raise an error (22001) when it's too long.

/* types */
VALUES CAST(-12 AS CHARACTER(5));
-- COL1: -12   (CHARACTER(5))

/* types */
VALUES CAST(-1.25 AS CHARACTER(5));
-- COL1: -1.25 (CHARACTER(5))

VALUES CAST(-1.25 AS CHARACTER(4));
-- error 22001: string data right truncation for CHARACTER(4)

/* types */
VALUES CAST(-12 AS VARCHAR(5));
-- COL1: -12 (CHARACTER VARYING(5))

VALUES CAST(-12 AS VARCHAR(2));
-- error 22001: string data right truncation for CHARACTER VARYING(2)

/* types */
VALUES CAST(1.5e0 AS CHARACTER(10));
-- COL1: 1.5E0      (CHARACTER(10))

/* types */
VALUES CAST(-1.5e0 AS CHARACTER(10));
-- COL1: -1.5E0     (CHARACTER(10))

/* types */
VALUES CAST(-1.5e0 AS CHARACTER(6));
-- COL1: -1.5E0 (CHARACTER(6))

VALUES CAST(-1.5e0 AS CHARACTER(2));
-- error 22001: string data right truncation for CHARACTER(2)

/* types */
VALUES CAST(1.5e0 AS VARCHAR(10));
-- COL1: 1.5E0 (CHARACTER VARYING(10))

/* types */
VALUES CAST(-1.5e0 AS VARCHAR(10));
-- COL1: -1.5E0 (CHARACTER VARYING(10))

VALUES CAST(-1.5e0 AS VARCHAR(2));
-- error 22001: string data right truncation for CHARACTER VARYING(2)

-- # An approximate number is the shortest literal with a single non-zero digit,
-- # a period and an unsigned integer in its mantissa.
VALUES CAST(-123.0e0 AS VARCHAR(10));
-- COL1: -1.23E2

VALUES CAST(0.000123e0 AS VARCHAR(30));
-- COL1: 1.23E-4

VALUES CAST(1234567.0e0 AS VARCHAR(30));
-- COL1: 1.234567E6

VALUES CAST(1e0 AS VARCHAR(10));
-- COL1: 1.0E0

VALUES CAST(100.0e0 AS VARCHAR(10));
-- COL1: 1.0E2

VALUES CAST(1e100 AS VARCHAR(10));
-- COL1: 1.0E100

VALUES CAST(-2.5e-100 AS VARCHAR(10));
-- COL1: -2.5E-100

VALUES CAST(1.7976931348623157e308 AS VARCHAR(30));
-- COL1: 1.7976931348623157E308

VALUES CAST(0.1e0 + 0.2e0 AS VARCHAR(30));
-- COL1: 3.0000000000000004E-1

-- # Zero has no sign, even a negative zero.
VALUES CAST(0e0 AS VARCHAR(10));
-- COL1: 0E0

VALUES CAST(-0e0 AS VARCHAR(10));
-- COL1: 0E0

/* types */
VALUES CAST(0e0 AS CHARACTER(5));
-- COL1: 0E0   (CHARACTER(5))

-- # A REAL has fewer digits than the same value as a DOUBLE PRECISION.
VALUES CAST(CAST(0.1e0 AS REAL) AS VARCHAR(30));
-- COL1: 1.0E-1

VALUES CAST(CAST(-1234567.0e0 AS REAL) AS CHARACTER(11));
-- COL1: -1.234567E6

VALUES CAST(CAST(0e0 AS REAL) AS VARCHAR(10));
-- COL1: 0E0

VALUES CAST(CAST(-0e0 AS REAL) AS VARCHAR(10));
-- COL1: 0E0

-- # The length of the result decides if it fits, exactly at the limit.
VALUES CAST(-123.0e0 AS VARCHAR(7));
-- COL1: -1.23E2

VALUES CAST(-123.0e0 AS VARCHAR(6));
-- error 22001: string data right truncation for CHARACTER VARYING(6)

VALUES CAST(-123.0e0 AS CHARACTER(7));
-- COL1: -1.23E2

VALUES CAST(-123.0e0 AS CHARACTER(6));
-- error 22001: string data right truncation for CHARACTER(6)

VALUES CAST(CAST(1.5e0 AS REAL) AS VARCHAR(4));
-- error 22001: string data right truncation for CHARACTER VARYING(4)

VALUES CAST(CAST(1.5e0 AS REAL) AS CHARACTER(4));
-- error 22001: string data right truncation for CHARACTER(4)

-- # The result is a literal that converts back to the same value.
VALUES CAST(CAST(-1234567.0e0 AS VARCHAR(30)) AS DOUBLE PRECISION);
-- COL1: -1.234567e+06

VALUES CAST(CAST(0.000123e0 AS VARCHAR(30)) AS DOUBLE PRECISION);
-- COL1: 0.000123e0

-- # Only a cast to a string changes the form, not how the number is shown.
VALUES 123.0e0;
-- COL1: 123e0

/* types */
VALUES CAST(CAST(NULL AS DOUBLE PRECISION) AS VARCHAR(10));
-- COL1: NULL (CHARACTER VARYING(10))

/* types */
VALUES CAST(CAST(NULL AS REAL) AS CHARACTER(10));
-- COL1: NULL (CHARACTER(10))
