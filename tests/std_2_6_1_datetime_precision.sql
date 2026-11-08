-- # The largest TIME and TIMESTAMP precision is 6 (Syntax Rules, 38), with or
-- # without a time zone, in a CAST or a column. A precision of 6 shows 6 digits
-- # after the point (General Rules, 5).
VALUES CAST(TIME '10:00:00' AS TIME(6));
-- COL1: 10:00:00.000000

VALUES CAST(TIME '10:00:00' AS TIME(7));
-- error 42601: syntax error: TIME(7): cannot have precision greater than 6

VALUES CAST(TIME '10:00:00' AS TIME(9) WITH TIME ZONE);
-- error 42601: syntax error: TIME(9): cannot have precision greater than 6

VALUES CAST(TIMESTAMP '2022-06-30 12:34:56' AS TIMESTAMP(6));
-- COL1: 2022-06-30T12:34:56.000000

VALUES CAST(TIMESTAMP '2022-06-30 12:34:56' AS TIMESTAMP(9));
-- error 42601: syntax error: TIMESTAMP(9): cannot have precision greater than 6

VALUES CAST(TIMESTAMP '2022-06-30 12:34:56' AS TIMESTAMP(7) WITHOUT TIME ZONE);
-- error 42601: syntax error: TIMESTAMP(7): cannot have precision greater than 6

CREATE TABLE foo (x TIME(7));
-- error 42601: syntax error: TIME(7): cannot have precision greater than 6

CREATE TABLE foo (x TIMESTAMP(9) WITH TIME ZONE);
-- error 42601: syntax error: TIMESTAMP(9): cannot have precision greater than 6

-- # A TIMESTAMP literal's precision is its number of fraction digits, and
-- # casting it to a string gives a TIMESTAMP literal with all of them (6.13,
-- # General Rules, 12.e.i.2).
VALUES TIMESTAMP '2022-01-02 03:04:05.000006';
-- COL1: 2022-01-02T03:04:05.000006

VALUES CAST(TIMESTAMP '2022-01-02 03:04:05.000006' AS VARCHAR(50));
-- COL1: TIMESTAMP '2022-01-02 03:04:05.000006'

-- # Casting to a lower precision truncates the extra digits (6.13, General
-- # Rules, 16.b).
VALUES TIME '03:04:05.000123';
-- COL1: 03:04:05.000123

VALUES CAST(TIME '03:04:05.000123' AS TIME(4));
-- COL1: 03:04:05.0001
