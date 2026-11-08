-- # A DATE literal is only a date, as YYYY-MM-DD. A time, a time zone, a
-- # fraction, a 'T' or any stray characters make it invalid.
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

-- # A valid DATE literal has the type DATE (5.3, Syntax Rules, 25).
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

-- # Years run from 0001 to 9999 (5.3, Syntax Rules, 32). The year must have
-- # four digits and the month and day two (5.3, Syntax Rules, 31), and the rest
-- # of these aren't dates at all.
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

-- # A DATE column stores and returns the date, and casting a DATE to DATE gives
-- # the same value (6.13, General Rules, 14.b).
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

-- # A DATE has no time, so it can't be cast to a TIME (6.13, Syntax Rules, 7).
-- # Casting it to a TIMESTAMP gives midnight at the target's precision (6.13,
-- # General Rules, 18.b), and WITH TIME ZONE adds the session's time zone,
-- # +05:00 in the tests (6.13, General Rules, 19.e).
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

-- # A string is cast to a DATE after trimming spaces (6.13, General Rules,
-- # 14.a.ii). Anything that isn't a valid date, including a timestamp, is an
-- # invalid datetime format (6.13, General Rules, 14.a.ii.2).
/* types */
VALUES CAST('2022-06-30' AS DATE);
-- COL1: 2022-06-30 (DATE)

VALUES CAST('  2022-06-30   ' AS DATE);
-- COL1: 2022-06-30

VALUES CAST('2022-02-30' AS DATE);
-- error 22007: invalid datetime format

VALUES CAST('2022-06-30 12:34:56' AS DATE);
-- error 22007: invalid datetime format

VALUES CAST('hello' AS DATE);
-- error 22007: invalid datetime format

-- # A date literal is also accepted (6.13, General Rules, 14.a.ii.1), but the
-- # keyword must be DATE. Any white space can separate DATE and the quoted
-- # date, but a comment can't, since the string isn't SQL. A DATE cast to a
-- # string is a DATE literal (6.13, General Rules, 12.e.i.2), so it casts back.
-- # An unclosed or doubled quote is invalid.
VALUES CAST('DATE ''2022-06-30''' AS DATE);
-- COL1: 2022-06-30

VALUES CAST(' date''2022-06-30''  ' AS DATE);
-- COL1: 2022-06-30

VALUES CAST(U&'DATE\000A\0009\3000''2022-06-30''' AS DATE);
-- COL1: 2022-06-30

VALUES CAST('DATE /* comment */ ''2022-06-30''' AS DATE);
-- error 22007: invalid datetime format

VALUES CAST(CAST(DATE '2022-06-30' AS VARCHAR(30)) AS DATE);
-- COL1: 2022-06-30

VALUES CAST('TIMESTAMP ''2022-06-30''' AS DATE);
-- error 22007: invalid datetime format

VALUES CAST('DATE ''2022-06-30' AS DATE);
-- error 22007: invalid datetime format

VALUES CAST('DATE ''2022-''''06-30''' AS DATE);
-- error 22007: invalid datetime format

VALUES CAST('DATE' AS DATE);
-- error 22007: invalid datetime format

-- # A NULL string casts to a NULL DATE (6.13, General Rules, 2.c).
CREATE TABLE foo (f1 VARCHAR(20));
INSERT INTO foo (f1) VALUES ('2022-06-30');
INSERT INTO foo (f1) VALUES (NULL);
SELECT CAST(f1 AS DATE) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- COL1: 2022-06-30
-- COL1: NULL

-- # A character string is not assignable to a DATE column without a CAST.
CREATE TABLE foo (f1 DATE);
INSERT INTO foo (f1) VALUES ('2022-06-30');
-- msg: CREATE TABLE 1
-- error 42846: cannot coerce CHARACTER(10) to DATE
