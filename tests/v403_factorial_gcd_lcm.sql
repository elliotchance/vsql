-- # FACTORIAL, GCD and LCM are vsql extensions (V403-11 to V403-13), as in
-- # PostgreSQL.

/* setup */
CREATE TABLE t (a SMALLINT, b INT, c BIGINT);
INSERT INTO t (a, b, c) VALUES (12, 18, 30);
INSERT INTO t (a, b, c) VALUES (-4, 0, NULL);

-- # FACTORIAL of any integer is an exact NUMERIC with a scale of 0.
/* types */
VALUES ROW(FACTORIAL(0), FACTORIAL(1), FACTORIAL(5), FACTORIAL(CAST(10 AS INT)), FACTORIAL(CAST(20 AS BIGINT)));
-- COL1: 1 (NUMERIC) COL2: 1 (NUMERIC) COL3: 120 (NUMERIC) COL4: 3628800 (NUMERIC) COL5: 2432902008176640000 (NUMERIC)

-- # A large result stays exact.
VALUES FACTORIAL(30);
-- COL1: 265252859812191058636308480000000

-- # 449! has 998 digits, the largest that fits in a NUMERIC. 450! has 1001.
VALUES CHAR_LENGTH(CAST(FACTORIAL(449) AS VARCHAR(1000)));
-- COL1: 998

VALUES FACTORIAL(450);
-- error 22003: numeric value out of range

VALUES FACTORIAL(9223372036854775807);
-- error 22003: numeric value out of range

-- # A negative argument has no factorial.
VALUES FACTORIAL(-1);
-- error 22003: numeric value out of range

-- # The argument must be an integer.
VALUES FACTORIAL(5.0);
-- error 42883: function does not exist: FACTORIAL(NUMERIC(2, 1))

VALUES FACTORIAL(5e0);
-- error 42883: function does not exist: FACTORIAL(DOUBLE PRECISION)

/* types */
VALUES FACTORIAL(CAST(NULL AS INT));
-- COL1: NULL (NUMERIC)

-- # GCD is the greatest common divisor, and LCM is the least common multiple.
-- # Neither is ever negative.
VALUES ROW(GCD(12, 18), GCD(-12, 18), GCD(12, -18), GCD(-12, -18), GCD(7, 13));
-- COL1: 6 COL2: 6 COL3: 6 COL4: 6 COL5: 1

VALUES ROW(LCM(4, 6), LCM(-4, 6), LCM(4, -6), LCM(-4, -6), LCM(7, 13));
-- COL1: 12 COL2: 12 COL3: 12 COL4: 12 COL5: 91

-- # GCD with 0 is the absolute value of the other argument, and LCM with 0 is 0.
VALUES ROW(GCD(0, 0), GCD(-7, 0), GCD(0, 7), LCM(0, 0), LCM(-5, 0), LCM(0, 5));
-- COL1: 0 COL2: 7 COL3: 7 COL4: 0 COL5: 0 COL6: 0

-- # The result has the larger of the two integer types.
/* types */
VALUES ROW(GCD(CAST(4 AS SMALLINT), CAST(6 AS SMALLINT)), GCD(CAST(4 AS SMALLINT), CAST(6 AS INT)), GCD(CAST(4 AS BIGINT), CAST(6 AS SMALLINT)), GCD(CAST(4 AS INT), CAST(6 AS INT)), GCD(CAST(4 AS INT), CAST(6 AS BIGINT)));
-- COL1: 2 (SMALLINT) COL2: 2 (INTEGER) COL3: 2 (BIGINT) COL4: 2 (INTEGER) COL5: 2 (BIGINT)

/* types */
VALUES ROW(LCM(CAST(4 AS SMALLINT), CAST(6 AS SMALLINT)), LCM(CAST(4 AS INT), CAST(6 AS SMALLINT)), LCM(CAST(4 AS SMALLINT), CAST(6 AS BIGINT)), LCM(CAST(4 AS BIGINT), CAST(6 AS BIGINT)));
-- COL1: 12 (SMALLINT) COL2: 12 (INTEGER) COL3: 12 (BIGINT) COL4: 12 (BIGINT)

