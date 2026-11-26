-- # LAST_DAY(source) (V402-22) is the last day of the month of a DATE or
-- # TIMESTAMP, as a DATE.

/* types */
VALUES ROW(LAST_DAY(DATE '2024-02-10'), LAST_DAY(DATE '2023-02-10'), LAST_DAY(DATE '2024-04-30'), LAST_DAY(DATE '2024-12-01'));
-- COL1: 2024-02-29 (DATE) COL2: 2023-02-28 (DATE) COL3: 2024-04-30 (DATE) COL4: 2024-12-31 (DATE)

-- # A TIMESTAMP of any precision, and a century that isn't a leap year.
/* types */
VALUES ROW(LAST_DAY(TIMESTAMP '1900-02-03 23:59:59.999999'), LAST_DAY(CAST(TIMESTAMP '2000-02-03 10:00:00' AS TIMESTAMP(0))), LAST_DAY(TIMESTAMP '9999-12-31 12:00:00'), LAST_DAY(DATE '0001-01-01'));
-- COL1: 1900-02-28 (DATE) COL2: 2000-02-29 (DATE) COL3: 9999-12-31 (DATE) COL4: 0001-01-31 (DATE)

-- # A value WITH TIME ZONE uses the date in its own time zone.
VALUES ROW(LAST_DAY(TIMESTAMP '2024-06-30 23:30:00+10:00'), LAST_DAY(TIMESTAMP '2024-07-01 00:30:00-05:00'));
-- COL1: 2024-06-30 COL2: 2024-07-31

-- # A number of months after, and the month before (see the docs).
VALUES ROW(LAST_DAY(DATE_TRUNC('month', DATE '2024-01-31') + 1 * INTERVAL '1' MONTH), LAST_DAY(DATE_TRUNC('month', DATE '2026-01-31') + INTERVAL '1' MONTH), DATE_TRUNC('month', DATE '2026-11-17') - INTERVAL '1' DAY);
-- COL1: 2024-02-29 COL2: 2026-02-28 COL3: 2026-10-31

-- # NULL is NULL.
/* types */
VALUES LAST_DAY(CAST(NULL AS DATE));
-- COL1: NULL (DATE)

-- # Only a DATE or TIMESTAMP.
VALUES LAST_DAY(TIME '10:00:00');
VALUES LAST_DAY('2024-02-10');
VALUES LAST_DAY(1);
VALUES LAST_DAY();
VALUES LAST_DAY(DATE '2024-02-10', DATE '2024-02-10');
-- error 42883: function does not exist: LAST_DAY(TIME(0) WITHOUT TIME ZONE)
-- error 42883: function does not exist: LAST_DAY(CHARACTER(10))
-- error 42883: function does not exist: LAST_DAY(INTEGER)
-- error 42883: function does not exist: LAST_DAY()
-- error 42883: function does not exist: LAST_DAY(DATE, DATE)

-- # Columns, and it's deterministic, so it can be in a CHECK.
CREATE TABLE bills (due DATE CHECK (due = LAST_DAY(due)), paid TIMESTAMP);
INSERT INTO bills VALUES (DATE '2024-02-29', TIMESTAMP '2024-02-01 09:00:00');
INSERT INTO bills VALUES (DATE '2024-02-28', NULL);
SELECT due, LAST_DAY(paid) AS l FROM bills WHERE LAST_DAY(paid) = due;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 23514: violates check constraint: CHECK (DUE = LAST_DAY(DUE)) on ":memory:".PUBLIC.BILLS
-- DUE: 2024-02-29 L: 2024-02-29

-- # The flagger reports it (see docs/sql-flagging.rst). F641 and F661 are for
-- # VALUES.
/* flags */
VALUES LAST_DAY(DATE '2024-02-10');
-- flags: F641, F661, V402-22
-- COL1: 2024-02-29
