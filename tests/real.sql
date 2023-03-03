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
-- COL1: 123

CREATE TABLE foo (x REAL);
INSERT INTO foo (x) VALUES (123);
SELECT CAST(x AS DOUBLE PRECISION) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 123

VALUES CAST(500000000.3 AS REAL) * 2000000000.7;
-- COL1: 1e+18

VALUES CAST(1.23 AS REAL) + 53.7;
-- COL1: 54.93

VALUES 53.7 + CAST(1.23 AS REAL);
-- COL1: 54.93

VALUES CAST(500000000 AS REAL) + 2000000000.7;
-- COL1: 2.500000e+09

VALUES 500000000.7 + CAST(2000000000 AS REAL);
-- COL1: 2.500000e+09

VALUES CAST(1.23 AS REAL) - 53.7;
-- COL1: -52.470001

VALUES 53.7 - CAST(1.23 AS REAL);
-- COL1: 52.470001

VALUES CAST(-2000000000.1 AS REAL) - 500000000.7;
-- COL1: -2.500000e+09

VALUES -500000000.7 - CAST(2000000000.1 AS REAL);
-- COL1: -2.500000e+09

VALUES CAST(12.3 AS REAL) * 53.7;
-- COL1: 660.51001

VALUES -53.7 * CAST(12.3 AS REAL);
-- COL1: -660.51001

VALUES CAST(-300000.1 AS REAL) * 200000.7;
-- COL1: -0.6000023e+11

VALUES -300000.7 * CAST(200000.1 AS REAL);
-- COL1: -0.6000017e+11

VALUES CAST(1.23 AS REAL) / 53.7;
-- COL1: 0.022905

VALUES -123.7 / CAST(53.1 AS REAL);
-- COL1: -2.329567

VALUES CAST(-300000000.5 AS REAL) / 0.02;
-- COL1: -1.500000e+1

VALUES -90000.7 / CAST(3.2 AS REAL);
-- COL1: -28125.21875

VALUES CAST(-30000.5 AS REAL) / 0;
-- error 22012: division by zero

VALUES -90000.5 / CAST(0.1 AS REAL);
-- COL1: -900005

CREATE TABLE foo (x REAL);
INSERT INTO foo (x) VALUES (123456789123456789123456789);
SELECT CAST(x AS BIGINT) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 22003: numeric value out of range
