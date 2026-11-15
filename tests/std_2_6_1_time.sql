-- # A TIME literal is only a time of day, so it can't have a date.
VALUES TIME '2022-06-30 21:47:32';
-- error 42601: syntax error: TIME '2022-06-30 21:47:32' is not valid

VALUES TIME '2022-06-30 21:47:32+05:12';
-- error 42601: syntax error: TIME '2022-06-30 21:47:32+05:12' is not valid

-- # Each field has two digits and must make a valid time of day (5.3, Syntax
-- # Rules, 31 and 32). A time zone can be up to 14 hours either side of UTC
-- # (5.3, Syntax Rules, 43), and its sign applies to the minutes too.
/* types */
VALUES TIME '21:47:32';
-- COL1: 21:47:32 (TIME(0) WITHOUT TIME ZONE)

VALUES TIME '25:00:00';
-- error 42601: syntax error: TIME '25:00:00' is not valid

VALUES TIME '21:60:00';
-- error 42601: syntax error: TIME '21:60:00' is not valid

VALUES TIME '1:2:3';
-- error 42601: syntax error: TIME '1:2:3' is not valid

VALUES TIME '21:47:32+14:00';
-- COL1: 21:47:32+1400

VALUES TIME '21:47:32-00:30';
-- COL1: 21:47:32-0030

VALUES TIME 'a21:47:32';
-- error 42601: syntax error: TIME 'a21:47:32' is not valid

VALUES TIME '21:47:32T';
-- error 42601: syntax error: TIME '21:47:32T' is not valid

-- # A literal with a time zone is a TIME WITH TIME ZONE, and its precision is
-- # the number of digits in the fraction of a second (5.3, Syntax Rules, 26).
/* types */
VALUES TIME '21:47:32+05:12';
-- COL1: 21:47:32+0512 (TIME(0) WITH TIME ZONE)

/* types */
VALUES TIME '21:47:32-11:30';
-- COL1: 21:47:32-1130 (TIME(0) WITH TIME ZONE)

/* types */
VALUES TIME '21:47:32.123+05:12';
-- COL1: 21:47:32.123+0512 (TIME(3) WITH TIME ZONE)

-- # Anything with a date, or that isn't a time of day, isn't a TIME literal.
VALUES TIME '2022-06-30 21:47:32-11:30';
-- error 42601: syntax error: TIME '2022-06-30 21:47:32-11:30' is not valid

VALUES TIME '2022-06-30 00:00:00';
-- error 42601: syntax error: TIME '2022-06-30 00:00:00' is not valid

VALUES TIME '2022-06-30 21:47:32.123';
-- error 42601: syntax error: TIME '2022-06-30 21:47:32.123' is not valid

VALUES TIME '2022-06-30 21:47:32.456000+05:12';
-- error 42601: syntax error: TIME '2022-06-30 21:47:32.456000+05:12' is not valid

VALUES TIME '2022-06-30T21:47:32';
-- error 42601: syntax error: TIME '2022-06-30T21:47:32' is not valid

VALUES TIME 'a2022-06-30 21:47:32';
-- error 42601: syntax error: TIME 'a2022-06-30 21:47:32' is not valid

VALUES TIME '2022-06-30 21:47:32a';
-- error 42601: syntax error: TIME '2022-06-30 21:47:32a' is not valid

VALUES TIME '2022-06-30';
-- error 42601: syntax error: TIME '2022-06-30' is not valid

/* types */
VALUES TIME '21:47:32';
-- COL1: 21:47:32 (TIME(0) WITHOUT TIME ZONE)

VALUES TIME 'FOO BAR';
-- error 42601: syntax error: TIME 'FOO BAR' is not valid

VALUES TIME '2022-06-30 21:47:75';
-- error 42601: syntax error: TIME '2022-06-30 21:47:75' is not valid

VALUES TIME '10000-06-30T21:47:32';
-- error 42601: syntax error: TIME '10000-06-30T21:47:32' is not valid

