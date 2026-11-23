/* define bookings */
CREATE TABLE bookings (id INT, starts DATE, ends DATE);
INSERT INTO bookings (id, starts, ends) VALUES (1, DATE '2020-01-01', DATE '2020-01-05');
INSERT INTO bookings (id, starts, ends) VALUES (2, DATE '2020-01-05', DATE '2020-01-10');
INSERT INTO bookings (id, starts, ends) VALUES (3, DATE '2020-01-08', NULL);
INSERT INTO bookings (id, starts, ends) VALUES (4, NULL, NULL);

-- # Two periods overlap when they share any instant. A period includes its
-- # start but not its end (General Rules, 7), so periods that only touch don't
-- # overlap.
VALUES (DATE '2020-01-01', DATE '2020-01-10') OVERLAPS (DATE '2020-01-05', DATE '2020-01-20');
VALUES (DATE '2020-01-05', DATE '2020-01-20') OVERLAPS (DATE '2020-01-01', DATE '2020-01-10');
VALUES (DATE '2020-01-01', DATE '2020-01-31') OVERLAPS (DATE '2020-01-10', DATE '2020-01-20');
VALUES (DATE '2020-01-01', DATE '2020-01-10') OVERLAPS (DATE '2020-01-10', DATE '2020-01-20');
VALUES (DATE '2020-01-10', DATE '2020-01-20') OVERLAPS (DATE '2020-01-01', DATE '2020-01-10');
VALUES (DATE '2020-01-01', DATE '2020-01-05') OVERLAPS (DATE '2020-01-10', DATE '2020-01-20');
VALUES (DATE '2020-01-10', DATE '2020-01-20') OVERLAPS (DATE '2020-01-01', DATE '2020-01-05');
-- COL1: TRUE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: FALSE
-- COL1: FALSE
-- COL1: FALSE
-- COL1: FALSE

-- # The same periods.
VALUES (DATE '2020-01-01', DATE '2020-01-10') OVERLAPS (DATE '2020-01-01', DATE '2020-01-10');
-- COL1: TRUE

-- # A period whose end is before its start is swapped (General Rules, 4 and 6).
VALUES (DATE '2020-01-10', DATE '2020-01-01') OVERLAPS (DATE '2020-01-20', DATE '2020-01-05');
VALUES (DATE '2020-01-10', DATE '2020-01-01') OVERLAPS (DATE '2020-01-20', DATE '2020-01-10');
-- COL1: TRUE
-- COL1: FALSE

-- # A period of a single instant overlaps a period that starts at the same
-- # instant, but not one that ends at it.
VALUES (DATE '2020-01-10', DATE '2020-01-10') OVERLAPS (DATE '2020-01-10', DATE '2020-01-20');
VALUES (DATE '2020-01-10', DATE '2020-01-20') OVERLAPS (DATE '2020-01-10', DATE '2020-01-10');
VALUES (DATE '2020-01-10', DATE '2020-01-10') OVERLAPS (DATE '2020-01-01', DATE '2020-01-10');
VALUES (DATE '2020-01-10', DATE '2020-01-10') OVERLAPS (DATE '2020-01-01', DATE '2020-01-20');
VALUES (DATE '2020-01-10', DATE '2020-01-10') OVERLAPS (DATE '2020-01-10', DATE '2020-01-10');
-- COL1: TRUE
-- COL1: TRUE
-- COL1: FALSE
-- COL1: TRUE
-- COL1: TRUE

-- # A row of NULLs is the null value, so the result is UNKNOWN (General Rules,
-- # 1).
VALUES (CAST(NULL AS DATE), CAST(NULL AS DATE)) OVERLAPS (DATE '2020-01-01', DATE '2020-01-10');
VALUES (DATE '2020-01-01', DATE '2020-01-10') OVERLAPS (CAST(NULL AS DATE), CAST(NULL AS DATE));
-- COL1: UNKNOWN
-- COL1: UNKNOWN

