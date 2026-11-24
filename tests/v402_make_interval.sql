-- # MAKE_INTERVAL(years, months, weeks, days, hours, mins, secs) (V402-21)
-- # builds an interval from numbers, like PostgreSQL's make_interval. Trailing
-- # arguments can be left out, and are 0. It's a year-month interval when only
-- # the years or months are given, otherwise a day-time interval.

/* setup */
CREATE TABLE jobs (id INT, ts TIMESTAMP(0), retention_days INT, extra_months INT);
INSERT INTO jobs VALUES (1, TIMESTAMP '2026-11-17 12:00:00', 3, 2), (2, TIMESTAMP '2026-11-30 06:30:00', 30, 0), (3, TIMESTAMP '2026-12-31 23:00:00', NULL, NULL);

/* types */
VALUES ROW(MAKE_INTERVAL(1, 6), MAKE_INTERVAL(0, 0, 2), MAKE_INTERVAL(0, 0, 0, 3, 4, 5, 6.5));
-- COL1: 1-06 (INTERVAL YEAR(8) TO MONTH) COL2: 14 (INTERVAL DAY(8)) COL3: 3 04:05:06.500000 (INTERVAL DAY(8) TO SECOND(6))

-- # Each argument on its own. A day-time interval is to the smallest unit
-- # that's given, so weeks or days are an INTERVAL DAY, which can be added to
-- # a DATE.
/* types */
VALUES ROW(MAKE_INTERVAL(2), MAKE_INTERVAL(0, 5), MAKE_INTERVAL(0, 0, 1), MAKE_INTERVAL(0, 0, 0, 4));
-- COL1: 2-00 (INTERVAL YEAR(8) TO MONTH) COL2: 0-05 (INTERVAL YEAR(8) TO MONTH) COL3: 7 (INTERVAL DAY(8)) COL4: 4 (INTERVAL DAY(8))

/* types */
VALUES ROW(MAKE_INTERVAL(0, 0, 0, 0, 7), MAKE_INTERVAL(0, 0, 0, 0, 0, 8), MAKE_INTERVAL(0, 0, 0, 0, 0, 0, 9), MAKE_INTERVAL(0, 0, 0, 0, 0, 0, 0.000001));
-- COL1: 0 07 (INTERVAL DAY(8) TO HOUR) COL2: 0 00:08 (INTERVAL DAY(8) TO MINUTE) COL3: 0 00:00:09.000000 (INTERVAL DAY(8) TO SECOND(6)) COL4: 0 00:00:00.000001 (INTERVAL DAY(8) TO SECOND(6))

-- # With no arguments, or only zeros, it's a zero day-time interval.
/* types */
VALUES ROW(MAKE_INTERVAL(), MAKE_INTERVAL(0), MAKE_INTERVAL(0, 0, 0, 0, 0, 0, 0));
-- COL1: 0 00:00:00.000000 (INTERVAL DAY(8) TO SECOND(6)) COL2: 0 00:00:00.000000 (INTERVAL DAY(8) TO SECOND(6)) COL3: 0 00:00:00.000000 (INTERVAL DAY(8) TO SECOND(6))

-- # A constant 0 (even an expression) isn't counted as given, so the first is
-- # a year-month interval and the second is a day-time interval.
/* types */
VALUES ROW(MAKE_INTERVAL(1, 6, 0, 0, 0, 0, 0), MAKE_INTERVAL(0, 0 + 0, 0, 3));
-- COL1: 1-06 (INTERVAL YEAR(8) TO MONTH) COL2: 3 (INTERVAL DAY(8))

-- # A year-month and a day-time part can't be in the same interval, so they
-- # have to be two intervals.
VALUES MAKE_INTERVAL(1, 0, 0, 3);
-- error 42601: syntax error: MAKE_INTERVAL can't have both years or months and a smaller unit, add two intervals instead

SELECT MAKE_INTERVAL(0, extra_months, 0, retention_days) FROM jobs;
-- error 42601: syntax error: MAKE_INTERVAL can't have both years or months and a smaller unit, add two intervals instead

SELECT ts + MAKE_INTERVAL(0, extra_months) + MAKE_INTERVAL(0, 0, 0, retention_days) AS due FROM jobs ORDER BY id;
-- DUE: 2027-01-20T12:00:00
-- DUE: 2026-12-30T06:30:00
-- DUE: NULL

