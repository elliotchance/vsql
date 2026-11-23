-- # SET TIME ZONE LOCAL sets the time zone of the session back to the one it
-- # started with (19.4, General Rules, 1.a), which is the time zone of the
-- # clock (+05:00 in the tests).
SET TIME ZONE LOCAL;
VALUES CURRENT_TIME;
VALUES TIMESTAMP '2022-07-04 12:00:00+00:00' AT LOCAL;
-- msg: SET TIME ZONE
-- COL1: 14:05:03+0500
-- COL1: 2022-07-04T17:00:00+0500

/* clock -05:00 */
SET TIME ZONE LOCAL;
VALUES CURRENT_TIME;
-- msg: SET TIME ZONE
-- COL1: 04:05:03-0500

-- # SET TIME ZONE with an INTERVAL HOUR TO MINUTE sets the time zone of the
-- # session (19.4, Syntax Rules, 1, and General Rules, 1.b.i). LOCAL sets it
-- # back.
SET TIME ZONE INTERVAL '-03:30' HOUR TO MINUTE;
VALUES CURRENT_TIME;
VALUES TIMESTAMP '2022-07-04 12:00:00+00:00' AT LOCAL;
SET TIME ZONE INTERVAL '1:00' HOUR TO MINUTE + INTERVAL '30' MINUTE;
VALUES CURRENT_TIME;
SET TIME ZONE LOCAL;
VALUES CURRENT_TIME;
-- msg: SET TIME ZONE
-- COL1: 05:35:03-0330
-- COL1: 2022-07-04T08:30:00-0330
-- msg: SET TIME ZONE
-- COL1: 10:35:03+0130
-- msg: SET TIME ZONE
-- COL1: 14:05:03+0500

-- # It's 22009 (invalid time zone displacement value) if it's NULL or out of
-- # range (19.4, General Rules, 1.b.ii), and it must be an INTERVAL HOUR TO
-- # MINUTE.
SET TIME ZONE INTERVAL '15:00' HOUR TO MINUTE;
SET TIME ZONE INTERVAL '-14:01' HOUR TO MINUTE;
SET TIME ZONE CAST(NULL AS INTERVAL HOUR TO MINUTE);
SET TIME ZONE INTERVAL '1' HOUR;
SET TIME ZONE '+01:00';
SET TIME ZONE;
EXPLAIN SET TIME ZONE LOCAL;
-- error 22009: invalid time zone displacement value
-- error 22009: invalid time zone displacement value
-- error 22009: invalid time zone displacement value
-- error 42804: data type mismatch in SET TIME ZONE: expected INTERVAL HOUR TO MINUTE but got INTERVAL HOUR(2)
-- error 42804: data type mismatch in SET TIME ZONE: expected INTERVAL HOUR TO MINUTE but got CHARACTER(6)
-- error 42601: syntax error: unexpected $end at line 1, column 14 near "SET TIME ZONE"
-- error 42601: syntax error: Cannot EXPLAIN SET TIME ZONE

-- # A dynamic parameter is an INTERVAL HOUR TO MINUTE.
/* types */
/* params '2:00' */
SET TIME ZONE ?;
VALUES CURRENT_TIME;
-- sql: SET TIME ZONE '2:00'
-- msg: SET TIME ZONE
-- COL1: 11:05:03+0200 (TIME(0) WITH TIME ZONE)

-- # It doesn't start a transaction or use up a SET TRANSACTION, and it can be used
-- # in one.
CREATE TABLE t (x INT);
SET TRANSACTION READ ONLY;
SET TIME ZONE LOCAL;
INSERT INTO t (x) VALUES (1);
START TRANSACTION;
SET TIME ZONE LOCAL;
ROLLBACK;
-- msg: CREATE TABLE 1
-- msg: SET TRANSACTION
-- msg: SET TIME ZONE
-- error 25006: read-only sql transaction: cannot execute INSERT
-- msg: START TRANSACTION
-- msg: SET TIME ZONE
-- msg: ROLLBACK

-- # SET TIME ZONE needs F411 (19.4, Conformance Rules, 1).
/* flags */
SET TIME ZONE LOCAL;
-- flags: F411
-- msg: SET TIME ZONE
