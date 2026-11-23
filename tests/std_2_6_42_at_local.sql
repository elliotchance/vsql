-- # The clock of the tests is 09:05:03.120056 UTC on 2022-07-04, in +05:00
-- # (see the "clock" directive in docs/testing.rst), which is the time zone of
-- # the session.
--
-- # AT LOCAL moves a datetime with a time zone into the time zone of the
-- # session, keeping the same instant (6.42, General Rules, 5.b.i.1 and
-- # 5.b.ii.1). The type keeps its precision (6.42, Syntax Rules, 4.a).
/* types */
VALUES TIMESTAMP '2022-07-04 12:00:00+00:00' AT LOCAL;
VALUES TIMESTAMP '2022-07-04 12:00:00.123-03:30' AT LOCAL;
VALUES TIMESTAMP '2022-12-31 22:00:00+00:00' AT LOCAL;
VALUES TIMESTAMP '2022-07-04 12:00:00+05:00' AT LOCAL;
-- COL1: 2022-07-04T17:00:00+0500 (TIMESTAMP(0) WITH TIME ZONE)
-- COL1: 2022-07-04T20:30:00.123+0500 (TIMESTAMP(3) WITH TIME ZONE)
-- COL1: 2023-01-01T03:00:00+0500 (TIMESTAMP(0) WITH TIME ZONE)
-- COL1: 2022-07-04T12:00:00+0500 (TIMESTAMP(0) WITH TIME ZONE)

-- # A TIME wraps around midnight, since it has no date.
/* types */
VALUES TIME '12:00:00+00:00' AT LOCAL;
VALUES TIME '22:30:00.5-03:00' AT LOCAL;
VALUES TIME '02:00:00+09:00' AT LOCAL;
-- COL1: 17:00:00+0500 (TIME(0) WITH TIME ZONE)
-- COL1: 06:30:00.5+0500 (TIME(1) WITH TIME ZONE)
-- COL1: 22:00:00+0500 (TIME(0) WITH TIME ZONE)

-- # A datetime without a time zone is already in the time zone of the session,
-- # so it only gets that time zone (6.42, General Rules, 5.b.i.2).
/* types */
VALUES TIMESTAMP '2022-07-04 12:00:00' AT LOCAL;
VALUES TIME '10:00:00.25' AT LOCAL;
VALUES LOCALTIMESTAMP AT LOCAL;
VALUES LOCALTIME(3) AT LOCAL;
VALUES CURRENT_TIMESTAMP(0) AT LOCAL;
-- COL1: 2022-07-04T12:00:00+0500 (TIMESTAMP(0) WITH TIME ZONE)
-- COL1: 10:00:00.25+0500 (TIME(2) WITH TIME ZONE)
-- COL1: 2022-07-04T14:05:03.120056+0500 (TIMESTAMP(6) WITH TIME ZONE)
-- COL1: 14:05:03.120+0500 (TIME(3) WITH TIME ZONE)
-- COL1: 2022-07-04T14:05:03+0500 (TIMESTAMP(0) WITH TIME ZONE)

-- # The time zone of the session can be behind UTC.
/* clock -05:00 */
VALUES TIMESTAMP '2022-07-04 02:00:00+00:00' AT LOCAL;
VALUES TIME '02:00:00+00:00' AT LOCAL;
VALUES TIMESTAMP '2022-07-04 02:00:00' AT LOCAL;
-- COL1: 2022-07-03T21:00:00-0500
-- COL1: 21:00:00-0500
-- COL1: 2022-07-04T02:00:00-0500

-- # It's the same instant, so it's still equal to the original value.
VALUES TIMESTAMP '2022-07-04 12:00:00-08:00' AT LOCAL = TIMESTAMP '2022-07-04 12:00:00-08:00';
VALUES TIMESTAMP '2022-07-04 12:00:00' AT LOCAL = TIMESTAMP '2022-07-04 12:00:00+05:00';
VALUES (TIMESTAMP '2022-07-04 12:00:00-08:00' AT LOCAL) AT LOCAL;
-- COL1: TRUE
-- COL1: TRUE
-- COL1: 2022-07-05T01:00:00+0500

-- # It can follow any datetime value, such as a column or a parameter. The null
-- # value is still the null value.
/* types */
CREATE TABLE t (ts TIMESTAMP(2) WITH TIME ZONE, tm TIME);
INSERT INTO t (ts, tm) VALUES (TIMESTAMP '2022-07-04 01:02:03.45-07:00', TIME '01:02:03');
INSERT INTO t (ts, tm) VALUES (NULL, NULL);
SELECT ts AT LOCAL AS a, tm AT LOCAL AS b FROM t WHERE ts AT LOCAL IS NOT NULL;
SELECT ts AT LOCAL AS a, tm AT LOCAL AS b FROM t WHERE ts IS NULL;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- A: 2022-07-04T13:02:03.45+0500 (TIMESTAMP(2) WITH TIME ZONE) B: 01:02:03+0500 (TIME(0) WITH TIME ZONE)
-- A: NULL (TIMESTAMP(2) WITH TIME ZONE) B: NULL (TIME(0) WITH TIME ZONE)

-- # A dynamic parameter on its own is a TIMESTAMP(6) WITH TIME ZONE.
/* params NULL TIMESTAMP */
/* types */
VALUES ? AT LOCAL;
-- sql: VALUES CAST(NULL AS TIMESTAMP(0) WITHOUT TIME ZONE) AT LOCAL
-- COL1: NULL (TIMESTAMP(6) WITH TIME ZONE)

-- # A DATE (or anything that isn't a datetime) can't have a time zone (6.42,
-- # Syntax Rules, 1 and 3).
VALUES DATE '2022-07-04' AT LOCAL;
VALUES 123 AT LOCAL;
VALUES 'foo' AT LOCAL;
-- error 42804: data type mismatch in DATE '2022-07-04' AT LOCAL: expected TIME or TIMESTAMP but got DATE
-- error 42804: data type mismatch in 123 AT LOCAL: expected TIME or TIMESTAMP but got SMALLINT
-- error 42804: data type mismatch in 'foo' AT LOCAL: expected TIME or TIMESTAMP but got CHARACTER(3)

-- # A datetime without a time zone depends on the time zone of the session, so
-- # it can't be in a CHECK constraint or a generated column (9.16, Syntax
-- # Rules, 1.i). A datetime with a time zone is still the same instant.
CREATE TABLE c1 (x TIMESTAMP CHECK (x AT LOCAL > TIMESTAMP '2000-01-01 00:00:00+00:00'));
CREATE TABLE c2 (x TIME, y TIME WITH TIME ZONE GENERATED ALWAYS AS (x AT LOCAL));
CREATE TABLE c3 (x TIMESTAMP WITH TIME ZONE CHECK (x AT LOCAL > TIMESTAMP '2000-01-01 00:00:00+00:00'));
-- error 42601: syntax error: X AT LOCAL cannot be used in a CHECK constraint
-- error 42601: syntax error: X AT LOCAL cannot be used in a generation expression
-- msg: CREATE TABLE 1

-- # A <time zone> needs F411 (6.42, Conformance Rules, 2).
/* flags */
CREATE TABLE t (x INT);
SELECT TIMESTAMP '2022-07-04 12:00:00' AT LOCAL FROM t;
SELECT TIMESTAMP '2022-07-04 12:00:00' FROM t;
-- flags:
-- msg: CREATE TABLE 1
-- flags: F411
-- flags:
