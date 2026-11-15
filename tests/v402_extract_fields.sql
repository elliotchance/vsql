-- # EXTRACT has fields that aren't in the standard (V402-02 to V402-08), which
-- # PostgreSQL also has. They're for a DATE or TIMESTAMP, and they're INTEGERs,
-- # except for EPOCH.

-- # DOW is the day of the week from 0 (Sunday) to 6 (Saturday), and ISODOW is
-- # from 1 (Monday) to 7 (Sunday). 2026-11-15 is a Sunday.
/* types */
/* extensions V402-02 V402-03 */
VALUES ROW(EXTRACT(DOW FROM DATE '2026-11-15'), EXTRACT(ISODOW FROM DATE '2026-11-15'));
-- COL1: 0 (INTEGER) COL2: 7 (INTEGER)

/* extensions V402-02 V402-03 */
VALUES ROW(EXTRACT(DOW FROM DATE '2027-01-01'), EXTRACT(ISODOW FROM TIMESTAMP '0001-01-01 12:00:00'));
-- COL1: 5 COL2: 1

-- # The fields aren't keywords, so they can be in any case.
/* extensions V402-02 */
values extract(dow from date '2026-11-16');
-- COL1: 1

-- # DOY is the day of the year, which is 366 at the end of a leap year.
/* types */
/* extensions V402-04 */
VALUES ROW(EXTRACT(DOY FROM DATE '2026-11-15'), EXTRACT(DOY FROM DATE '2024-12-31'), EXTRACT(DOY FROM DATE '2027-01-01'));
-- COL1: 319 (INTEGER) COL2: 366 (INTEGER) COL3: 1 (INTEGER)

-- # WEEK is the ISO 8601 week, and ISOYEAR is the year that the week is in.
-- # The first days of January can be in the last week of the year before, and
-- # the last days of December in the first week of the year after.
/* types */
/* extensions V402-05 V402-06 */
VALUES ROW(EXTRACT(WEEK FROM DATE '2026-11-15'), EXTRACT(ISOYEAR FROM DATE '2026-11-15'));
-- COL1: 46 (INTEGER) COL2: 2026 (INTEGER)

/* extensions V402-05 V402-06 */
VALUES ROW(EXTRACT(WEEK FROM DATE '2027-01-01'), EXTRACT(ISOYEAR FROM DATE '2027-01-01'), EXTRACT(YEAR FROM DATE '2027-01-01'));
-- COL1: 53 COL2: 2026 COL3: 2027

/* extensions V402-05 V402-06 */
VALUES ROW(EXTRACT(WEEK FROM TIMESTAMP '2024-12-30 23:00:00'), EXTRACT(ISOYEAR FROM TIMESTAMP '2024-12-30 23:00:00'));
-- COL1: 1 COL2: 2025

-- # QUARTER is from 1 to 4.
/* types */
/* extensions V402-07 */
VALUES ROW(EXTRACT(QUARTER FROM DATE '2026-03-31'), EXTRACT(QUARTER FROM DATE '2026-11-15'));
-- COL1: 1 (INTEGER) COL2: 4 (INTEGER)

-- # The fields are of the local date, not UTC, like the standard ones.
/* extensions V402-02 */
VALUES EXTRACT(DOW FROM TIMESTAMP '2026-11-15 23:30:00-05:00');
-- COL1: 0

-- # EPOCH is the seconds since 1970-01-01 00:00:00 UTC, as a NUMERIC that keeps
-- # the fraction of a second. A DATE or TIMESTAMP without a time zone is taken
-- # to be UTC.
/* types */
/* extensions V402-08 */
VALUES ROW(EXTRACT(EPOCH FROM DATE '1970-01-02'), EXTRACT(EPOCH FROM TIMESTAMP '2026-11-15 12:00:00.25+05:00'));
-- COL1: 86400 (NUMERIC(12)) COL2: 1794726000.25 (NUMERIC(14, 2))

/* extensions V402-08 */
VALUES ROW(EXTRACT(EPOCH FROM TIMESTAMP '1969-12-31 23:59:59.75'), EXTRACT(EPOCH FROM DATE '0001-01-01'));
-- COL1: -0.25 COL2: -62135596800

-- # A TIME has no date, so it has none of the fields.
/* extensions V402-02 */
VALUES EXTRACT(DOW FROM TIME '12:00:00');
-- error 42804: data type mismatch in EXTRACT(DOW FROM ...): expected DATE or TIMESTAMP but got TIME(0) WITHOUT TIME ZONE

/* extensions V402-08 */
VALUES EXTRACT(EPOCH FROM TIME '12:00:00');
-- error 42804: data type mismatch in EXTRACT(EPOCH FROM ...): expected DATE or TIMESTAMP but got TIME(0) WITHOUT TIME ZONE

-- # A field that isn't a field is an error when the statement is compiled. A
-- # delimited identifier isn't a field.
VALUES EXTRACT(FORTNIGHT FROM DATE '2026-11-15');
-- error 42601: syntax error: EXTRACT has no field FORTNIGHT

VALUES EXTRACT("DOW" FROM DATE '2026-11-15');
-- error 42601: syntax error: EXTRACT has no field "DOW"

-- # EXTRACT of a NULL is NULL.
/* types */
/* extensions V402-08 */
VALUES EXTRACT(EPOCH FROM CAST(NULL AS DATE));
-- COL1: NULL (NUMERIC(12))

-- # The flagger reports each field (see docs/sql-flagging.rst). F641 and F661
-- # are for VALUES.
/* flags */
/* extensions V402-05 */
VALUES EXTRACT(WEEK FROM DATE '2026-11-15');
-- flags: F052, F641, F661, V402-05
-- COL1: 46
