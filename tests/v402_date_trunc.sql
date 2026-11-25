-- # DATE_TRUNC(field, source) (V402-20) rounds a datetime down to the start of
-- # a unit, like PostgreSQL's date_trunc. The result has the type of the
-- # source, including its precision and time zone.

/* setup */
CREATE TABLE orders (id INT, created_at TIMESTAMP, unit VARCHAR(10));
INSERT INTO orders VALUES (1, TIMESTAMP '2026-10-03 10:00:00', 'month'), (2, TIMESTAMP '2026-11-17 14:35:21', 'month'), (3, TIMESTAMP '2026-11-01 00:00:00', 'month'), (4, NULL, 'month');

/* types */
VALUES ROW(DATE_TRUNC('month', TIMESTAMP '2026-11-17 14:35:21.5'), DATE_TRUNC('hour', TIMESTAMP '2026-11-17 14:35:21.5'));
-- COL1: 2026-11-01T00:00:00.0 (TIMESTAMP(1) WITHOUT TIME ZONE) COL2: 2026-11-17T14:00:00.0 (TIMESTAMP(1) WITHOUT TIME ZONE)

-- # Every field of a TIMESTAMP.
VALUES ROW(DATE_TRUNC('microseconds', TIMESTAMP '2026-11-17 14:35:21.123456'), DATE_TRUNC('milliseconds', TIMESTAMP '2026-11-17 14:35:21.123456'), DATE_TRUNC('second', TIMESTAMP '2026-11-17 14:35:21.123456'), DATE_TRUNC('minute', TIMESTAMP '2026-11-17 14:35:21.123456'));
-- COL1: 2026-11-17T14:35:21.123456 COL2: 2026-11-17T14:35:21.123000 COL3: 2026-11-17T14:35:21.000000 COL4: 2026-11-17T14:35:00.000000

VALUES ROW(DATE_TRUNC('hour', TIMESTAMP '2026-11-17 14:35:21.123456'), DATE_TRUNC('day', TIMESTAMP '2026-11-17 14:35:21.123456'), DATE_TRUNC('week', TIMESTAMP '2026-11-17 14:35:21.123456'), DATE_TRUNC('month', TIMESTAMP '2026-11-17 14:35:21.123456'));
-- COL1: 2026-11-17T14:00:00.000000 COL2: 2026-11-17T00:00:00.000000 COL3: 2026-11-16T00:00:00.000000 COL4: 2026-11-01T00:00:00.000000

VALUES ROW(DATE_TRUNC('quarter', TIMESTAMP '2026-11-17 14:35:21'), DATE_TRUNC('year', TIMESTAMP '2026-11-17 14:35:21'), DATE_TRUNC('decade', TIMESTAMP '2026-11-17 14:35:21'), DATE_TRUNC('century', TIMESTAMP '2026-11-17 14:35:21'), DATE_TRUNC('millennium', TIMESTAMP '2026-11-17 14:35:21'));
-- COL1: 2026-10-01T00:00:00 COL2: 2026-01-01T00:00:00 COL3: 2020-01-01T00:00:00 COL4: 2001-01-01T00:00:00 COL5: 2001-01-01T00:00:00

-- # A DATE stays a DATE, and has the fields of a day and larger.
/* types */
VALUES ROW(DATE_TRUNC('day', DATE '2026-11-17'), DATE_TRUNC('week', DATE '2026-11-17'), DATE_TRUNC('month', DATE '2026-11-17'), DATE_TRUNC('quarter', DATE '2026-11-17'));
-- COL1: 2026-11-17 (DATE) COL2: 2026-11-16 (DATE) COL3: 2026-11-01 (DATE) COL4: 2026-10-01 (DATE)

VALUES ROW(DATE_TRUNC('year', DATE '2026-11-17'), DATE_TRUNC('decade', DATE '2026-11-17'), DATE_TRUNC('century', DATE '2026-11-17'), DATE_TRUNC('millennium', DATE '2026-11-17'));
-- COL1: 2026-01-01 COL2: 2020-01-01 COL3: 2001-01-01 COL4: 2001-01-01

-- # So it can be compared to a DATE.
VALUES DATE_TRUNC('month', DATE '2026-11-17') = DATE '2026-11-01';
-- COL1: TRUE