-- # With one NULL, the other value is the start and the end is unknown
-- # (General Rules, 4 and 6). That can still be enough to know they overlap,
-- # but not when both start at the same time, since "T1 <> T2 OR T1 = T2" is
-- # UNKNOWN when an end is unknown.
VALUES (CAST(NULL AS DATE), DATE '2020-01-05') OVERLAPS (DATE '2020-01-01', DATE '2020-01-10');
VALUES (DATE '2020-01-05', CAST(NULL AS DATE)) OVERLAPS (DATE '2020-01-01', DATE '2020-01-10');
VALUES (DATE '2020-01-01', DATE '2020-01-10') OVERLAPS (DATE '2020-01-05', CAST(NULL AS DATE));
VALUES (DATE '2020-01-05', CAST(NULL AS DATE)) OVERLAPS (DATE '2020-01-05', DATE '2020-01-10');
VALUES (DATE '2020-01-05', CAST(NULL AS DATE)) OVERLAPS (DATE '2020-01-06', DATE '2020-01-10');
VALUES (DATE '2020-01-05', CAST(NULL AS DATE)) OVERLAPS (DATE '2020-01-01', DATE '2020-01-02');
VALUES (DATE '2020-01-05', CAST(NULL AS DATE)) OVERLAPS (CAST(NULL AS DATE), DATE '2020-01-05');
VALUES (DATE '2020-01-05', CAST(NULL AS DATE)) OVERLAPS (CAST(NULL AS DATE), DATE '2020-01-06');
-- COL1: TRUE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: UNKNOWN
-- COL1: UNKNOWN
-- COL1: UNKNOWN
-- COL1: UNKNOWN
-- COL1: UNKNOWN

-- # TIME and TIMESTAMP, with and without a time zone.
VALUES (TIME '10:00:00', TIME '12:00:00') OVERLAPS (TIME '11:00:00', TIME '13:00:00');
VALUES (TIME '10:00:00', TIME '12:00:00') OVERLAPS (TIME '12:00:00', TIME '13:00:00');
VALUES (TIME '10:00:00+05:00', TIME '12:00:00+05:00') OVERLAPS (TIME '07:00:00+02:00', TIME '08:00:00+02:00');
VALUES (TIMESTAMP '2020-01-01 10:00:00', TIMESTAMP '2020-01-01 12:00:00') OVERLAPS (TIMESTAMP '2020-01-01 11:59:59.999999', TIMESTAMP '2020-01-02 00:00:00');
VALUES (TIMESTAMP '2020-01-01 10:00:00+00:00', TIMESTAMP '2020-01-01 12:00:00+00:00') OVERLAPS (TIMESTAMP '2020-01-01 14:00:00+02:00', TIMESTAMP '2020-01-01 16:00:00+02:00');
-- COL1: TRUE
-- COL1: FALSE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: FALSE

-- # Columns, in a WHERE.
/* include bookings */
SELECT id FROM bookings WHERE (starts, ends) OVERLAPS (DATE '2020-01-04', DATE '2020-01-06');
SELECT id FROM bookings WHERE NOT (starts, ends) OVERLAPS (DATE '2020-01-09', DATE '2020-01-12');
SELECT id, (starts, ends) OVERLAPS (DATE '2020-01-09', DATE '2020-01-12') AS o FROM bookings;
-- ID: 1
-- ID: 2
-- ID: 1
-- ID: 1 O: FALSE
-- ID: 2 O: TRUE
-- ID: 3 O: UNKNOWN
-- ID: 4 O: UNKNOWN

/* include bookings */
/* extensions V001-01 */
EXPLAIN SELECT id FROM bookings WHERE (starts, ends) OVERLAPS (DATE '2020-01-04', ends);
-- EXPLAIN: TABLE ":memory:".PUBLIC.BOOKINGS (ID INTEGER, STARTS DATE, ENDS DATE)
-- EXPLAIN: WHERE ROW(STARTS, ENDS) OVERLAPS ROW(DATE '2020-01-04', ENDS)
-- EXPLAIN: EXPR (ID INTEGER)

-- # OVERLAPS isn't Core SQL, it's Feature F053 (Conformance Rules, 1). The
-- # rows are F641.
/* include bookings */
/* flags */
SELECT id FROM bookings WHERE (starts, ends) OVERLAPS (DATE '2020-01-04', DATE '2020-01-06');
-- flags: F053, F641
-- ID: 1
-- ID: 2

