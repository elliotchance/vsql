/* setup */
CREATE TABLE t (a TIMESTAMP, b TIMESTAMP, i INTERVAL HOUR TO MINUTE);
INSERT INTO t (a, b, i) VALUES (TIMESTAMP '2020-03-01 10:30:00', TIMESTAMP '2020-02-01 00:00:00', INTERVAL '1:30' HOUR TO MINUTE);

-- # The sum or difference of two intervals has every field of either one, the
-- # greater fractional seconds precision, and the maximum leading field
-- # precision (6.44, Syntax Rules, 2.c).
/* types */
VALUES INTERVAL '1' DAY + INTERVAL '2' HOUR;
VALUES INTERVAL '1' HOUR - INTERVAL '1:30' MINUTE TO SECOND(1);
VALUES INTERVAL '1' YEAR + INTERVAL '14' MONTH;
VALUES INTERVAL '99' DAY + INTERVAL '99' DAY;
-- COL1: 1 02 (INTERVAL DAY(8) TO HOUR)
-- COL1: 0:58:30.0 (INTERVAL HOUR(8) TO SECOND(1))
-- COL1: 2-02 (INTERVAL YEAR(8) TO MONTH)
-- COL1: 198 (INTERVAL DAY(8))

-- # Both must be year-month intervals, or both day-time intervals (6.44,
-- # Syntax Rules, 3.a and 3.b).
VALUES INTERVAL '1' DAY + INTERVAL '1' YEAR;
VALUES INTERVAL '1' MONTH - INTERVAL '1' SECOND;
-- error 42883: operator does not exist: INTERVAL DAY(2) + INTERVAL YEAR(2)
-- error 42883: operator does not exist: INTERVAL MONTH(2) - INTERVAL SECOND(2, 6)

-- # It's 22015 (interval field overflow) if the result doesn't fit.
VALUES INTERVAL '99999999' DAY(8) + INTERVAL '1' DAY;
VALUES INTERVAL '-99999999' DAY(8) - INTERVAL '99999999' DAY(8) - INTERVAL '99999999' DAY(8);
-- error 22015: interval field overflow
-- error 22015: interval field overflow

-- # An interval multiplied or divided by a number has the fields of the
-- # interval (6.44, Syntax Rules, 2.b). The result is in units of the least
-- # significant field, truncated towards zero (6.44, General Rules, 1 and 5).
/* types */
VALUES INTERVAL '1' DAY * 2.5;
VALUES 3 * INTERVAL '1-6' YEAR TO MONTH;
VALUES INTERVAL '1-6' YEAR TO MONTH / 4;
VALUES INTERVAL '10' SECOND(2, 1) / 3;
VALUES INTERVAL '-1 00:00' DAY TO MINUTE * 0.5e0;
VALUES INTERVAL '1' DAY / 3;
-- COL1: 2 (INTERVAL DAY(8))
-- COL1: 4-06 (INTERVAL YEAR(8) TO MONTH)
-- COL1: 0-04 (INTERVAL YEAR(8) TO MONTH)
-- COL1: 3.3 (INTERVAL SECOND(8, 1))
-- COL1: -0 12:00 (INTERVAL DAY(8) TO MINUTE)
-- COL1: 0 (INTERVAL DAY(8))

VALUES INTERVAL '1' DAY / 0;
VALUES INTERVAL '99999999' DAY(8) * 10;
VALUES INTERVAL '1' DAY * 1e300;
VALUES 2 / INTERVAL '1' DAY;
VALUES INTERVAL '1' DAY * INTERVAL '1' DAY;
-- error 22012: division by zero
-- error 22015: interval field overflow
-- error 22015: interval field overflow
-- error 42883: operator does not exist: INTEGER / INTERVAL DAY(2)
-- error 42883: operator does not exist: INTERVAL DAY(2) * INTERVAL DAY(2)