-- # A TIME has the fields of an hour and smaller, and keeps its time zone.
/* types */
VALUES ROW(DATE_TRUNC('hour', TIME '14:35:21.123456'), DATE_TRUNC('minute', TIME '14:35:21+05:30'), DATE_TRUNC('second', TIME '14:35:21.5'), DATE_TRUNC('milliseconds', TIME '14:35:21.1234-08:00'), DATE_TRUNC('microseconds', TIME '14:35:21.123456'));
-- COL1: 14:00:00.000000 (TIME(6) WITHOUT TIME ZONE) COL2: 14:35:00+0530 (TIME(0) WITH TIME ZONE) COL3: 14:35:21.0 (TIME(1) WITHOUT TIME ZONE) COL4: 14:35:21.1230-0800 (TIME(4) WITH TIME ZONE) COL5: 14:35:21.123456 (TIME(6) WITHOUT TIME ZONE)

-- # The field is in any case.
VALUES ROW(DATE_TRUNC('MONTH', DATE '2026-11-17'), DATE_TRUNC('Month', DATE '2026-11-17'), date_trunc('mOnTh', date '2026-11-17'));
-- COL1: 2026-11-01 COL2: 2026-11-01 COL3: 2026-11-01

-- # An ISO week starts on a Monday, which can be in the year before.
-- # 2026-01-01 is a Thursday.
VALUES ROW(DATE_TRUNC('week', DATE '2026-01-01'), DATE_TRUNC('week', DATE '2026-11-16'), DATE_TRUNC('week', DATE '2026-11-22'), DATE_TRUNC('week', DATE '0001-01-07'));
-- COL1: 2025-12-29 COL2: 2026-11-16 COL3: 2026-11-16 COL4: 0001-01-01

-- # Quarters start on January 1, April 1, July 1 and October 1.
VALUES ROW(DATE_TRUNC('quarter', DATE '2026-01-01'), DATE_TRUNC('quarter', DATE '2026-03-31'), DATE_TRUNC('quarter', DATE '2026-04-01'), DATE_TRUNC('quarter', DATE '2026-09-30'), DATE_TRUNC('quarter', DATE '2026-12-31'));
-- COL1: 2026-01-01 COL2: 2026-01-01 COL3: 2026-04-01 COL4: 2026-07-01 COL5: 2026-10-01

-- # A decade starts in a year divisible by 10. Centuries and millenniums start
-- # in a year ending in 1, so 2000 is in the century that starts in 1901.
VALUES ROW(DATE_TRUNC('decade', DATE '2029-12-31'), DATE_TRUNC('decade', DATE '2030-01-01'), DATE_TRUNC('decade', DATE '0010-06-01'));
-- COL1: 2020-01-01 COL2: 2030-01-01 COL3: 0010-01-01

VALUES ROW(DATE_TRUNC('century', DATE '2000-06-01'), DATE_TRUNC('century', DATE '2001-01-01'), DATE_TRUNC('century', DATE '0001-01-01'), DATE_TRUNC('century', DATE '0100-12-31'), DATE_TRUNC('century', DATE '0101-01-01'));
-- COL1: 1901-01-01 COL2: 2001-01-01 COL3: 0001-01-01 COL4: 0001-01-01 COL5: 0101-01-01

VALUES ROW(DATE_TRUNC('millennium', DATE '2000-06-01'), DATE_TRUNC('millennium', DATE '2001-01-01'), DATE_TRUNC('millennium', DATE '1000-12-31'), DATE_TRUNC('millennium', DATE '9999-12-31'));
-- COL1: 1001-01-01 COL2: 2001-01-01 COL3: 0001-01-01 COL4: 9001-01-01

-- # There's no year 0, so the years 1 to 9 have no decade.
VALUES DATE_TRUNC('decade', DATE '0009-12-31');
-- error 22008: datetime field overflow

-- # A field smaller than the precision of the value doesn't change it.
/* types */
VALUES ROW(DATE_TRUNC('microseconds', TIMESTAMP '2026-11-17 14:35:21'), DATE_TRUNC('milliseconds', TIMESTAMP '2026-11-17 14:35:21.12'), DATE_TRUNC('milliseconds', CAST(TIMESTAMP '2026-11-17 14:35:21.987654' AS TIMESTAMP(3))));
-- COL1: 2026-11-17T14:35:21 (TIMESTAMP(0) WITHOUT TIME ZONE) COL2: 2026-11-17T14:35:21.12 (TIMESTAMP(2) WITHOUT TIME ZONE) COL3: 2026-11-17T14:35:21.987 (TIMESTAMP(3) WITHOUT TIME ZONE)

-- # A value WITH TIME ZONE is truncated in its own time zone, which it keeps.
/* types */
VALUES ROW(DATE_TRUNC('day', TIMESTAMP '2026-11-17 01:30:00+11:00'), DATE_TRUNC('day', TIMESTAMP '2026-11-17 23:30:00-05:00'), DATE_TRUNC('hour', TIMESTAMP '2026-11-17 23:30:00+05:30'));
-- COL1: 2026-11-17T00:00:00+1100 (TIMESTAMP(0) WITH TIME ZONE) COL2: 2026-11-17T00:00:00-0500 (TIMESTAMP(0) WITH TIME ZONE) COL3: 2026-11-17T23:00:00+0530 (TIMESTAMP(0) WITH TIME ZONE)

-- # It rounds down, never to the nearest.
VALUES ROW(DATE_TRUNC('hour', TIME '14:59:59.999999'), DATE_TRUNC('year', DATE '2026-12-31'));
-- COL1: 14:00:00.000000 COL2: 2026-01-01

-- # A NULL source is NULL.
/* types */
VALUES ROW(DATE_TRUNC('month', CAST(NULL AS DATE)), DATE_TRUNC('hour', CAST(NULL AS TIMESTAMP(3) WITH TIME ZONE)));
-- COL1: NULL (DATE) COL2: NULL (TIMESTAMP(3) WITH TIME ZONE)

-- # A field that the type doesn't have is an error.
VALUES DATE_TRUNC('hour', DATE '2026-11-17');
-- error 42804: data type mismatch in DATE_TRUNC('HOUR', ...): expected TIME or TIMESTAMP but got DATE

VALUES DATE_TRUNC('microseconds', DATE '2026-11-17');
-- error 42804: data type mismatch in DATE_TRUNC('MICROSECONDS', ...): expected TIME or TIMESTAMP but got DATE

VALUES DATE_TRUNC('day', TIME '12:00:00');
-- error 42804: data type mismatch in DATE_TRUNC('DAY', ...): expected DATE or TIMESTAMP but got TIME(0) WITHOUT TIME ZONE

VALUES DATE_TRUNC('millennium', TIME '12:00:00+01:00');
-- error 42804: data type mismatch in DATE_TRUNC('MILLENNIUM', ...): expected DATE or TIMESTAMP but got TIME(0) WITH TIME ZONE

-- # An unknown field is an error.
VALUES DATE_TRUNC('fortnight', DATE '2026-11-17');
-- error 42601: syntax error: DATE_TRUNC has no field fortnight

VALUES DATE_TRUNC('months', DATE '2026-11-17');
-- error 42601: syntax error: DATE_TRUNC has no field months

-- # The field must be a constant that isn't NULL.
SELECT DATE_TRUNC(unit, created_at) FROM orders;
-- error 42601: syntax error: the field of DATE_TRUNC must be a constant that isn't NULL

VALUES DATE_TRUNC(CAST(NULL AS VARCHAR(10)), DATE '2026-11-17');
-- error 42601: syntax error: the field of DATE_TRUNC must be a constant that isn't NULL

-- # Its usual use is grouping by a period.
SELECT first_day, COUNT(*) AS n FROM (SELECT DATE_TRUNC('month', created_at) AS first_day FROM orders WHERE created_at IS NOT NULL) AS t GROUP BY first_day ORDER BY first_day;
-- FIRST_DAY: 2026-10-01T00:00:00.000000 N: 1
-- FIRST_DAY: 2026-11-01T00:00:00.000000 N: 2

SELECT id FROM orders WHERE created_at >= DATE_TRUNC('month', TIMESTAMP '2026-11-20 08:00:00') ORDER BY id;
-- ID: 2
-- ID: 3

-- # It's deterministic, so it can be in a CHECK constraint.
CREATE TABLE months (m DATE CHECK (m = DATE_TRUNC('month', m)));
INSERT INTO months VALUES (DATE '2026-11-01');
SELECT COUNT(*) AS n FROM months WHERE m = DATE_TRUNC('month', DATE '2026-11-17');
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- N: 1

-- # The flagger reports it (see docs/sql-flagging.rst). F641 and F661 are for
-- # VALUES.
/* flags */
VALUES DATE_TRUNC('month', DATE '2026-11-17');
-- flags: F641, F661, V402-20
-- COL1: 2026-11-01
