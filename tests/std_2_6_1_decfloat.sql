-- # The precision of a DECFLOAT is 16 or 34 digits (6.1, Syntax Rules, 23),
-- # and one without a precision has 34 (6.1, Syntax Rules, 22). Trailing zeros
-- # are kept.
/* types */
CREATE TABLE t (a DECFLOAT, b DECFLOAT(16), c DECFLOAT(16), d DECFLOAT(34));
INSERT INTO t VALUES (1.5, 1.50, -123, 0.000001);
INSERT INTO t (a) VALUES (NULL);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- A: 1.5 (DECFLOAT(34)) B: 1.50 (DECFLOAT(16)) C: -123 (DECFLOAT(16)) D: 0.000001 (DECFLOAT(34))
-- A: NULL (DECFLOAT(34)) B: NULL (DECFLOAT(16)) C: NULL (DECFLOAT(16)) D: NULL (DECFLOAT(34))

CREATE TABLE t (a DECFLOAT(7));
-- error 42601: syntax error: DECFLOAT precision must be 16 or 34

CREATE TABLE t (a DECFLOAT(35));
-- error 42601: syntax error: DECFLOAT precision must be 16 or 34

-- # A number with more digits than the precision is rounded (half to even),
-- # and a very large or small number is shown with an exponent.
CREATE TABLE t (a DECFLOAT(16));
INSERT INTO t VALUES (12345678901234567890);
INSERT INTO t VALUES (1.00000000000000050);
INSERT INTO t VALUES (1.00000000000000150);
INSERT INTO t VALUES (9999999999999999.9);
INSERT INTO t VALUES (0.0000001);
INSERT INTO t VALUES (1.5e300);
INSERT INTO t VALUES (0);
INSERT INTO t VALUES (CAST(1 AS SMALLINT));
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- A: 1.234567890123457E+19
-- A: 1.000000000000000
-- A: 1.000000000000002
-- A: 1.000000000000000E+16
-- A: 1E-7
-- A: 1.5E+300
-- A: 0
-- A: 1

-- # The exponent of a DECFLOAT(16) is from -383 to 384, and the exponent of a
-- # DECFLOAT(34) is from -6143 to 6144.
CREATE TABLE t (a DECFLOAT(16), b DECFLOAT);
INSERT INTO t (a) VALUES (1e308);
INSERT INTO t (a) VALUES (CAST('1E385' AS DECFLOAT));
INSERT INTO t (b) VALUES (CAST('1E6144' AS DECFLOAT));
INSERT INTO t (b) VALUES (CAST('-1E-6143' AS DECFLOAT));
SELECT * FROM t;
VALUES CAST('1E6145' AS DECFLOAT);
VALUES CAST('1E-6144' AS DECFLOAT);
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 22003: numeric value out of range
-- msg: INSERT 1
-- msg: INSERT 1
-- A: 1E+308 B: NULL
-- A: NULL B: 1E+6144
-- A: NULL B: -1E-6143
-- error 22003: numeric value out of range
-- error 22003: numeric value out of range

-- # A character string can be cast to a DECFLOAT, and keeps all of its
-- # digits, even with an exponent.
/* types */
VALUES CAST(' 1.2345678901234567890123E-5 ' AS DECFLOAT);
-- COL1: 0.000012345678901234567890123 (DECFLOAT(34))

VALUES CAST('abc' AS DECFLOAT);
-- error 22018: invalid character value for cast

-- # A DECFLOAT can only be stored from a number.
CREATE TABLE t (a DECFLOAT);
INSERT INTO t VALUES ('1.5');
-- msg: CREATE TABLE 1
-- error 42846: cannot coerce CHARACTER(3) to DECFLOAT(34)

-- # Values that are equal, such as 1.5 and 1.50, are the same PRIMARY KEY.
CREATE TABLE t (a DECFLOAT PRIMARY KEY);
INSERT INTO t VALUES (1.5), (-2), (0.05), (100), (-0.5), (0);
SELECT * FROM t;
INSERT INTO t VALUES (1.50);
-- msg: CREATE TABLE 1
-- msg: INSERT 6
-- A: -2
-- A: -0.5
-- A: 0
-- A: 0.05
-- A: 1.5
-- A: 100
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T

-- # A DECFLOAT can be cast to any other number, and a column that isn't
-- # needed is skipped.
CREATE TABLE t (a DECFLOAT, b INT);
INSERT INTO t VALUES (CAST('1.5E+2' AS DECFLOAT), 1);
SELECT b FROM t;
VALUES CAST(CAST('1.5E+2' AS DECFLOAT) AS INTEGER);
VALUES CAST(CAST('1.25' AS DECFLOAT) AS NUMERIC(4, 2));
VALUES CAST(CAST('0.005' AS DECFLOAT) AS NUMERIC(4, 3));
VALUES CAST(CAST('-2.5' AS DECFLOAT) AS DOUBLE PRECISION);
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- B: 1
-- COL1: 150
-- COL1: 1.25
-- COL1: 0.005
-- COL1: -2.5e0