VALUES TIME '-1-06-30T21:47:32';
-- error 42601: syntax error: TIME '-1-06-30T21:47:32' is not valid

VALUES TIME '2022-06-30 21:47:32+12:00';
-- error 42601: syntax error: TIME '2022-06-30 21:47:32+12:00' is not valid

VALUES TIME '2022-06-30 21:47:32-12:00';
-- error 42601: syntax error: TIME '2022-06-30 21:47:32-12:00' is not valid

-- # Storing a TIME in a column of the other kind casts it (9.2, General Rules,
-- # 3.b.xvi.1): a time zone is dropped, keeping the local time (6.13, General
-- # Rules, 16.c), and a missing one becomes the session's, +05:00 here (6.13,
-- # General Rules, 17.c). Extra fractional seconds are truncated.
CREATE TABLE foo (f1 TIME WITHOUT TIME ZONE);
INSERT INTO foo (f1) 
VALUES (TIME '21:47:32');
INSERT INTO foo (f1) 
VALUES (TIME '01:47:32+05:12');
INSERT INTO foo (f1) 
VALUES (TIME '21:47:32.123');
INSERT INTO foo (f1) 
VALUES (TIME '01:47:32.123456+05:12');
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- F1: 21:47:32
-- F1: 01:47:32
-- F1: 21:47:32
-- F1: 01:47:32

CREATE TABLE foo (f1 TIME WITH TIME ZONE);
INSERT INTO foo (f1) 
VALUES (TIME '21:47:32');
INSERT INTO foo (f1) 
VALUES (TIME '01:47:32+05:12');
INSERT INTO foo (f1) 
VALUES (TIME '21:47:32.123');
INSERT INTO foo (f1) 
VALUES (TIME '01:47:32.123456+05:12');
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- F1: 21:47:32+0500
-- F1: 01:47:32+0512
-- F1: 21:47:32+0500
-- F1: 01:47:32+0512

CREATE TABLE foo (f1 TIME (3) WITHOUT TIME ZONE);
INSERT INTO foo (f1) 
VALUES (TIME '21:47:32');
INSERT INTO foo (f1) 
VALUES (TIME '01:47:32+05:12');
INSERT INTO foo (f1) 
VALUES (TIME '21:47:32.123');
INSERT INTO foo (f1) 
VALUES (TIME '01:47:32.123456+05:12');
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- F1: 21:47:32.000
-- F1: 01:47:32.000
-- F1: 21:47:32.123
-- F1: 01:47:32.123

CREATE TABLE foo (f1 TIME (3) WITH TIME ZONE);
INSERT INTO foo (f1) 
VALUES (TIME '21:47:32');
INSERT INTO foo (f1) 
VALUES (TIME '01:47:32+05:12');
INSERT INTO foo (f1) 
VALUES (TIME '21:47:32.123');
INSERT INTO foo (f1) 
VALUES (TIME '01:47:32.123456+05:12');
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- F1: 21:47:32.000+0500
-- F1: 01:47:32.000+0512
-- F1: 21:47:32.123+0500
-- F1: 01:47:32.123+0512

-- # Casting a TIME WITH TIME ZONE. There's no cast to DATE (6.13, Syntax Rules,
-- # 7). Changing the precision truncates or zero-extends the fraction. Dropping
-- # the time zone keeps the local time (6.13, General Rules, 16.c), and a
-- # TIMESTAMP gets today's date, 2022-07-04 here (6.13, General Rules, 19.d).
CREATE TABLE foo (f1 TIME WITH TIME ZONE);
INSERT INTO foo (f1) 
VALUES (TIME '21:47:32+05:00');
SELECT CAST(f1 AS DATE) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 42846: cannot coerce TIME(0) WITH TIME ZONE to DATE

CREATE TABLE foo (f1 TIME WITH TIME ZONE);
INSERT INTO foo (f1) 
VALUES (TIME '21:47:32+05:00');
SELECT CAST(f1 AS TIME WITH TIME ZONE) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 21:47:32+0500

