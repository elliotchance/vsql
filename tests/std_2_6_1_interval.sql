-- # An interval literal has the type of its interval qualifier. A field
-- # without a leading field precision has 2 digits, and SECOND has 6
-- # fractional digits (10.1, Syntax Rules, 5 and 6).
/* types */
VALUES INTERVAL '3' YEAR;
-- COL1: 3 (INTERVAL YEAR(2))

/* types */
VALUES INTERVAL '1-2' YEAR TO MONTH;
-- COL1: 1-02 (INTERVAL YEAR(2) TO MONTH)

/* types */
VALUES INTERVAL '15' MONTH(3);
-- COL1: 15 (INTERVAL MONTH(3))

/* types */
VALUES INTERVAL '3' DAY;
-- COL1: 3 (INTERVAL DAY(2))

/* types */
VALUES INTERVAL '3 4' DAY TO HOUR;
-- COL1: 3 04 (INTERVAL DAY(2) TO HOUR)

/* types */
VALUES INTERVAL '3 4:05' DAY TO MINUTE;
-- COL1: 3 04:05 (INTERVAL DAY(2) TO MINUTE)

/* types */
VALUES INTERVAL '3 4:05:06.5' DAY TO SECOND;
-- COL1: 3 04:05:06.500000 (INTERVAL DAY(2) TO SECOND(6))

/* types */
VALUES INTERVAL '4' HOUR;
-- COL1: 4 (INTERVAL HOUR(2))

/* types */
VALUES INTERVAL '4:05' HOUR TO MINUTE;
-- COL1: 4:05 (INTERVAL HOUR(2) TO MINUTE)

/* types */
VALUES INTERVAL '4:05:06' HOUR(3) TO SECOND(0);
-- COL1: 4:05:06 (INTERVAL HOUR(3) TO SECOND(0))

/* types */
VALUES INTERVAL '5' MINUTE;
-- COL1: 5 (INTERVAL MINUTE(2))

/* types */
VALUES INTERVAL '5:06.123' MINUTE TO SECOND(3);
-- COL1: 5:06.123 (INTERVAL MINUTE(2) TO SECOND(3))

/* types */
VALUES INTERVAL '6.25' SECOND;
-- COL1: 6.250000 (INTERVAL SECOND(2, 6))

/* types */
VALUES INTERVAL '12345678.5' SECOND(8, 1);
-- COL1: 12345678.5 (INTERVAL SECOND(8, 1))

-- # An interval can be negative, with a sign before or inside the string. Two
-- # signs cancel out.
VALUES INTERVAL -'1-2' YEAR TO MONTH;
VALUES INTERVAL '-1-2' YEAR TO MONTH;
VALUES INTERVAL -'-1-2' YEAR TO MONTH;
VALUES INTERVAL +'3 4:05:06' DAY TO SECOND(0);
VALUES INTERVAL '-3 4:05:06' DAY TO SECOND(0);
-- COL1: -1-02
-- COL1: -1-02
-- COL1: 1-02
-- COL1: 3 04:05:06
-- COL1: -3 04:05:06

-- # The string must have each field of the qualifier, and nothing else. A
-- # field after the first is less than the field before it, and the first
-- # field can't have more digits than its precision.
VALUES INTERVAL '1' YEAR TO MONTH;
-- error 42601: syntax error: INTERVAL '1' YEAR(2) TO MONTH is not valid

VALUES INTERVAL '1-12' YEAR TO MONTH;
-- error 42601: syntax error: INTERVAL '1-12' YEAR(2) TO MONTH is not valid

VALUES INTERVAL '100' YEAR;
-- error 42601: syntax error: INTERVAL '100' YEAR(2) is not valid

VALUES INTERVAL '3 24' DAY TO HOUR;
-- error 42601: syntax error: INTERVAL '3 24' DAY(2) TO HOUR is not valid

VALUES INTERVAL '1:60' HOUR TO MINUTE;
-- error 42601: syntax error: INTERVAL '1:60' HOUR(2) TO MINUTE is not valid

VALUES INTERVAL '1:2:60' HOUR TO SECOND;
-- error 42601: syntax error: INTERVAL '1:2:60' HOUR(2) TO SECOND(6) is not valid

VALUES INTERVAL '1.5' MINUTE;
-- error 42601: syntax error: INTERVAL '1.5' MINUTE(2) is not valid

-- # Digits after the fractional seconds precision are truncated (5.3,
-- # General Rules, 10.b).
VALUES INTERVAL '1.1234567' SECOND;
VALUES INTERVAL '-1:02.99' MINUTE TO SECOND(1);
-- COL1: 1.123456
-- COL1: -1:02.9

VALUES INTERVAL '1.x' SECOND;
-- error 42601: syntax error: INTERVAL '1.x' SECOND(2, 6) is not valid

VALUES INTERVAL '' DAY;
-- error 42601: syntax error: INTERVAL '' DAY(2) is not valid

VALUES INTERVAL 'a' DAY;
-- error 42601: syntax error: INTERVAL 'a' DAY(2) is not valid

VALUES INTERVAL '99999999999999999999' SECOND(8);
-- error 42601: syntax error: INTERVAL '99999999999999999999' SECOND(8, 6) is not valid

