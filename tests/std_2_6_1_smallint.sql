-- # vsql gives SMALLINT a binary precision of 16 (Syntax Rules, 28), so it
-- # holds -32768 to 32767. A value outside that range can't be stored (9.2,
-- # General Rules, 3.b.xv.3).
CREATE TABLE foo (x SMALLINT);
INSERT INTO foo (x) VALUES (-32769);
INSERT INTO foo (x) VALUES (-32768);
INSERT INTO foo (x) VALUES (32767);
INSERT INTO foo (x) VALUES (32768);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- error 22003: numeric value out of range
-- msg: INSERT 1
-- msg: INSERT 1
-- error 22003: numeric value out of range
-- X: -32768
-- X: 32767

-- # A SMALLINT can be cast to any wider numeric type without changing its
-- # value.
CREATE TABLE foo (x SMALLINT);
INSERT INTO foo (x) VALUES (123);
SELECT CAST(x AS SMALLINT) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 123

CREATE TABLE foo (x SMALLINT);
INSERT INTO foo (x) VALUES (123);
SELECT CAST(x AS INTEGER) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 123

CREATE TABLE foo (x SMALLINT);
INSERT INTO foo (x) VALUES (123);
SELECT CAST(x AS BIGINT) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 123

CREATE TABLE foo (x SMALLINT);
INSERT INTO foo (x) VALUES (123);
SELECT CAST(x AS REAL) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 123e0

CREATE TABLE foo (x SMALLINT);
INSERT INTO foo (x) VALUES (123);
SELECT CAST(x AS DOUBLE PRECISION) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 123e0

-- # Arithmetic on two SMALLINTs makes a SMALLINT (6.29, Syntax Rules, 1.c), so
-- # a result outside the SMALLINT range is an error (6.29, General Rules, 5.a).
/* types */
VALUES CAST(123 AS SMALLINT) + CAST(53 AS SMALLINT);
-- COL1: 176 (SMALLINT)

/* types */
VALUES CAST(53 AS SMALLINT) + CAST(123 AS SMALLINT);
-- COL1: 176 (SMALLINT)

VALUES CAST(30000 AS SMALLINT) + CAST(20000 AS SMALLINT);
-- error 22003: numeric value out of range

VALUES CAST(30000 AS SMALLINT) + CAST(20000 AS SMALLINT);
-- error 22003: numeric value out of range

/* types */
VALUES CAST(123 AS SMALLINT) - CAST(53 AS SMALLINT);
-- COL1: 70 (SMALLINT)

/* types */
VALUES CAST(53 AS SMALLINT) - CAST(123 AS SMALLINT);
-- COL1: -70 (SMALLINT)

VALUES CAST(-30000 AS SMALLINT) - CAST(20000 AS SMALLINT);
-- error 22003: numeric value out of range

VALUES CAST(-30000 AS SMALLINT) - CAST(20000 AS SMALLINT);
-- error 22003: numeric value out of range

/* types */
VALUES CAST(123 AS SMALLINT) * CAST(53 AS SMALLINT);
-- COL1: 6519 (SMALLINT)

/* types */
VALUES CAST(-53 AS SMALLINT) * CAST(123 AS SMALLINT);
-- COL1: -6519 (SMALLINT)

VALUES CAST(-30000 AS SMALLINT) * CAST(20000 AS SMALLINT);
-- error 22003: numeric value out of range

VALUES CAST(-30000 AS SMALLINT) * CAST(20000 AS SMALLINT);
-- error 22003: numeric value out of range

-- # Division of SMALLINTs truncates toward zero (6.29, General Rules, 5.b).
-- # CAST(0.1 AS SMALLINT) truncates to 0 (6.13, General Rules, 8.a.i), so it's
-- # also a division by zero.
/* types */
VALUES CAST(123 AS SMALLINT) / CAST(53 AS SMALLINT);
-- COL1: 2 (SMALLINT)

/* types */
VALUES CAST(-123 AS SMALLINT) / CAST(53 AS SMALLINT);
-- COL1: -2 (SMALLINT)

VALUES CAST(-30000 AS SMALLINT) / CAST(0 AS SMALLINT);
-- error 22012: division by zero

VALUES CAST(-30000 AS SMALLINT) / CAST(0.1 AS SMALLINT);
-- error 22012: division by zero

-- # -32768 has no positive SMALLINT, so negating it or dividing it by -1 is out
-- # of range (6.29, General Rules, 5.a and 5.b).
VALUES -CAST(-32768 AS SMALLINT);
-- error 22003: numeric value out of range

VALUES CAST(-32768 AS SMALLINT) / CAST(-1 AS SMALLINT);
-- error 22003: numeric value out of range