-- # The seconds can have a fraction, as an exact number or a DOUBLE
-- # PRECISION. A fraction past microseconds is truncated.
VALUES ROW(MAKE_INTERVAL(0, 0, 0, 0, 0, 0, 6.5), MAKE_INTERVAL(0, 0, 0, 0, 0, 0, 1.25e0), MAKE_INTERVAL(0, 0, 0, 0, 0, 0, 1.2345678));
-- COL1: 0 00:00:06.500000 COL2: 0 00:00:01.250000 COL3: 0 00:00:01.234567

-- # The other arguments are integers.
VALUES MAKE_INTERVAL(1.5);
-- error 42883: function does not exist: MAKE_INTERVAL(NUMERIC(2, 1))

-- # Values aren't normalised as they're given, but an interval is always shown
-- # normalised: 25 hours is 1 day 1 hour, and 14 months is 1 year 2 months.
VALUES ROW(MAKE_INTERVAL(0, 0, 0, 0, 25), MAKE_INTERVAL(0, 14), MAKE_INTERVAL(0, 0, 0, 0, 0, 90), MAKE_INTERVAL(0, 0, 0, 0, 0, 0, 3600));
-- COL1: 1 01 COL2: 1-02 COL3: 0 01:30 COL4: 0 01:00:00.000000

-- # Negative values can be mixed.
VALUES ROW(MAKE_INTERVAL(0, 0, 0, 1, -2), MAKE_INTERVAL(-1, 3), MAKE_INTERVAL(0, 0, 0, -1), MAKE_INTERVAL(0, 0, 0, 0, 0, 0, -0.5));
-- COL1: 0 22 COL2: -0-09 COL3: -1 COL4: -0 00:00:00.500000

-- # A NULL argument makes it NULL.
/* types */
VALUES ROW(MAKE_INTERVAL(CAST(NULL AS INT)), MAKE_INTERVAL(0, 0, 0, CAST(NULL AS INT)), MAKE_INTERVAL(0, 0, 0, 0, 0, 0, CAST(NULL AS DOUBLE PRECISION)));
-- COL1: NULL (INTERVAL YEAR(8) TO MONTH) COL2: NULL (INTERVAL DAY(8)) COL3: NULL (INTERVAL DAY(8) TO SECOND(6))

-- # The leading field can have up to 8 digits, otherwise it's an interval field
-- # overflow.
VALUES ROW(MAKE_INTERVAL(99999999, 11), MAKE_INTERVAL(0, 0, 0, 99999999, 23, 59, 59.999999));
-- COL1: 99999999-11 COL2: 99999999 23:59:59.999999

VALUES MAKE_INTERVAL(100000000);
-- error 22015: interval field overflow

VALUES MAKE_INTERVAL(99999999, 12);
-- error 22015: interval field overflow

VALUES MAKE_INTERVAL(0, 0, 0, 99999999, 24);
-- error 22015: interval field overflow

VALUES MAKE_INTERVAL(0, 0, 0, -100000000);
-- error 22015: interval field overflow

VALUES MAKE_INTERVAL(0, 0, 9223372036854775807);
-- error 22015: interval field overflow

-- # It can be added to a DATE or TIMESTAMP.
VALUES ROW(DATE '2026-01-15' + MAKE_INTERVAL(0, 1), DATE '2026-11-17' + MAKE_INTERVAL(0, 0, 2), TIMESTAMP '2026-11-17 12:00:00' + MAKE_INTERVAL(0, 0, 1, 1, 1, 1, 1.5), TIMESTAMP '2026-11-17 12:00:00' - MAKE_INTERVAL(1));
-- COL1: 2026-02-15 COL2: 2026-12-01 COL3: 2026-11-25T13:01:01.500000 COL4: 2025-11-17T12:00:00

SELECT id, ts + MAKE_INTERVAL(0, 0, 0, retention_days) AS expires FROM jobs ORDER BY id;
-- ID: 1 EXPIRES: 2026-11-20T12:00:00
-- ID: 2 EXPIRES: 2026-12-30T06:30:00
-- ID: 3 EXPIRES: NULL

-- # The same as multiplying an interval.
VALUES MAKE_INTERVAL(0, 0, 0, 3) = 3 * INTERVAL '1' DAY;
-- COL1: TRUE

-- # The flagger reports it (see docs/sql-flagging.rst). F641 and F661 are for
-- # VALUES.
/* flags */
VALUES MAKE_INTERVAL(0, 0, 0, 3);
-- flags: F641, F661, V402-21
-- COL1: 3
