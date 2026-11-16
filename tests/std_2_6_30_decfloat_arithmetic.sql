-- # If either operand is a DECFLOAT, the result is a DECFLOAT (Syntax Rules,
-- # 1.a). Its precision is implementation-defined: the larger precision of the
-- # DECFLOAT operands, and any other number is cast to it.
/* types */
VALUES CAST(1.5 AS DECFLOAT) + 1;
VALUES CAST(1.5 AS DECFLOAT(16)) + CAST(1 AS DECFLOAT);
VALUES CAST(1.5 AS DECFLOAT(16)) - CAST(1 AS DECFLOAT(16));
VALUES 2 * CAST(1.5 AS DECFLOAT(16));
VALUES CAST(1.5 AS DECFLOAT(16)) + 1e0;
VALUES CAST(1.5 AS REAL) * CAST(2 AS DECFLOAT(16));
VALUES CAST(1.25 AS DECIMAL(3, 2)) - CAST(3 AS DECFLOAT);
VALUES CAST(9223372036854775807 AS BIGINT) + CAST(1 AS DECFLOAT);
-- COL1: 2.5 (DECFLOAT(34))
-- COL1: 2.5 (DECFLOAT(34))
-- COL1: 0.5 (DECFLOAT(16))
-- COL1: 3.0 (DECFLOAT(16))
-- COL1: 2.5 (DECFLOAT(16))
-- COL1: 3.0 (DECFLOAT(16))
-- COL1: -1.75 (DECFLOAT(34))
-- COL1: 9223372036854775808 (DECFLOAT(34))

-- # Like IEEE 754, an addition has the smaller exponent of the two, and a
-- # multiplication adds them, so trailing zeros are kept.
VALUES CAST(1.50 AS DECFLOAT) + 1;
VALUES CAST(1.50 AS DECFLOAT) * CAST(2.0 AS DECFLOAT);
VALUES CAST(1.50 AS DECFLOAT) - CAST(1.5 AS DECFLOAT);
VALUES CAST('1E+3' AS DECFLOAT) + 1;
VALUES CAST('1E+3' AS DECFLOAT) * 2;
-- COL1: 2.50
-- COL1: 3.000
-- COL1: 0.00
-- COL1: 1001
-- COL1: 2E+3

-- # A division has as many digits as it needs, up to the precision. An exact
-- # quotient has the difference of the exponents, if it can.
/* types */
VALUES CAST(1 AS DECFLOAT) / 3;
VALUES CAST(1 AS DECFLOAT(16)) / 3;
VALUES CAST(2 AS DECFLOAT(16)) / 3;
VALUES CAST(6 AS DECFLOAT) / 2;
VALUES CAST(1 AS DECFLOAT) / 4;
VALUES CAST(6.0 AS DECFLOAT) / 2;
VALUES CAST(0 AS DECFLOAT) / 7;
VALUES CAST(-1 AS DECFLOAT(16)) / 7;
VALUES CAST(1 AS DECFLOAT(16)) / -8;
-- COL1: 0.3333333333333333333333333333333333 (DECFLOAT(34))
-- COL1: 0.3333333333333333 (DECFLOAT(16))
-- COL1: 0.6666666666666667 (DECFLOAT(16))
-- COL1: 3 (DECFLOAT(34))
-- COL1: 0.25 (DECFLOAT(34))
-- COL1: 3.0 (DECFLOAT(34))
-- COL1: 0 (DECFLOAT(34))
-- COL1: -0.1428571428571429 (DECFLOAT(16))
-- COL1: -0.125 (DECFLOAT(16))

-- # Dividing by zero is an error (General Rules, 4).
VALUES CAST(1 AS DECFLOAT) / 0;
VALUES CAST(1 AS DECFLOAT) / CAST(0.00 AS DECFLOAT);
VALUES 1 / CAST(0 AS DECFLOAT);
-- error 22012: division by zero
-- error 22012: division by zero
-- error 22012: division by zero

-- # The result is rounded to the precision, half to even (General Rules, 7).
VALUES CAST(1234567890123456 AS DECFLOAT(16)) * 10 + 5;
VALUES CAST(1234567890123456 AS DECFLOAT(16)) * 10 + 15;
VALUES CAST(9999999999999999 AS DECFLOAT(16)) + 1;
VALUES CAST(1 AS DECFLOAT(16)) + CAST('1E-20' AS DECFLOAT(16));
VALUES CAST(1 AS DECFLOAT(16)) - CAST('1E-20' AS DECFLOAT(16));
-- COL1: 1.234567890123456E+16
-- COL1: 1.234567890123458E+16
-- COL1: 1.000000000000000E+16
-- COL1: 1.000000000000000
-- COL1: 1.000000000000000

-- # A result with an exponent out of range is an error (General Rules, 7).
VALUES CAST('9E384' AS DECFLOAT(16)) * 10;
VALUES CAST('1E-383' AS DECFLOAT(16)) / 10;
VALUES CAST('9E6144' AS DECFLOAT) + CAST('9E6144' AS DECFLOAT);
VALUES CAST('1E-383' AS DECFLOAT(16)) * CAST('1E-383' AS DECFLOAT(16));
-- error 22003: numeric value out of range
-- error 22003: numeric value out of range
-- error 22003: numeric value out of range
-- error 22003: numeric value out of range

-- # Unary minus reverses the sign, and unary plus doesn't change anything
-- # (General Rules, 3).
/* types */
VALUES -CAST(1.5 AS DECFLOAT(16));
VALUES +CAST(1.50 AS DECFLOAT);
VALUES -CAST(-2 AS DECFLOAT);
-- COL1: -1.5 (DECFLOAT(16))
-- COL1: 1.50 (DECFLOAT(34))
-- COL1: 2 (DECFLOAT(34))

-- # A NULL operand is NULL (General Rules, 1).
/* types */
VALUES CAST(NULL AS DECFLOAT) + 1;
VALUES 1.5 * CAST(NULL AS DECFLOAT(16));
VALUES -CAST(NULL AS DECFLOAT(16));
-- COL1: NULL (DECFLOAT(34))
-- COL1: NULL (DECFLOAT(16))
-- COL1: NULL (DECFLOAT(16))

-- # Columns work the same way.
CREATE TABLE t (a DECFLOAT(16), b DECFLOAT, c INTEGER);
INSERT INTO t VALUES (1.5, 2.25, 3);
SELECT a + b, a * c, b / c, -a FROM t;
UPDATE t SET a = a * 2, c = b * 4;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 3.75 COL2: 4.5 COL3: 0.75 COL4: -1.5
-- msg: UPDATE 1
-- A: 3.0 B: 2.25 C: 9
