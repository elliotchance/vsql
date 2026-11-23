-- # AT TIME ZONE moves a datetime into the time zone of an INTERVAL HOUR TO
-- # MINUTE (6.42, General Rules, 5.b.ii.2.B and 5.b.iii). A datetime with a
-- # time zone keeps its UTC component, and one without a time zone is in the
-- # time zone of the session (+05:00 in the tests) (6.42, General Rules,
-- # 5.b.i.1 and 5.b.i.2). The result has a time zone, with the same precision
-- # (6.42, Syntax Rules, 4.a).
/* types */
VALUES TIMESTAMP '2022-07-04 12:00:00+00:00' AT TIME ZONE INTERVAL '05:30' HOUR TO MINUTE;
VALUES TIMESTAMP '2022-07-04 12:00:00.5' AT TIME ZONE INTERVAL '-03:00' HOUR TO MINUTE;
VALUES TIME '01:00:00+01:00' AT TIME ZONE INTERVAL '-2:00' HOUR TO MINUTE;
VALUES TIME '23:00:00' AT TIME ZONE (-INTERVAL '0:30' HOUR TO MINUTE);
-- COL1: 2022-07-04T17:30:00+0530 (TIMESTAMP(0) WITH TIME ZONE)
-- COL1: 2022-07-04T04:00:00.5-0300 (TIMESTAMP(1) WITH TIME ZONE)
-- COL1: 22:00:00-0200 (TIME(0) WITH TIME ZONE)
-- COL1: 17:30:00-0030 (TIME(0) WITH TIME ZONE)

-- # It's NULL if the datetime or the time zone is NULL (6.42, General Rules,
-- # 2), and 22009 (invalid time zone displacement value) if the time zone is
-- # out of range (6.42, General Rules, 5.b.ii.2.A).
VALUES CAST(NULL AS TIMESTAMP) AT TIME ZONE INTERVAL '1:00' HOUR TO MINUTE;
VALUES TIMESTAMP '2022-07-04 12:00:00' AT TIME ZONE CAST(NULL AS INTERVAL HOUR TO MINUTE);
VALUES TIMESTAMP '2022-07-04 12:00:00' AT TIME ZONE INTERVAL '14:01' HOUR TO MINUTE;
-- COL1: NULL
-- COL1: NULL
-- error 22009: invalid time zone displacement value

-- # The time zone must be an INTERVAL HOUR TO MINUTE (6.42, Syntax Rules, 6),
-- # and the datetime can't be a DATE (6.42, Syntax Rules, 3).
VALUES TIMESTAMP '2022-07-04 12:00:00' AT TIME ZONE '+01:00';
VALUES TIMESTAMP '2022-07-04 12:00:00' AT TIME ZONE INTERVAL '1' HOUR;
VALUES DATE '2022-07-04' AT TIME ZONE INTERVAL '1:00' HOUR TO MINUTE;
-- error 42804: data type mismatch in TIMESTAMP '2022-07-04 12:00:00' AT TIME ZONE '+01:00': expected INTERVAL HOUR TO MINUTE but got CHARACTER(6)
-- error 42804: data type mismatch in TIMESTAMP '2022-07-04 12:00:00' AT TIME ZONE INTERVAL '1' HOUR(2): expected INTERVAL HOUR TO MINUTE but got INTERVAL HOUR(2)
-- error 42804: data type mismatch in DATE '2022-07-04' AT TIME ZONE INTERVAL '1:00' HOUR(2) TO MINUTE: expected TIME or TIMESTAMP but got DATE

-- # A dynamic parameter is an INTERVAL HOUR TO MINUTE, and so is one with an
-- # interval qualifier.
/* types */
/* params '1:00' '2:00' */
VALUES (TIMESTAMP '2022-07-04 12:00:00+00:00' AT TIME ZONE ?, TIMESTAMP '2022-07-04 12:00:00+00:00' AT TIME ZONE ? HOUR TO MINUTE);
-- sql: VALUES (TIMESTAMP '2022-07-04 12:00:00+00:00' AT TIME ZONE '1:00', TIMESTAMP '2022-07-04 12:00:00+00:00' AT TIME ZONE '2:00' HOUR TO MINUTE)
-- COL1: 2022-07-04T13:00:00+0100 (TIMESTAMP(0) WITH TIME ZONE) COL2: 2022-07-04T14:00:00+0200 (TIMESTAMP(0) WITH TIME ZONE)

-- # A datetime without a time zone is in the time zone of the session, which can
-- # change, but one with a time zone isn't.
CREATE TABLE t (x TIMESTAMP CHECK (x AT TIME ZONE INTERVAL '1:00' HOUR TO MINUTE IS NOT NULL));
CREATE TABLE t2 (x TIMESTAMP WITH TIME ZONE CHECK (x AT TIME ZONE INTERVAL '1:00' HOUR TO MINUTE IS NOT NULL));
-- error 42601: syntax error: X AT TIME ZONE INTERVAL '1:00' HOUR(2) TO MINUTE cannot be used in a CHECK constraint
-- msg: CREATE TABLE 1

-- # A <time zone> needs F411 (6.42, Conformance Rules, 2), and the interval
-- # needs F052.
/* flags */
VALUES TIMESTAMP '2022-07-04 12:00:00' AT TIME ZONE INTERVAL '1:00' HOUR TO MINUTE;
-- flags: F052, F411, F641, F661
-- COL1: 2022-07-04T08:00:00+0100
