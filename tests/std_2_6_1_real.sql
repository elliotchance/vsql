-- # Casting to an integer type works while the value fits (6.13, General Rules,
-- # 8.a.i), otherwise it's out of range (6.13, General Rules, 8.a.ii). Casting
-- # to REAL or DOUBLE PRECISION keeps a small value.
CREATE TABLE foo (x REAL);
INSERT INTO foo (x) VALUES (123);
SELECT CAST(x AS SMALLINT) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 123

CREATE TABLE foo (x REAL);
INSERT INTO foo (x) VALUES (123456);
SELECT CAST(x AS SMALLINT) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 22003: numeric value out of range

CREATE TABLE foo (x REAL);
INSERT INTO foo (x) VALUES (123);
SELECT CAST(x AS INTEGER) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 123

CREATE TABLE foo (x REAL);
INSERT INTO foo (x) VALUES (12345678910);
SELECT CAST(x AS INTEGER) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 22003: numeric value out of range

CREATE TABLE foo (x REAL);
INSERT INTO foo (x) VALUES (123);
SELECT CAST(x AS BIGINT) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 123

CREATE TABLE foo (x REAL);
INSERT INTO foo (x) VALUES (123);
SELECT CAST(x AS REAL) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 123e0

CREATE TABLE foo (x REAL);
INSERT INTO foo (x) VALUES (123);
SELECT CAST(x AS DOUBLE PRECISION) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 123e0

-- # Arithmetic between REAL values is a REAL (6.29, Syntax Rules, 1.b), which
-- # is IEEE 754 single precision (Syntax Rules, 30). With only about 7
-- # significant digits, 52.47 shows as 52.470001e0 and the fractions of the
-- # large values are lost.
/* types */
VALUES CAST(500000000.3 AS REAL) * CAST(2000000000.7 AS REAL);
-- COL1: 1e+18 (REAL)

/* types */
VALUES CAST(1.23 AS REAL) + CAST(53.7 AS REAL);
-- COL1: 54.93e0 (REAL)

/* types */
VALUES CAST(53.7 AS REAL) + CAST(1.23 AS REAL);
-- COL1: 54.93e0 (REAL)

/* types */
VALUES CAST(500000000 AS REAL) + CAST(2000000000.7 AS REAL);
-- COL1: 2.5e+09 (REAL)

/* types */
VALUES CAST(500000000.7 AS REAL) + CAST(2000000000 AS REAL);
-- COL1: 2.5e+09 (REAL)

/* types */
VALUES CAST(1.23 AS REAL) - CAST(53.7 AS REAL);
-- COL1: -52.470001e0 (REAL)

/* types */
VALUES CAST(53.7 AS REAL) - CAST(1.23 AS REAL);
-- COL1: 52.470001e0 (REAL)

/* types */
VALUES CAST(-2000000000.1 AS REAL) - CAST(500000000.7 AS REAL);
-- COL1: -2.5e+09 (REAL)

/* types */
VALUES CAST(-500000000.7 AS REAL) - CAST(2000000000.1 AS REAL);
-- COL1: -2.5e+09 (REAL)

/* types */
VALUES CAST(12.3 AS REAL) * CAST(53.7 AS REAL);
-- COL1: 660.51001e0 (REAL)

/* types */
VALUES CAST(-53.7 AS REAL) * CAST(12.3 AS REAL);
-- COL1: -660.51001e0 (REAL)

/* types */
VALUES CAST(-300000.1 AS REAL) * CAST(200000.7 AS REAL);
-- COL1: -6.00002e+10 (REAL)

/* types */
VALUES CAST(-300000.7 AS REAL) * CAST(200000.1 AS REAL);
-- COL1: -6.00002e+10 (REAL)

/* types */
VALUES CAST(1.23 AS REAL) / CAST(53.7 AS REAL);
-- COL1: 0.022905e0 (REAL)

/* types */
VALUES CAST(-123.7 AS REAL) / CAST(53.1 AS REAL);
-- COL1: -2.329567e0 (REAL)

/* types */
VALUES CAST(-300000000.5 AS REAL) / CAST(0.02 AS REAL);
-- COL1: -1.5e+10 (REAL)

/* types */
VALUES CAST(-90000.7 AS REAL) / CAST(3.2 AS REAL);
-- COL1: -28125.21875e0 (REAL)

-- # Dividing by zero is an error for approximate numbers too (6.29, General
-- # Rules, 4).
/* types */
VALUES CAST(-30000.5 AS REAL) / CAST(0 AS REAL);
-- error 22012: division by zero

/* types */
VALUES CAST(-90000.5 AS REAL) / CAST(0.1 AS REAL);
-- COL1: -900005e0 (REAL)

-- # A NUMERIC literal too large for BIGINT is rounded when stored in a REAL
-- # (9.2, General Rules, 3.b.xv.2), but then can't be cast to BIGINT (6.13,
-- # General Rules, 8.a.ii).
CREATE TABLE foo (x REAL);
INSERT INTO foo (x) VALUES (123456789123456789123456789);
SELECT CAST(x AS BIGINT) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 22003: numeric value out of range

-- # Negating a REAL keeps the type REAL (6.29, Syntax Rules, 2).
/* types */
VALUES -CAST(1.5 AS REAL);
-- COL1: -1.5e0 (REAL)
