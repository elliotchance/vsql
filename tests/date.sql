VALUES DATE '2022-06-30 21:47:32';
-- error 42601: syntax error: DATE '2022-06-30 21:47:32' is not valid

VALUES DATE '2022-06-30 21:47:32+05:12';
-- error 42601: syntax error: DATE '2022-06-30 21:47:32+05:12' is not valid

VALUES DATE '21:47:32';
-- error 42601: syntax error: DATE '21:47:32' is not valid

VALUES DATE '21:47:32+05:12';
-- error 42601: syntax error: DATE '21:47:32+05:12' is not valid

VALUES DATE '2022-06-30 21:47:32-11:30';
-- error 42601: syntax error: DATE '2022-06-30 21:47:32-11:30' is not valid

VALUES DATE '2022-06-30 00:00:00';
-- error 42601: syntax error: DATE '2022-06-30 00:00:00' is not valid

VALUES DATE '2022-06-30 21:47:32.123';
-- error 42601: syntax error: DATE '2022-06-30 21:47:32.123' is not valid

VALUES DATE '2022-06-30 21:47:32.456000+05:12';
-- error 42601: syntax error: DATE '2022-06-30 21:47:32.456000+05:12' is not valid

VALUES DATE '2022-06-30T21:47:32';
-- error 42601: syntax error: DATE '2022-06-30T21:47:32' is not valid

VALUES DATE 'a2022-06-30 21:47:32';
-- error 42601: syntax error: DATE 'a2022-06-30 21:47:32' is not valid

VALUES DATE '2022-06-30 21:47:32a';
-- error 42601: syntax error: DATE '2022-06-30 21:47:32a' is not valid

/* types */
VALUES DATE '2022-06-30';
-- COL1: 2022-06-30 (DATE)

-- # Dates must be valid in the Gregorian calendar.
VALUES DATE '2022-02-30';
-- error 42601: syntax error: DATE '2022-02-30' is not valid

VALUES DATE '2024-02-29';
-- COL1: 2024-02-29

VALUES DATE '2023-02-29';
-- error 42601: syntax error: DATE '2023-02-29' is not valid

VALUES DATE '2022-00-10';
-- error 42601: syntax error: DATE '2022-00-10' is not valid

VALUES DATE '2022-13-01';
-- error 42601: syntax error: DATE '2022-13-01' is not valid

VALUES DATE '2022-06-00';
-- error 42601: syntax error: DATE '2022-06-00' is not valid

VALUES DATE '0000-01-01';
-- error 42601: syntax error: DATE '0000-01-01' is not valid

VALUES DATE '0001-01-01';
-- COL1: 0001-01-01

VALUES DATE '9999-12-31';
-- COL1: 9999-12-31

VALUES DATE '22-6-3';
-- error 42601: syntax error: DATE '22-6-3' is not valid

VALUES DATE '21:47:32';
-- error 42601: syntax error: DATE '21:47:32' is not valid

VALUES DATE 'FOO BAR';
-- error 42601: syntax error: DATE 'FOO BAR' is not valid

VALUES DATE '2022-06-30 21:47:75';
-- error 42601: syntax error: DATE '2022-06-30 21:47:75' is not valid

VALUES DATE '10000-06-30T21:47:32';
-- error 42601: syntax error: DATE '10000-06-30T21:47:32' is not valid

VALUES DATE '-1-06-30T21:47:32';
-- error 42601: syntax error: DATE '-1-06-30T21:47:32' is not valid

VALUES DATE '2022-06-30 21:47:32+12:00';
-- error 42601: syntax error: DATE '2022-06-30 21:47:32+12:00' is not valid

VALUES DATE '2022-06-30 21:47:32-12:00';
-- error 42601: syntax error: DATE '2022-06-30 21:47:32-12:00' is not valid

CREATE TABLE foo (f1 DATE);
INSERT INTO foo (f1) VALUES (DATE '2022-06-30');
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- F1: 2022-06-30

CREATE TABLE foo (f1 DATE);
INSERT INTO foo (f1) VALUES (DATE '2022-06-30');
SELECT CAST(f1 AS DATE) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 2022-06-30

CREATE TABLE foo (f1 DATE);
INSERT INTO foo (f1) VALUES (DATE '2022-06-30');
SELECT CAST(f1 AS TIME WITHOUT TIME ZONE) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 42846: cannot coerce DATE to TIME(0) WITHOUT TIME ZONE

CREATE TABLE foo (f1 DATE);
INSERT INTO foo (f1) VALUES (DATE '2022-06-30');
SELECT CAST(f1 AS TIME WITH TIME ZONE) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 42846: cannot coerce DATE to TIME(0) WITH TIME ZONE

CREATE TABLE foo (f1 DATE);
INSERT INTO foo (f1) VALUES (DATE '2022-06-30');
SELECT CAST(f1 AS TIMESTAMP WITHOUT TIME ZONE) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 2022-06-30T00:00:00.000000

CREATE TABLE foo (f1 DATE);
INSERT INTO foo (f1) VALUES (DATE '2022-06-30');
SELECT CAST(f1 AS TIMESTAMP(3) WITHOUT TIME ZONE) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 2022-06-30T00:00:00.000

CREATE TABLE foo (f1 DATE);
INSERT INTO foo (f1) VALUES (DATE '2022-06-30');
SELECT CAST(f1 AS TIMESTAMP WITH TIME ZONE) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 2022-06-30T00:00:00.000000+0500

CREATE TABLE foo (f1 DATE);
INSERT INTO foo (f1) VALUES (DATE '2022-06-30');
SELECT CAST(f1 AS TIMESTAMP(4) WITH TIME ZONE) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 2022-06-30T00:00:00.0000+0500

CREATE TABLE foo (f1 DATE);
INSERT INTO foo (f1) VALUES (DATE '2022-06-30');
SELECT CAST(f1 AS TIMESTAMP(0) WITH TIME ZONE) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 2022-06-30T00:00:00+0500