-- # Each period must be a row of degree 2 (Syntax Rules, 1).
VALUES DATE '2020-01-01' OVERLAPS (DATE '2020-01-01', DATE '2020-01-10');
VALUES (DATE '2020-01-01', DATE '2020-01-10') OVERLAPS (DATE '2020-01-01', DATE '2020-01-10', DATE '2020-01-20');
-- error 42601: syntax error: OVERLAPS needs a row of degree 2, not 1
-- error 42601: syntax error: OVERLAPS needs a row of degree 2, not 3

-- # Every value must be a datetime (Syntax Rules, 2 and 3), except that the
-- # second field can be an INTERVAL.
VALUES (1, 2) OVERLAPS (3, 4);
VALUES (DATE '2020-01-01', 'a') OVERLAPS (DATE '2020-01-01', DATE '2020-01-10');
VALUES (INTERVAL '1' DAY, DATE '2020-01-01') OVERLAPS (DATE '2020-01-01', DATE '2020-01-10');
-- error 42804: data type mismatch in OVERLAPS: expected DATE, TIME or TIMESTAMP but got SMALLINT
-- error 42804: data type mismatch in OVERLAPS: expected DATE, TIME, TIMESTAMP or INTERVAL but got CHARACTER(1)
-- error 42804: data type mismatch in OVERLAPS: expected DATE, TIME or TIMESTAMP but got INTERVAL DAY(2)

-- # A period can be a start and an interval, which ends at the start plus the
-- # interval (Syntax Rules, 3.a, and General Rules, 3.b and 5.b). It's NULL if
-- # the start or the interval is NULL, so the result is unknown if the other
-- # period starts at the same time.
VALUES (DATE '2020-01-01', INTERVAL '10' DAY) OVERLAPS (DATE '2020-01-05', DATE '2020-02-01');
VALUES (DATE '2020-01-01', INTERVAL '4' DAY) OVERLAPS (DATE '2020-01-05', DATE '2020-02-01');
VALUES (DATE '2020-01-10', INTERVAL '-9' DAY) OVERLAPS (DATE '2020-01-05', INTERVAL '1' MONTH);
VALUES (TIME '10:00:00', INTERVAL '30' MINUTE) OVERLAPS (TIME '10:15:00', TIME '11:00:00');
VALUES (DATE '2020-01-01', CAST(NULL AS INTERVAL DAY)) OVERLAPS (DATE '2020-01-01', DATE '2020-01-10');
VALUES (CAST(NULL AS DATE), INTERVAL '1' DAY) OVERLAPS (DATE '2020-01-01', DATE '2020-01-10');
-- COL1: TRUE
-- COL1: FALSE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: UNKNOWN
-- COL1: UNKNOWN

-- # The interval must be one that can be added to the start.
VALUES (DATE '2020-01-01', INTERVAL '1' HOUR) OVERLAPS (DATE '2020-01-05', DATE '2020-02-01');
-- error 42804: data type mismatch in OVERLAPS: expected an interval that can be added to DATE but got INTERVAL HOUR(2)

-- # And they must be comparable.
VALUES (DATE '2020-01-01', DATE '2020-01-10') OVERLAPS (TIMESTAMP '2020-01-01 00:00:00', TIMESTAMP '2020-01-10 00:00:00');
VALUES (DATE '2020-01-01', TIME '10:00:00') OVERLAPS (DATE '2020-01-01', DATE '2020-01-10');
VALUES (DATE '2020-01-01', DATE '2020-01-10') OVERLAPS (DATE '2020-01-01', TIME '10:00:00');
-- error 42883: cannot compare DATE and TIMESTAMP(0) WITHOUT TIME ZONE
-- error 42883: cannot compare DATE and TIME(0) WITHOUT TIME ZONE
-- error 42883: cannot compare DATE and TIME(0) WITHOUT TIME ZONE

-- # A dynamic parameter has the type of the field in the same position of the
-- # other row.
/* include bookings */
/* params '2020-01-04' '2020-01-06' */
SELECT id FROM bookings WHERE (?, ?) OVERLAPS (starts, ends);
-- sql: SELECT id FROM bookings WHERE ('2020-01-04', '2020-01-06') OVERLAPS (starts, ends)
-- ID: 1
-- ID: 2
