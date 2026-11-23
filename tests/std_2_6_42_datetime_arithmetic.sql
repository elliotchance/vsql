/* setup */
CREATE TABLE t (d DATE, i INTERVAL DAY);
INSERT INTO t (d, i) VALUES (DATE '2020-01-01', NULL), (NULL, INTERVAL '1' DAY);

-- # A datetime plus or minus an interval has the type of the datetime, with
-- # the greater fractional seconds precision (6.42, Syntax Rules, 5.b). An
-- # interval can also be added to a datetime.
/* types */
VALUES DATE '2020-01-31' + INTERVAL '1' DAY;
VALUES DATE '2020-03-01' - INTERVAL '1' DAY;
VALUES INTERVAL '3' DAY + DATE '2020-12-30';
VALUES TIMESTAMP '2020-01-31 10:00:00' - INTERVAL '1 02:03:04.5' DAY TO SECOND;
VALUES TIMESTAMP '2020-01-31 10:00:00.25' + INTERVAL '1' MINUTE;
VALUES TIME '10:00:00' + INTERVAL '0.123' SECOND(2, 3);
-- COL1: 2020-02-01 (DATE)
-- COL1: 2020-02-29 (DATE)
-- COL1: 2021-01-02 (DATE)
-- COL1: 2020-01-30T07:56:55.500000 (TIMESTAMP(6) WITHOUT TIME ZONE)
-- COL1: 2020-01-31T10:01:00.25 (TIMESTAMP(2) WITHOUT TIME ZONE)
-- COL1: 10:00:00.123 (TIME(3) WITHOUT TIME ZONE)

-- # A year-month interval keeps the day, and it's 22008 (datetime field
-- # overflow) if that day isn't in the month (6.42, General Rules, 4 and 6.b).
VALUES DATE '2020-01-15' + INTERVAL '1-1' YEAR TO MONTH;
VALUES DATE '2020-01-29' + INTERVAL '1' MONTH;
VALUES DATE '2020-01-30' + INTERVAL '1' MONTH;
VALUES DATE '2020-02-29' - INTERVAL '1' YEAR;
VALUES TIMESTAMP '2020-05-31 12:00:00' - INTERVAL '-14' MONTH;
-- COL1: 2021-02-15
-- COL1: 2020-02-29
-- error 22008: datetime field overflow
-- error 22008: datetime field overflow
-- COL1: 2021-07-31T12:00:00

-- # The result must be between the years 1 and 9999.
VALUES DATE '9999-12-31' + INTERVAL '1' DAY;
VALUES DATE '0001-01-01' - INTERVAL '1' MONTH;
VALUES TIMESTAMP '9999-12-31 23:59:59' + INTERVAL '1' SECOND;
-- error 22008: datetime field overflow
-- error 22008: datetime field overflow
-- error 22008: datetime field overflow

-- # The HOUR of a TIME is modulo 24 (6.42, General Rules, 4).
VALUES TIME '23:00:00' + INTERVAL '2' HOUR;
VALUES TIME '01:00:00' - INTERVAL '90' MINUTE;
VALUES TIME '01:00:00' + INTERVAL '-49' HOUR;
-- COL1: 01:00:00
-- COL1: 23:30:00
-- COL1: 00:00:00

-- # The time zone of the result is the time zone of the datetime, and its UTC
-- # component changes (6.42, General Rules, 6). A year-month interval is added
-- # to the UTC date, so 2020-02-01 03:00 UTC becomes 2020-03-01 03:00 UTC.
/* types */
VALUES TIMESTAMP '2020-01-31 22:00:00-05:00' + INTERVAL '3' HOUR;
VALUES TIMESTAMP '2020-01-31 22:00:00-05:00' + INTERVAL '1' MONTH;
VALUES TIME '23:30:00+02:00' + INTERVAL '1' HOUR;
-- COL1: 2020-02-01T01:00:00-0500 (TIMESTAMP(0) WITH TIME ZONE)
-- COL1: 2020-02-29T22:00:00-0500 (TIMESTAMP(0) WITH TIME ZONE)
-- COL1: 00:30:00+0200 (TIME(0) WITH TIME ZONE)

-- # The interval can only have the fields of the datetime (6.42, Syntax Rules,
-- # 5.a).
VALUES DATE '2020-01-01' + INTERVAL '1' HOUR;
VALUES DATE '2020-01-01' + INTERVAL '1 02' DAY TO HOUR;
VALUES TIME '10:00:00' + INTERVAL '1' DAY;
VALUES INTERVAL '1' MONTH + TIME '10:00:00';
-- error 42883: operator does not exist: DATE + INTERVAL HOUR(2)
-- error 42883: operator does not exist: DATE + INTERVAL DAY(2) TO HOUR
-- error 42883: operator does not exist: TIME(0) WITHOUT TIME ZONE + INTERVAL DAY(2)
-- error 42883: operator does not exist: INTERVAL MONTH(2) + TIME(0) WITHOUT TIME ZONE

-- # A datetime can't be subtracted from an interval, and two datetimes can't be
-- # added. The difference of two datetimes needs an interval qualifier (see
-- # std_2_6_44_interval_value_expression.sql).
VALUES INTERVAL '1' DAY - DATE '2020-01-01';
VALUES DATE '2020-01-01' + DATE '2020-01-01';
VALUES DATE '2020-01-01' * INTERVAL '1' DAY;
VALUES DATE '2020-01-01' + 1;
VALUES DATE '2020-01-02' - DATE '2020-01-01';
-- error 42883: operator does not exist: INTERVAL DAY(2) - DATE
-- error 42883: operator does not exist: DATE + DATE
-- error 42883: operator does not exist: DATE * INTERVAL DAY(2)
-- error 42883: operator does not exist: DATE + SMALLINT
-- error 42601: syntax error: DATE - DATE needs an interval qualifier, such as (A - B) DAY TO SECOND

-- # The result is NULL if either operand is NULL (6.42, General Rules, 1).
SELECT d + i, i + d, d - i FROM t;
-- COL1: NULL COL2: NULL COL3: NULL
-- COL1: NULL COL2: NULL COL3: NULL

-- # A dynamic parameter added to a DATE is an INTERVAL YEAR TO MONTH, and one
-- # added to a TIMESTAMP is an INTERVAL DAY TO SECOND (20.7, General Rules,
-- # 5.a.xi.2.A and 5.a.xi.2.B). One added to a TIME is an INTERVAL HOUR TO
-- # SECOND, since a TIME doesn't have a DAY.
/* types */
/* params '1-02' '1 02:03:04' '26:00:00' */
VALUES (DATE '2020-01-31' + ?, ? + TIMESTAMP '2020-01-31 00:00:00', TIME '23:00:00' - ?);
-- sql: VALUES (DATE '2020-01-31' + '1-02', '1 02:03:04' + TIMESTAMP '2020-01-31 00:00:00', TIME '23:00:00' - '26:00:00')
-- COL1: 2021-03-31 (DATE) COL2: 2020-02-01T02:03:04.000000 (TIMESTAMP(6) WITHOUT TIME ZONE) COL3: 21:00:00.000000 (TIME(6) WITHOUT TIME ZONE)

-- # Datetime arithmetic needs F052 (6.42, Conformance Rules, 1).
/* flags */
SELECT d + i FROM t;
SELECT d - i FROM t;
-- flags: F052
-- COL1: NULL
-- COL1: NULL
-- flags: F052
-- COL1: NULL
-- COL1: NULL