-- # A sign makes the interval negative, or doesn't change it (6.44, General
-- # Rules, 4).
/* types */
VALUES -INTERVAL '1' DAY;
VALUES +INTERVAL '1-02' YEAR TO MONTH;
VALUES -(INTERVAL '-3' HOUR);
-- COL1: -1 (INTERVAL DAY(2))
-- COL1: 1-02 (INTERVAL YEAR(2) TO MONTH)
-- COL1: 3 (INTERVAL HOUR(2))

-- # The difference of two datetimes in parentheses, followed by an interval
-- # qualifier, is an interval of that type (6.44, Syntax Rules, 2.a). Each
-- # datetime is a number of the least significant field of the qualifier, and
-- # the result is their difference (6.44, General Rules, 7.c and 7.d).
/* types */
VALUES (DATE '2020-03-01' - DATE '2020-02-01') DAY;
VALUES (DATE '2020-03-01' - DATE '2019-02-15') YEAR TO MONTH;
VALUES (DATE '2020-03-01' - DATE '2019-02-15') YEAR;
VALUES (DATE '2020-01-01' - DATE '2020-03-01') MONTH;
SELECT (a - b) DAY TO SECOND, (b - a) HOUR(3) TO MINUTE, (a - b) DAY FROM t;
VALUES (TIMESTAMP '2020-01-02 01:00:00' - TIMESTAMP '2020-01-01 23:00:00') DAY;
VALUES (TIMESTAMP '2020-01-02 01:00:00.123456' - TIMESTAMP '2020-01-01 23:00:00') MINUTE(3) TO SECOND(3);
-- COL1: 29 (INTERVAL DAY(2))
-- COL1: 1-01 (INTERVAL YEAR(2) TO MONTH)
-- COL1: 1 (INTERVAL YEAR(2))
-- COL1: -2 (INTERVAL MONTH(2))
-- COL1: 29 10:30:00.000000 (INTERVAL DAY(2) TO SECOND(6)) COL2: -706:30 (INTERVAL HOUR(3) TO MINUTE) COL3: 29 (INTERVAL DAY(2))
-- COL1: 1 (INTERVAL DAY(2))
-- COL1: 120:00.123 (INTERVAL MINUTE(3) TO SECOND(3))

-- # The difference of two TIMEs is less than 24 hours.
VALUES (TIME '01:00:00' - TIME '23:00:00') HOUR TO MINUTE;
VALUES (TIME '23:59:59.5' - TIME '00:00:00') SECOND(5, 1);
-- COL1: -22:00
-- COL1: 86399.5

-- # It's 22015 (interval field overflow) if the start field has more digits
-- # than the leading field precision.
VALUES (DATE '2020-01-01' - DATE '2000-01-01') DAY;
VALUES (DATE '2020-01-01' - DATE '2000-01-01') DAY(4);
-- error 22015: interval field overflow
-- COL1: 7305

-- # A datetime with a time zone is in the time zone of the session first (6.44,
-- # General Rules, 7.a and 7.b). The time zone of the session is +05:00.
VALUES (TIMESTAMP '2020-01-02 01:00:00+05:00' - TIMESTAMP '2020-01-01 20:00:00+00:00') MINUTE;
VALUES (TIMESTAMP '2020-01-02 00:00:00+05:00' - TIMESTAMP '2020-01-01 23:00:00') DAY;
VALUES (TIMESTAMP '2020-01-01 19:30:00+00:00' - TIMESTAMP '2020-01-01 00:00:00+05:00') DAY;
-- COL1: 0
-- COL1: 1
-- COL1: 1

-- # The datetimes must be comparable (6.44, Syntax Rules, 4).
VALUES (DATE '2020-01-01' - TIMESTAMP '2020-01-01 00:00:00') DAY;
VALUES (INTERVAL '1' DAY - INTERVAL '1' DAY) DAY;
VALUES (1 - 2) DAY;
-- error 42883: operator does not exist: (DATE - TIMESTAMP(0) WITHOUT TIME ZONE) DAY(2)
-- error 42883: operator does not exist: (INTERVAL DAY(2) - INTERVAL DAY(2)) DAY(2)
-- error 42883: operator does not exist: (INTEGER - INTEGER) DAY(2)

