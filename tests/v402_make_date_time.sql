-- # MAKE_DATE (V402-09), MAKE_TIME (V402-10), MAKE_TIMESTAMP (V402-11) and
-- # MAKE_TIMESTAMPTZ (V402-12) are vsql extensions that build a datetime from
-- # its fields. A field out of range is an error, it never rolls over into the
-- # next unit (except a leap second, like in a literal).

/* setup */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);

VALUES MAKE_DATE(2024, 6, 30);
-- COL1: 2024-06-30

VALUES MAKE_TIME(12, 34, 56);
-- COL1: 12:34:56.000000

VALUES MAKE_TIMESTAMP(2024, 6, 30, 12, 34, 56);
-- COL1: 2024-06-30T12:34:56.000000

values (make_date ( 1, 1, 1 ), make_date(9999, 12, 31));
-- COL1: 0001-01-01 COL2: 9999-12-31

-- # The result types.
/* extensions V001-01 */
EXPLAIN SELECT MAKE_DATE(1, 2, 3), MAKE_TIME(1, 2, 3), MAKE_TIMESTAMP(1, 2, 3, 4, 5, 6), MAKE_TIMESTAMPTZ(1, 2, 3, 4, 5, 6) FROM t;
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (X INTEGER)
-- EXPLAIN: EXPR (COL1 DATE, COL2 TIME(6) WITHOUT TIME ZONE, COL3 TIMESTAMP(6) WITHOUT TIME ZONE, COL4 TIMESTAMP(6) WITH TIME ZONE)

-- # The same as a literal.
VALUES (MAKE_DATE(2024, 2, 3) = DATE '2024-02-03', MAKE_TIME(4, 5, 6.5) = TIME '04:05:06.5', MAKE_TIMESTAMP(2024, 2, 3, 4, 5, 6.5) = TIMESTAMP '2024-02-03 04:05:06.5');
-- COL1: TRUE COL2: TRUE COL3: TRUE

-- # Any integer type, from a column.
SELECT MAKE_DATE(CAST(2024 AS BIGINT), CAST(x AS SMALLINT), x) FROM t;
-- COL1: 2024-01-01

-- # Leap years.
VALUES MAKE_DATE(2024, 2, 29);
-- COL1: 2024-02-29

VALUES MAKE_DATE(2023, 2, 29);
-- error 22007: invalid datetime format

VALUES MAKE_DATE(1900, 2, 29);
-- error 22007: invalid datetime format

VALUES MAKE_DATE(2000, 2, 29);
-- COL1: 2000-02-29

VALUES MAKE_TIMESTAMP(2023, 2, 29, 0, 0, 0);
-- error 22007: invalid datetime format

-- # Each field out of range.
VALUES MAKE_DATE(0, 1, 1);
-- error 22007: invalid datetime format

VALUES MAKE_DATE(10000, 1, 1);
-- error 22007: invalid datetime format

VALUES MAKE_DATE(-2024, 1, 1);
-- error 22007: invalid datetime format

VALUES MAKE_DATE(9223372036854775807, 1, 1);
-- error 22007: invalid datetime format

VALUES MAKE_DATE(2024, 0, 1);
-- error 22007: invalid datetime format

VALUES MAKE_DATE(2024, 13, 1);
-- error 22007: invalid datetime format

VALUES MAKE_DATE(2024, 1, 0);
-- error 22007: invalid datetime format

VALUES MAKE_DATE(2024, 1, 32);
-- error 22007: invalid datetime format

VALUES MAKE_DATE(2024, 4, 31);
-- error 22007: invalid datetime format

VALUES MAKE_TIME(-1, 0, 0);
-- error 22007: invalid datetime format

VALUES MAKE_TIME(24, 0, 0);
-- error 22007: invalid datetime format

VALUES MAKE_TIME(0, -1, 0);
-- error 22007: invalid datetime format

VALUES MAKE_TIME(0, 60, 0);
-- error 22007: invalid datetime format

VALUES MAKE_TIME(0, 0, -1);
-- error 22007: invalid datetime format

VALUES MAKE_TIME(0, 0, -0.0000001);
-- error 22007: invalid datetime format

VALUES MAKE_TIME(0, 0, -1e-7);
-- error 22007: invalid datetime format

VALUES MAKE_TIME(0, 0, 62);
-- error 22007: invalid datetime format

VALUES MAKE_TIME(0, 0, 1e2);
-- error 22007: invalid datetime format

VALUES MAKE_TIMESTAMP(2024, 1, 1, 24, 0, 0);
-- error 22007: invalid datetime format

VALUES MAKE_TIMESTAMP(2024, 1, 1, 0, 60, 0);
-- error 22007: invalid datetime format

-- # A leap second (60 or 61) is accepted like it is in a literal, and it rolls
-- # over into the next minute.
VALUES (MAKE_TIME(23, 59, 60), MAKE_TIME(23, 59, 60) = TIME '23:59:60');
-- COL1: 00:00:00.000000 COL2: TRUE

VALUES MAKE_TIMESTAMP(2016, 12, 31, 23, 59, 61.5);
-- COL1: 2017-01-01T00:00:01.500000

VALUES MAKE_TIMESTAMP(9999, 12, 31, 23, 59, 59.999999);
-- COL1: 9999-12-31T23:59:59.999999

VALUES MAKE_TIMESTAMP(9999, 12, 31, 23, 59, 60);
-- error 22007: invalid datetime format

-- # The fraction of a second, from an exact or approximate number, is cut to 6
-- # digits.
VALUES MAKE_TIME(12, 34, 56.789);
-- COL1: 12:34:56.789000

