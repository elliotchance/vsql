-- # The difference of two datetimes without an interval qualifier is a vsql
-- # extension (V305-01 to V305-03). It's the same as "(a - b) IQ" with an implied
-- # qualifier: DAY for two DATEs, HOUR TO SECOND for two TIMEs and DAY TO
-- # SECOND for two TIMESTAMPs (see std_2_6_44_interval_value_expression.sql for
-- # the standard form).

/* types */
VALUES DATE '2026-11-17' - DATE '2026-01-01';
VALUES TIME '08:00:00' - TIME '09:15:30';
VALUES TIMESTAMP '2026-11-17 14:30:00' - TIMESTAMP '2026-11-16 12:00:00';
-- COL1: 320 (INTERVAL DAY(8))
-- COL1: -1:15:30 (INTERVAL HOUR(2) TO SECOND(0))
-- COL1: 1 02:30:00 (INTERVAL DAY(8) TO SECOND(0))

-- # The fractional seconds precision is the larger of the two.
/* types */
VALUES TIME '08:00:00.5' - TIME '09:15:30.123';
VALUES TIMESTAMP '2026-11-17 14:30:00.12' - TIMESTAMP '2026-11-16 12:00:00';
VALUES TIMESTAMP '2026-11-17 14:30:00' - TIMESTAMP '2026-11-16 12:00:00.123456';
-- COL1: -1:15:29.623 (INTERVAL HOUR(2) TO SECOND(3))
-- COL1: 1 02:30:00.12 (INTERVAL DAY(8) TO SECOND(2))
-- COL1: 1 02:29:59.876544 (INTERVAL DAY(8) TO SECOND(6))

-- # Values with a time zone are subtracted in UTC, so the same instant with
-- # different offsets is a difference of zero.
/* types */
VALUES TIMESTAMP '2026-11-17 14:30:00+05:00' - TIMESTAMP '2026-11-17 09:30:00+00:00';
VALUES TIME '14:30:00+05:00' - TIME '09:30:00+00:00';
VALUES TIMESTAMP '2026-11-17 14:30:00+05:00' - TIMESTAMP '2026-11-17 14:30:00+00:00';
-- COL1: 0 00:00:00 (INTERVAL DAY(8) TO SECOND(0))
-- COL1: 0:00:00 (INTERVAL HOUR(2) TO SECOND(0))
-- COL1: -0 05:00:00 (INTERVAL DAY(8) TO SECOND(0))

-- # A difference of zero, and the largest differences.
/* types */
VALUES DATE '2026-11-17' - DATE '2026-11-17';
VALUES DATE '9999-12-31' - DATE '0001-01-01';
VALUES DATE '0001-01-01' - DATE '9999-12-31';
VALUES TIMESTAMP '9999-12-31 23:59:59.999999' - TIMESTAMP '0001-01-01 00:00:00';
VALUES TIME '23:59:59.999999' - TIME '00:00:00';
VALUES TIME '00:00:00' - TIME '23:59:59.999999';
-- COL1: 0 (INTERVAL DAY(8))
-- COL1: 3652058 (INTERVAL DAY(8))
-- COL1: -3652058 (INTERVAL DAY(8))
-- COL1: 3652058 23:59:59.999999 (INTERVAL DAY(8) TO SECOND(6))
-- COL1: 23:59:59.999999 (INTERVAL HOUR(2) TO SECOND(6))
-- COL1: -23:59:59.999999 (INTERVAL HOUR(2) TO SECOND(6))

-- # Leap days are counted, since it uses the real dates.
VALUES DATE '2028-03-01' - DATE '2028-02-28';
VALUES DATE '2027-03-01' - DATE '2027-02-28';
VALUES TIMESTAMP '2028-03-01 00:00:00' - TIMESTAMP '2028-02-28 12:00:00';
-- COL1: 2
-- COL1: 1
-- COL1: 1 12:00:00

-- # The result is an ordinary interval, so it can be cast, extracted from,
-- # compared and used in interval arithmetic.
/* types */
VALUES CAST(DATE '2026-11-17' - DATE '2026-01-01' AS INTEGER);
VALUES EXTRACT(HOUR FROM TIMESTAMP '2026-11-17 14:30:00' - TIMESTAMP '2026-11-16 12:00:00');
VALUES DATE '2026-11-17' - DATE '2026-01-01' > INTERVAL '300' DAY(3);
VALUES DATE '2026-11-17' - DATE '2026-01-01' + INTERVAL '1' DAY;
VALUES DATE '2026-01-01' + (DATE '2026-11-17' - DATE '2026-01-01');
VALUES (TIME '10:00:00' - TIME '08:30:00') * 2;
-- COL1: 320 (INTEGER)
-- COL1: 2 (INTEGER)
-- COL1: TRUE (BOOLEAN)
-- COL1: 321 (INTERVAL DAY(8))
-- COL1: 2026-11-17 (DATE)
-- COL1: 3:00:00 (INTERVAL HOUR(8) TO SECOND(0))

-- # A year-month interval is never implied, so it still needs the qualifier.
VALUES (DATE '2020-03-01' - DATE '2019-02-15') YEAR TO MONTH;
-- COL1: 1-01

-- # NULL is NULL.
/* types */
VALUES DATE '2026-11-17' - CAST(NULL AS DATE);
VALUES CAST(NULL AS TIME) - TIME '10:00:00';
VALUES TIMESTAMP '2026-11-17 14:30:00' - CAST(NULL AS TIMESTAMP(3));
-- COL1: NULL (INTERVAL DAY(8))
-- COL1: NULL (INTERVAL HOUR(2) TO SECOND(0))
-- COL1: NULL (INTERVAL DAY(8) TO SECOND(3))

-- # The datetimes must be comparable.
VALUES DATE '2026-11-17' - TIMESTAMP '2026-11-17 00:00:00';
VALUES TIME '10:00:00' - TIMESTAMP '2026-11-17 00:00:00';
-- error 42883: operator does not exist: DATE - TIMESTAMP(0) WITHOUT TIME ZONE
-- error 42883: operator does not exist: TIME(0) WITHOUT TIME ZONE - TIMESTAMP(0) WITHOUT TIME ZONE

-- # A dynamic parameter has the type of the other datetime.
/* types */
/* params '2026-11-17' */
VALUES ? - DATE '2026-01-01';
-- sql: VALUES '2026-11-17' - DATE '2026-01-01'
-- COL1: 320 (INTERVAL DAY(8))

-- # The flagger has a code for each type.
/* flags */
VALUES DATE '2026-11-17' - DATE '2026-01-01';
-- flags: F052, F641, F661, V305-01
-- COL1: 320

/* flags */
VALUES TIME '08:00:00' - TIME '09:15:30';
-- flags: F052, F641, F661, V305-02
-- COL1: -1:15:30

/* flags */
VALUES TIMESTAMP '2026-11-17 14:30:00' - TIMESTAMP '2026-11-16 12:00:00';
-- flags: F052, F641, F661, V305-03
-- COL1: 1 02:30:00
