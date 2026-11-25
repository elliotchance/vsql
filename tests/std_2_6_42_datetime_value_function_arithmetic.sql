-- # The clock of the tests is 09:05:03.120056 UTC on 2022-07-04, in +05:00
-- # (see the "clock" directive in docs/testing.rst), which is the time zone of
-- # the session.
--
/* setup */
CREATE TABLE t (d DATE, ts TIMESTAMP(0));
INSERT INTO t VALUES (DATE '2022-06-30', TIMESTAMP '2022-07-04 12:00:00');

-- # A <datetime value function> is a <datetime primary>, so it can be an
-- # operand of datetime arithmetic without parentheses (6.42, Format, and 6.44,
-- # Format), on either side of the operator. An INTERVAL SECOND has a
-- # fractional seconds precision of 6, so the TIME it's added to has one too
-- # (6.42, Syntax Rules, 5.b).
/* types */
VALUES CURRENT_DATE + INTERVAL '1' DAY;
VALUES INTERVAL '1' DAY + CURRENT_DATE;
VALUES CURRENT_DATE - INTERVAL '1' MONTH;
VALUES LOCALTIME(0) + INTERVAL '1' HOUR;
VALUES LOCALTIMESTAMP(0) - INTERVAL '30' MINUTE;
VALUES CURRENT_TIME(0) + INTERVAL '10' SECOND;
VALUES CURRENT_TIMESTAMP(0) + INTERVAL '1' DAY;
-- COL1: 2022-07-05 (DATE)
-- COL1: 2022-07-05 (DATE)
-- COL1: 2022-06-04 (DATE)
-- COL1: 15:05:03 (TIME(0) WITHOUT TIME ZONE)
-- COL1: 2022-07-04T13:35:03 (TIMESTAMP(0) WITHOUT TIME ZONE)
-- COL1: 14:05:13.000000+0500 (TIME(6) WITH TIME ZONE)
-- COL1: 2022-07-05T14:05:03+0500 (TIMESTAMP(0) WITH TIME ZONE)

-- # More than one operator, and in a comparison.
VALUES CURRENT_DATE + INTERVAL '1' DAY - INTERVAL '1' DAY = CURRENT_DATE;
VALUES CURRENT_DATE - INTERVAL '1' DAY < CURRENT_DATE;
-- COL1: TRUE
-- COL1: TRUE

-- # The difference of two datetimes, with a datetime value function as either
-- # operand.
/* types */
SELECT (CURRENT_DATE - d) DAY FROM t;
SELECT (d - CURRENT_DATE) DAY FROM t;
SELECT (LOCALTIMESTAMP(0) - ts) HOUR TO MINUTE FROM t;
SELECT d FROM t WHERE d < CURRENT_DATE - INTERVAL '1' DAY;
-- COL1: 4 (INTERVAL DAY(2))
-- COL1: -4 (INTERVAL DAY(2))
-- COL1: 2:05 (INTERVAL HOUR(2) TO MINUTE)
-- D: 2022-06-30 (DATE)

-- # The operand can have a time zone.
/* types */
VALUES LOCALTIMESTAMP(0) AT TIME ZONE INTERVAL '+02:00' HOUR TO MINUTE + INTERVAL '1' HOUR;
VALUES TIMESTAMP '2022-07-04 12:00:00' AT LOCAL - INTERVAL '1' DAY;
-- COL1: 2022-07-04T12:05:03+0200 (TIMESTAMP(0) WITH TIME ZONE)
-- COL1: 2022-07-03T12:00:00+0500 (TIMESTAMP(0) WITH TIME ZONE)

-- # It's still an error when the types don't fit an operator.
VALUES CURRENT_DATE * 2;
VALUES CURRENT_DATE + 1;
VALUES -CURRENT_DATE;
-- error 42883: operator does not exist: DATE * INTEGER
-- error 42883: operator does not exist: DATE + INTEGER
-- error 42883: operator does not exist: - DATE