CREATE TABLE foo (f1 TIME(3) WITH TIME ZONE);
INSERT INTO foo (f1) 
VALUES (TIME '21:47:32.123+05:00');
SELECT CAST(f1 AS TIME(2) WITH TIME ZONE) FROM foo;
SELECT CAST(f1 AS TIME(4) WITH TIME ZONE) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 21:47:32.12+0500
-- COL1: 21:47:32.1230+0500

CREATE TABLE foo (f1 TIME WITH TIME ZONE);
INSERT INTO foo (f1) 
VALUES (TIME '21:47:32+05:00');
SELECT CAST(f1 AS TIME WITHOUT TIME ZONE) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 21:47:32

CREATE TABLE foo (f1 TIME(3) WITH TIME ZONE);
INSERT INTO foo (f1) 
VALUES (TIME '21:47:32.123+05:00');
SELECT CAST(f1 AS TIME(2) WITHOUT TIME ZONE) FROM foo;
SELECT CAST(f1 AS TIME(4) WITHOUT TIME ZONE) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 21:47:32.12
-- COL1: 21:47:32.1230

CREATE TABLE foo (f1 TIME WITH TIME ZONE);
INSERT INTO foo (f1) 
VALUES (TIME '21:47:32+05:00');
SELECT CAST(f1 AS TIMESTAMP WITH TIME ZONE) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 2022-07-04T21:47:32.000000+0500

CREATE TABLE foo (f1 TIME WITH TIME ZONE);
INSERT INTO foo (f1) 
VALUES (TIME '21:47:32+05:00');
SELECT CAST(f1 AS TIMESTAMP WITHOUT TIME ZONE) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 2022-07-04T21:47:32.000000

-- # Casting a TIME WITHOUT TIME ZONE. Adding a time zone uses the session's,
-- # +05:00 here (6.13, General Rules, 17.c), and a TIMESTAMP gets today's date
-- # (6.13, General Rules, 18.c and 19.c).
CREATE TABLE foo (f1 TIME WITHOUT TIME ZONE);
INSERT INTO foo (f1) 
VALUES (TIME '21:47:32');
SELECT CAST(f1 AS DATE) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 42846: cannot coerce TIME(0) WITHOUT TIME ZONE to DATE

CREATE TABLE foo (f1 TIME WITHOUT TIME ZONE);
INSERT INTO foo (f1) 
VALUES (TIME '21:47:32');
SELECT CAST(f1 AS TIME WITH TIME ZONE) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 21:47:32+0500

CREATE TABLE foo (f1 TIME(3) WITHOUT TIME ZONE);
INSERT INTO foo (f1) 
VALUES (TIME '21:47:32.123');
SELECT CAST(f1 AS TIME(2) WITH TIME ZONE) FROM foo;
SELECT CAST(f1 AS TIME(4) WITH TIME ZONE) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 21:47:32.12+0500
-- COL1: 21:47:32.1230+0500

CREATE TABLE foo (f1 TIME WITHOUT TIME ZONE);
INSERT INTO foo (f1) 
VALUES (TIME '21:47:32');
SELECT CAST(f1 AS TIME WITHOUT TIME ZONE) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 21:47:32

CREATE TABLE foo (f1 TIME(3) WITHOUT TIME ZONE);
INSERT INTO foo (f1) 
VALUES (TIME '21:47:32.123');
SELECT CAST(f1 AS TIME(2) WITHOUT TIME ZONE) FROM foo;
SELECT CAST(f1 AS TIME(4) WITHOUT TIME ZONE) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 21:47:32.12
-- COL1: 21:47:32.1230

CREATE TABLE foo (f1 TIME WITHOUT TIME ZONE);
INSERT INTO foo (f1) 
VALUES (TIME '21:47:32');
SELECT CAST(f1 AS TIMESTAMP WITH TIME ZONE) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 2022-07-04T21:47:32.000000+0500

CREATE TABLE foo (f1 TIME WITHOUT TIME ZONE);
INSERT INTO foo (f1) 
VALUES (TIME '21:47:32');
SELECT CAST(f1 AS TIMESTAMP WITHOUT TIME ZONE) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 2022-07-04T21:47:32.000000