-- # A result that doesn't fit in the type is out of range, even for GCD of the
-- # smallest value of a type.
VALUES GCD(CAST(-32768 AS SMALLINT), CAST(0 AS SMALLINT));
-- error 22003: numeric value out of range

/* types */
VALUES GCD(CAST(-32768 AS SMALLINT), CAST(0 AS INT));
-- COL1: 32768 (INTEGER)

VALUES GCD(CAST(-9223372036854775808 AS BIGINT), 0);
-- error 22003: numeric value out of range

VALUES GCD(CAST(-9223372036854775808 AS BIGINT), 6);
-- COL1: 2

VALUES LCM(CAST(200 AS SMALLINT), CAST(201 AS SMALLINT));
-- error 22003: numeric value out of range

VALUES LCM(CAST(65536 AS INT), CAST(65537 AS INT));
-- error 22003: numeric value out of range

VALUES LCM(CAST(65536 AS INT), CAST(65537 AS BIGINT));
-- COL1: 4295032832

VALUES LCM(9223372036854775807, 9223372036854775806);
-- error 22003: numeric value out of range

VALUES LCM(CAST(-9223372036854775808 AS BIGINT), 1);
-- error 22003: numeric value out of range

-- # The arguments must be integers.
VALUES GCD(1.5, 2);
-- error 42883: function does not exist: GCD(NUMERIC(2, 1), SMALLINT)

VALUES LCM(4, 6e0);
-- error 42883: function does not exist: LCM(SMALLINT, DOUBLE PRECISION)

-- # NULL in, NULL out.
/* types */
VALUES ROW(GCD(CAST(NULL AS INT), 4), GCD(4, CAST(NULL AS BIGINT)), LCM(CAST(NULL AS SMALLINT), CAST(NULL AS SMALLINT)));
-- COL1: NULL (INTEGER) COL2: NULL (BIGINT) COL3: NULL (SMALLINT)

-- # With columns.
/* types */
SELECT GCD(a, b), LCM(a, b), GCD(b, c), LCM(a, c), FACTORIAL(a + 10) FROM t;
-- COL1: 6 (INTEGER) COL2: 36 (INTEGER) COL3: 6 (BIGINT) COL4: 60 (BIGINT) COL5: 1124000727777607680000 (NUMERIC)
-- COL1: 4 (INTEGER) COL2: 0 (INTEGER) COL3: NULL (BIGINT) COL4: NULL (BIGINT) COL5: 720 (NUMERIC)

-- # None of the names are reserved.
CREATE TABLE factorial (factorial INT, gcd INT, lcm INT);
INSERT INTO factorial (factorial, gcd, lcm) VALUES (1, 2, 3);
SELECT factorial, gcd, lcm FROM factorial;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- FACTORIAL: 1 GCD: 2 LCM: 3

-- # The flagger.
/* flags */
SELECT FACTORIAL(b), GCD(a, b), LCM(b, c) FROM t;
-- flags: V403-11, V403-12, V403-13
-- COL1: 6402373705728000 COL2: 6 COL3: 90
-- COL1: 1 COL2: 4 COL3: NULL

-- # A dynamic parameter has the type of the other argument, like MOD.
/* types */
/* params 12 18 */
SELECT GCD(?, b), LCM(c, ?) FROM t WHERE a = 12;
-- sql: SELECT GCD(12.0e0, b), LCM(c, 18.0e0) FROM t WHERE a = 12
-- COL1: 6 (INTEGER) COL2: 90 (BIGINT)

/* types */
/* params 4 */
VALUES LCM(?, 10);
-- sql: VALUES LCM(4.0e0, 10)
-- COL1: 20 (SMALLINT)

-- # With no other argument, the type can't be determined, like MOD(?, ?).
/* params 12 18 */
VALUES GCD(?, ?);
-- sql: VALUES GCD(12.0e0, 18.0e0)
-- error 42601: syntax error: the data type of ?1 cannot be determined

/* params 12 18 */
VALUES GCD(CAST(? AS INT), CAST(? AS INT));
-- sql: VALUES GCD(CAST(12.0e0 AS INT), CAST(18.0e0 AS INT))
-- COL1: 6