-- # Only a dynamic parameter or the difference of two datetimes in parentheses
-- # can have an interval qualifier (6.44, Syntax Rules, 5).
VALUES (DATE '2020-01-01') DAY;
SELECT i HOUR FROM t;
VALUES (DATE '2020-01-01' + INTERVAL '1' DAY) DAY;
-- error 42601: syntax error: an interval qualifier can only follow a dynamic parameter or the difference of two datetimes in parentheses: (DATE '2020-01-01') DAY(2)
-- error 42601: syntax error: an interval qualifier can only follow a dynamic parameter or the difference of two datetimes in parentheses: I HOUR(2)
-- error 42601: syntax error: an interval qualifier can only follow a dynamic parameter or the difference of two datetimes in parentheses: (DATE '2020-01-01' + INTERVAL '1' DAY(2)) DAY(2)

-- # The result is NULL if either datetime is NULL (6.44, General Rules, 2).
VALUES (DATE '2020-01-01' - CAST(NULL AS DATE)) DAY;
-- COL1: NULL

-- # The difference can be used with other operators.
SELECT (a - b) DAY TO MINUTE + i, a + (a - b) DAY FROM t;
-- COL1: 29 12:00 COL2: 2020-03-30T10:30:00.000000

-- # The difference of a datetime with a time zone and one without depends on
-- # the time zone of the session (9.16, Syntax Rules, 1.k).
CREATE TABLE t2 (a TIMESTAMP WITH TIME ZONE, b TIMESTAMP, CHECK ((a - b) HOUR > INTERVAL '0' HOUR));
CREATE TABLE t3 (a TIMESTAMP WITH TIME ZONE, b TIMESTAMP WITH TIME ZONE, CHECK ((a - b) HOUR > INTERVAL '0' HOUR));
-- error 42601: syntax error: the difference of TIMESTAMP(6) WITH TIME ZONE and TIMESTAMP(6) WITHOUT TIME ZONE cannot be used in a CHECK constraint
-- msg: CREATE TABLE 1

-- # A dynamic parameter followed by an interval qualifier is cast to that
-- # interval type (6.44, General Rules, 3.a, and 20.7, General Rules, 5.a.i).
/* types */
/* params '1 02' */
VALUES ? DAY TO HOUR;
-- sql: VALUES '1 02' DAY TO HOUR
-- COL1: 1 02 (INTERVAL DAY(2) TO HOUR)

-- # A dynamic parameter in the difference of two datetimes has the type of the
-- # other datetime (20.7, General Rules, 5.a.xi.1 and 5.a.xi.2.C).
/* types */
/* params '2020-01-10' '2020-01-01' */
VALUES ((? - DATE '2020-01-01') DAY, (DATE '2020-01-10' - ?) DAY);
-- sql: VALUES (('2020-01-10' - DATE '2020-01-01') DAY, (DATE '2020-01-10' - '2020-01-01') DAY)
-- COL1: 9 (INTERVAL DAY(2)) COL2: 9 (INTERVAL DAY(2))

-- # A dynamic parameter added to an interval is that interval type, and one
-- # that an interval is multiplied or divided by is a NUMERIC (20.7, General
-- # Rules, 5.a.x.2.A and 5.a.xi.2.C).
/* types */
/* params '3' 2 '1' 3 */
VALUES (INTERVAL '1' DAY + ?, INTERVAL '1' DAY * ?, ? - INTERVAL '1' HOUR, ? * INTERVAL '1' HOUR);
-- sql: VALUES (INTERVAL '1' DAY + '3', INTERVAL '1' DAY * 2.0e0, '1' - INTERVAL '1' HOUR, 3.0e0 * INTERVAL '1' HOUR)
-- COL1: 4 (INTERVAL DAY(8)) COL2: 2 (INTERVAL DAY(8)) COL3: 0 (INTERVAL HOUR(8)) COL4: 3 (INTERVAL HOUR(8))

-- # An interval value expression needs F052 (6.44, Conformance Rules, 1).
/* flags */
SELECT i + i, i * 2, (a - b) DAY FROM t;
-- flags: F052
-- COL1: 3:00 COL2: 3:00 COL3: 29
