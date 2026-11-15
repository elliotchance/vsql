-- # A NUMERIC or DECIMAL whose scale equals its precision holds any value
-- # whose absolute value is less than 1. Extra fraction digits are truncated
-- # and anything with an integer part is out of range.
CREATE TABLE t (d DECIMAL(2,2), n NUMERIC(3,3));
INSERT INTO t (d) VALUES (0.5);
INSERT INTO t (d) VALUES (0);
INSERT INTO t (n) VALUES (0.123);
INSERT INTO t (d) VALUES (0.999);
INSERT INTO t (n) VALUES (-0.25);
INSERT INTO t (d) VALUES (1.0);
INSERT INTO t (n) VALUES (-1.5);
UPDATE t SET n = -0.5 WHERE d = 0;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- error 22003: numeric value out of range
-- error 22003: numeric value out of range
-- msg: UPDATE 1
-- D: 0.50 N: NULL
-- D: 0.00 N: -0.500
-- D: NULL N: 0.123
-- D: 0.99 N: NULL
-- D: NULL N: -0.250

-- # The same applies to CAST and to a DEFAULT.
VALUES CAST(0.5 AS DECIMAL(2,2));
VALUES CAST(-0.5 AS NUMERIC(2,2));
VALUES CAST(1 AS NUMERIC(2,2));
CREATE TABLE t (d DECIMAL(2,2) DEFAULT 0.5);
INSERT INTO t (d) VALUES (DEFAULT);
SELECT * FROM t;
-- COL1: 0.50
-- COL1: -0.50
-- error 22003: numeric value out of range
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- D: 0.50

-- # An exact numeric stored in a SMALLINT, INTEGER or BIGINT has its fraction
-- # truncated before the range is checked, so a value just past the end of
-- # the range still fits.
CREATE TABLE t (s SMALLINT, i INTEGER, b BIGINT);
INSERT INTO t (s) VALUES (32767.5);
INSERT INTO t (s) VALUES (-32768.9);
INSERT INTO t (s) VALUES (32768.0);
INSERT INTO t (i) VALUES (2147483647.9);
INSERT INTO t (i) VALUES (-2147483648.9);
INSERT INTO t (i) VALUES (-2147483649.0);
INSERT INTO t (b) VALUES (9223372036854775807.9);
INSERT INTO t (b) VALUES (-9223372036854775808.9);
UPDATE t SET s = -0.9 WHERE b IS NOT NULL;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- error 22003: numeric value out of range
-- msg: INSERT 1
-- msg: INSERT 1
-- error 22003: numeric value out of range
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: UPDATE 2
-- S: 32767 I: NULL B: NULL
-- S: -32768 I: NULL B: NULL
-- S: NULL I: 2147483647 B: NULL
-- S: NULL I: -2147483648 B: NULL
-- S: 0 I: NULL B: 9223372036854775807
-- S: 0 I: NULL B: -9223372036854775808

-- # The same applies to CAST.
VALUES CAST(32767.9 AS SMALLINT);
VALUES CAST(-32768.9 AS SMALLINT);
VALUES CAST(32768.0 AS SMALLINT);
VALUES CAST(2147483647.9 AS INTEGER);
VALUES CAST(2147483648.0 AS INTEGER);
VALUES CAST(-9223372036854775808.9 AS BIGINT);
VALUES CAST(9223372036854775808.0 AS BIGINT);
-- COL1: 32767
-- COL1: -32768
-- error 22003: numeric value out of range
-- COL1: 2147483647
-- error 22003: numeric value out of range
-- COL1: -9223372036854775808
-- error 22003: numeric value out of range