-- # The start field must be before the end field, it can't be MONTH, and
-- # YEAR can only be followed by MONTH (10.1, Syntax Rules, 2). The leading
-- # field precision is from 1 to 8, and the fractional seconds precision is up
-- # to 6 (10.1, Syntax Rules, 3-6).
VALUES INTERVAL '1' MONTH TO YEAR;
-- error 42601: syntax error: invalid interval qualifier: MONTH TO YEAR

VALUES INTERVAL '1' YEAR TO DAY;
-- error 42601: syntax error: invalid interval qualifier: YEAR TO DAY

VALUES INTERVAL '1' DAY TO MONTH;
-- error 42601: syntax error: invalid interval qualifier: DAY TO MONTH

VALUES INTERVAL '1' MONTH TO DAY;
-- error 42601: syntax error: invalid interval qualifier: MONTH TO DAY

VALUES INTERVAL '1' HOUR TO HOUR;
-- error 42601: syntax error: invalid interval qualifier: HOUR TO HOUR

VALUES INTERVAL '1' DAY(0);
-- error 42601: syntax error: INTERVAL leading field precision must be between 1 and 8

VALUES INTERVAL '1' DAY(9);
-- error 42601: syntax error: INTERVAL leading field precision must be between 1 and 8

VALUES INTERVAL '1' SECOND(2, 7);
-- error 42601: syntax error: INTERVAL fractional seconds precision must not be greater than 6

-- # An interval column stores the value in the fields of its type. Fields
-- # after the end field are removed, and the leading field must fit in its
-- # precision, or it's 22015 (9.2, General Rules, 3.b.xvii).
/* types */
CREATE TABLE t (a INTERVAL YEAR TO MONTH, b INTERVAL YEAR(4), c INTERVAL DAY TO SECOND(3), d INTERVAL HOUR(3), e INTERVAL MINUTE(8) TO SECOND(0));
INSERT INTO t VALUES (INTERVAL '2' YEAR, INTERVAL '1-11' YEAR TO MONTH, INTERVAL '1 2:03:04.56789' DAY TO SECOND, INTERVAL '2 03:04' DAY TO MINUTE, INTERVAL '-1.9' SECOND);
INSERT INTO t (a) VALUES (NULL);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- A: 2-00 (INTERVAL YEAR(2) TO MONTH) B: 1 (INTERVAL YEAR(4)) C: 1 02:03:04.567 (INTERVAL DAY(2) TO SECOND(3)) D: 51 (INTERVAL HOUR(3)) E: -0:01 (INTERVAL MINUTE(8) TO SECOND(0))
-- A: NULL (INTERVAL YEAR(2) TO MONTH) B: NULL (INTERVAL YEAR(4)) C: NULL (INTERVAL DAY(2) TO SECOND(3)) D: NULL (INTERVAL HOUR(3)) E: NULL (INTERVAL MINUTE(8) TO SECOND(0))

CREATE TABLE t (a INTERVAL HOUR, b INTERVAL MONTH);
INSERT INTO t (a) VALUES (INTERVAL '5' DAY);
INSERT INTO t (b) VALUES (INTERVAL '9' YEAR);
INSERT INTO t (a) VALUES (INTERVAL '1' MONTH);
INSERT INTO t (a) VALUES ('1');
-- msg: CREATE TABLE 1
-- error 22015: interval field overflow
-- error 22015: interval field overflow
-- error 42846: cannot coerce INTERVAL MONTH(2) to INTERVAL HOUR(2)
-- error 42846: cannot coerce CHARACTER(1) to INTERVAL HOUR(2)

-- # An interval can be a PRIMARY KEY, and the default of a column.
CREATE TABLE t (a INTERVAL DAY TO SECOND(0) PRIMARY KEY, b INTERVAL YEAR DEFAULT INTERVAL '1' YEAR);
INSERT INTO t (a) VALUES (INTERVAL '1' DAY), (INTERVAL '-2' HOUR), (INTERVAL '0' SECOND), (INTERVAL '23' HOUR);
SELECT * FROM t;
INSERT INTO t (a) VALUES (INTERVAL '24' HOUR);
-- msg: CREATE TABLE 1
-- msg: INSERT 4
-- A: -0 02:00:00 B: 1
-- A: 0 00:00:00 B: 1
-- A: 0 23:00:00 B: 1
-- A: 1 00:00:00 B: 1
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T

CREATE TABLE t (a INTERVAL YEAR DEFAULT INTERVAL '1' DAY);
-- error 42601: syntax error: DEFAULT INTERVAL '1' DAY(2) is not valid for column A INTERVAL YEAR(2)

-- # A CAST can be to another interval with the same kind of fields.
/* types */
VALUES CAST(INTERVAL '25' HOUR AS INTERVAL DAY TO HOUR);
-- COL1: 1 01 (INTERVAL DAY(2) TO HOUR)

VALUES CAST(INTERVAL '25' HOUR AS INTERVAL YEAR);
-- error 42846: cannot coerce INTERVAL HOUR(2) to INTERVAL YEAR(2)

VALUES CAST(INTERVAL '25' HOUR AS VARCHAR(10));
-- error 42846: cannot coerce INTERVAL HOUR(2) to CHARACTER VARYING(10)