VALUES MAKE_TIME(12, 34, 59.9999999);
-- COL1: 12:34:59.999999

VALUES MAKE_TIME(12, 34, CAST(5 AS NUMERIC(20, 10)));
-- COL1: 12:34:05.000000

VALUES MAKE_TIME(12, 34, 5.5e0);
-- COL1: 12:34:05.500000

VALUES MAKE_TIME(12, 34, 0.3e0);
-- COL1: 12:34:00.300000

VALUES MAKE_TIME(12, 34, 1e-7);
-- COL1: 12:34:00.000000

VALUES MAKE_TIME(12, 34, 0e0);
-- COL1: 12:34:00.000000

VALUES MAKE_TIMESTAMP(2024, 2, 29, 1, 2, 3.0000019e0);
-- COL1: 2024-02-29T01:02:03.000001

-- # The other fields must be integers.
VALUES MAKE_DATE(2024, 2, 2.0);
-- error 42883: function does not exist: MAKE_DATE(SMALLINT, SMALLINT, NUMERIC(2, 1))

VALUES MAKE_TIME(1.5e0, 2, 3);
-- error 42883: function does not exist: MAKE_TIME(DOUBLE PRECISION, SMALLINT, SMALLINT)

VALUES MAKE_DATE(2024, 2);
-- error 42883: function does not exist: MAKE_DATE(SMALLINT, SMALLINT)

-- # NULL in any argument.
VALUES MAKE_DATE(CAST(NULL AS INT), 1, 1);
-- COL1: NULL

VALUES MAKE_TIME(1, 2, CAST(NULL AS DOUBLE PRECISION));
-- COL1: NULL

VALUES MAKE_TIMESTAMP(2024, 1, 1, CAST(NULL AS BIGINT), 0, 0);
-- COL1: NULL

VALUES MAKE_TIMESTAMPTZ(2024, 1, 1, 0, 0, 0, CAST(NULL AS VARCHAR(10)));
-- COL1: NULL

-- # MAKE_TIMESTAMPTZ without a time zone is in the session's time zone (+05:00
-- # in these tests).
VALUES MAKE_TIMESTAMPTZ(2024, 6, 30, 12, 34, 56.5);
-- COL1: 2024-06-30T12:34:56.500000+0500

VALUES MAKE_TIMESTAMPTZ(2024, 6, 30, 12, 34, 56) = CAST(TIMESTAMP '2024-06-30 12:34:56' AS TIMESTAMP WITH TIME ZONE);
-- COL1: TRUE

-- # Or a time zone like in a literal.
VALUES MAKE_TIMESTAMPTZ(2024, 6, 30, 12, 34, 56, '-08:00');
-- COL1: 2024-06-30T12:34:56.000000-0800

VALUES MAKE_TIMESTAMPTZ(2024, 6, 30, 12, 34, 56.5e0, '+05:30') = TIMESTAMP '2024-06-30 12:34:56.5+05:30';
-- COL1: TRUE

VALUES MAKE_TIMESTAMPTZ(2024, 6, 30, 12, 34, 56, '+14:00'), MAKE_TIMESTAMPTZ(2024, 6, 30, 12, 34, 56, '-14:00');
-- COL1: 2024-06-30T12:34:56.000000+1400
-- COL1: 2024-06-30T12:34:56.000000-1400

VALUES MAKE_TIMESTAMPTZ(2024, 6, 30, 12, 34, 56, '+14:01');
-- error 22007: invalid datetime format

VALUES MAKE_TIMESTAMPTZ(2024, 6, 30, 12, 34, 56, '+05:60');
-- error 22007: invalid datetime format

VALUES MAKE_TIMESTAMPTZ(2024, 6, 30, 12, 34, 56, '+5:00');
-- error 22007: invalid datetime format

VALUES MAKE_TIMESTAMPTZ(2024, 6, 30, 12, 34, 56, 'America/New_York');
-- error 22007: invalid datetime format

VALUES MAKE_TIMESTAMPTZ(2024, 2, 30, 12, 34, 56, '+00:00');
-- error 22007: invalid datetime format

-- # Without a time zone, it depends on the session, so it can't be in a CHECK.
CREATE TABLE c (a TIMESTAMP WITH TIME ZONE, CHECK (a < MAKE_TIMESTAMPTZ(2024, 1, 1, 0, 0, 0)));
-- error 42601: syntax error: non-deterministic function MAKE_TIMESTAMPTZ cannot be used in a CHECK constraint

CREATE TABLE c (a DATE, CHECK (a < MAKE_DATE(2024, 1, 1)));
-- msg: CREATE TABLE 1

-- # None of the names are reserved.
CREATE TABLE make_date (make_time INT, make_timestamp INT, make_timestamptz INT);
INSERT INTO make_date (make_time, make_timestamp, make_timestamptz) VALUES (1, 2, 3);
SELECT * FROM make_date;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- MAKE_TIME: 1 MAKE_TIMESTAMP: 2 MAKE_TIMESTAMPTZ: 3

-- # The flagger.
/* flags */
SELECT MAKE_DATE(2024, 1, 2), MAKE_TIME(3, 4, 5), MAKE_TIMESTAMP(2024, 1, 2, 3, 4, 5), MAKE_TIMESTAMPTZ(2024, 1, 2, 3, 4, 5, '+01:00') FROM t;
-- flags: V402-09, V402-10, V402-11, V402-12
-- COL1: 2024-01-02 COL2: 03:04:05.000000 COL3: 2024-01-02T03:04:05.000000 COL4: 2024-01-02T03:04:05.000000+0100