-- # When casting a TIME to a TIMESTAMP the date is CURRENT_DATE. A TIME WITH
-- # TIME ZONE keeps its own time zone, rather than the session time zone.
CREATE TABLE foo (f1 TIME(3) WITH TIME ZONE);
INSERT INTO foo (f1) VALUES (TIME '21:47:32.123+02:00');
SELECT CAST(f1 AS TIMESTAMP(2) WITH TIME ZONE) FROM foo;
SELECT CAST(f1 AS TIMESTAMP(0) WITHOUT TIME ZONE) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 2022-07-04T21:47:32.12+0200
-- COL1: 2022-07-04T21:47:32

VALUES CAST(TIME '01:02:03-11:30' AS TIMESTAMP WITH TIME ZONE);
-- COL1: 2022-07-04T01:02:03.000000-1130

VALUES CAST(TIME '01:02:03.456' AS TIMESTAMP(3) WITH TIME ZONE);
-- COL1: 2022-07-04T01:02:03.456+0500

VALUES CAST(TIME '01:02:03.456' AS TIMESTAMP(3) WITHOUT TIME ZONE);
-- COL1: 2022-07-04T01:02:03.456

-- # A string is trimmed, then read as a time (6.13, General Rules, 16.a.ii).
-- # Extra fractional seconds are truncated.
/* types */
VALUES CAST('12:34:56' AS TIME);
-- COL1: 12:34:56 (TIME(0) WITHOUT TIME ZONE)

VALUES CAST(' 12:34:56.789 ' AS TIME(1));
-- COL1: 12:34:56.7

-- # The time zone is dropped, keeping the local time.
VALUES CAST('12:34:56+03:00' AS TIME);
-- COL1: 12:34:56

-- # The session time zone is added.
VALUES CAST('12:34:56' AS TIME WITH TIME ZONE);
-- COL1: 12:34:56+0500

-- # A string with a time zone keeps it. A string that isn't a valid time,
-- # including one with a date, is an invalid datetime format (6.13, General
-- # Rules, 16.a.ii.3).
/* types */
VALUES CAST('12:34:56.5-03:00' AS TIME(2) WITH TIME ZONE);
-- COL1: 12:34:56.50-0300 (TIME(2) WITH TIME ZONE)

VALUES CAST('25:00:00' AS TIME);
-- error 22007: invalid datetime format

VALUES CAST('2022-06-30 12:34:56' AS TIME);
-- error 22007: invalid datetime format

-- # A time literal is also accepted, but the keyword must be TIME.
VALUES CAST('TIME ''12:34:56+03:00''' AS TIME WITH TIME ZONE);
-- COL1: 12:34:56+0300

VALUES CAST(CAST(TIME '12:34:56' AS VARCHAR(30)) AS TIME);
-- COL1: 12:34:56

VALUES CAST('TIMESTAMP ''2022-06-30 12:34:56''' AS TIME);
-- error 22007: invalid datetime format

-- # A time zone out of the range of -14:00 to +14:00 is an invalid time zone
-- # displacement (General Rules, 8).
VALUES CAST('12:34:56-14:00' AS TIME WITH TIME ZONE);
-- COL1: 12:34:56-1400

VALUES CAST('12:34:56-14:30' AS TIME WITH TIME ZONE);
-- error 22009: invalid time zone displacement value

-- # Times with a time zone are compared in UTC, which wraps around midnight
-- # (8.2, General Rules, 6). A time without one is taken to be in the session
-- # time zone.
VALUES TIME '10:00:00+01:00' = TIME '09:00:00+00:00';
-- COL1: TRUE

VALUES TIME '10:00:00+01:00' > TIME '09:30:00+00:00';
-- COL1: FALSE

VALUES TIME '00:30:00+01:00' = TIME '23:30:00+00:00';
-- COL1: TRUE

VALUES TIME '10:00:00' = TIME '05:00:00+00:00';
-- COL1: TRUE
