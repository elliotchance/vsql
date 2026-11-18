-- # SET TIME ZONE LOCAL sets the time zone of the session back to the one it
-- # started with (19.4, General Rules, 1.a), which is the time zone of the
-- # clock (+05:00 in the tests). It's the only one there is for now, since a
-- # time zone displacement is an interval.
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

SET TIME ZONE INTERVAL '+01:00' HOUR TO MINUTE;
SET TIME ZONE '+01:00';
SET TIME ZONE;
EXPLAIN SET TIME ZONE LOCAL;
-- error 42601: syntax error: unexpected INTERVAL at line 1, column 15 near "SET TIME ZONE INTERVAL '+01:00'", expecting LOCAL
-- error 42601: syntax error: unexpected string at line 1, column 15 near "SET TIME ZONE '+01:00'", expecting LOCAL
-- error 42601: syntax error: unexpected $end at line 1, column 14 near "SET TIME ZONE", expecting LOCAL
-- error 42601: syntax error: Cannot EXPLAIN SET TIME ZONE

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
