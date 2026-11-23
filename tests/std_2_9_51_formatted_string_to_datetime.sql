-- # CAST(character string AS datetime FORMAT template). The tests run on
-- # 2022-07-04 (in a time zone of +05:00), which is the current date for the
-- # fields that are missing.
/* types */
VALUES CAST('2024-03-05 14:07:09' AS TIMESTAMP(0) FORMAT 'YYYY-MM-DD HH24:MI:SS');
VALUES CAST('05/03/2024' AS DATE FORMAT 'DD/MM/YYYY');
VALUES CAST('14:07' AS TIME FORMAT 'HH24:MI');
VALUES CAST('05/03/2024 2:07 P.M.' AS TIMESTAMP(0) FORMAT 'DD/MM/YYYY HH12:MI A.M.');
-- COL1: 2024-03-05T14:07:09 (TIMESTAMP(0) WITHOUT TIME ZONE)
-- COL1: 2024-03-05 (DATE)
-- COL1: 14:07:00 (TIME(0) WITHOUT TIME ZONE)
-- COL1: 2024-03-05T14:07:00 (TIMESTAMP(0) WITHOUT TIME ZONE)

-- # A field between delimiters (or at the start or end) can be from 1 digit up
-- # to its full length. Otherwise it must be its full length, so a string that
-- # can't be long enough is an error before it's cast.
VALUES CAST('2024-3-5' AS DATE FORMAT 'YYYY-MM-DD');
VALUES CAST('20240305' AS DATE FORMAT 'YYYYMMDD');
VALUES CAST('202403-5' AS DATE FORMAT 'YYYYMM-DD');
VALUES CAST(CAST('2024035' AS VARCHAR(8)) AS DATE FORMAT 'YYYYMMDD');
VALUES CAST('2024035' AS DATE FORMAT 'YYYYMMDD');
-- COL1: 2024-03-05
-- COL1: 2024-03-05
-- COL1: 2024-03-05
-- error 22007: invalid datetime format
-- error 42601: syntax error: invalid datetime template 'YYYYMMDD': CHARACTER(7) is shorter than the template (8)

-- # Every delimiter must match itself: - . / , ' ; : and space.
VALUES CAST('2024-03.05/14,07''09;' AS TIMESTAMP(0) FORMAT 'YYYY-MM.DD/HH24,MI''SS;');
VALUES CAST(':14 07' AS TIME FORMAT ':HH24 MI');
VALUES CAST('2024.03-05' AS DATE FORMAT 'YYYY-MM.DD');
-- COL1: 2024-03-05T14:07:09
-- COL1: 14:07:00
-- error 22007: invalid datetime format

-- # A year with fewer digits takes the rest from the current year (2022).
VALUES CAST('24-03-05' AS DATE FORMAT 'YY-MM-DD');
VALUES CAST('4-03-05' AS DATE FORMAT 'Y-MM-DD');
VALUES CAST('987-03-05' AS DATE FORMAT 'YYY-MM-DD');
VALUES CAST('24-03-05' AS DATE FORMAT 'YYYY-MM-DD');
-- COL1: 2024-03-05
-- COL1: 2024-03-05
-- COL1: 2987-03-05
-- COL1: 2024-03-05

-- # A rounded year of 2 digits is the nearest year that ends with them (from 50
-- # years before the current year up to 49 after it), and 1 digit is within 5
-- # years.
VALUES CAST('71-01-01' AS DATE FORMAT 'RR-MM-DD');
VALUES CAST('72-01-01' AS DATE FORMAT 'RR-MM-DD');
VALUES CAST('9-01-01' AS DATE FORMAT 'RR-MM-DD');
VALUES CAST('6-01-01' AS DATE FORMAT 'RR-MM-DD');
VALUES CAST('1999-01-01' AS DATE FORMAT 'RRRR-MM-DD');
VALUES CAST('987-01-01' AS DATE FORMAT 'RRRR-MM-DD');
-- COL1: 2071-01-01
-- COL1: 1972-01-01
-- COL1: 2019-01-01
-- COL1: 2026-01-01
-- COL1: 1999-01-01
-- COL1: 2987-01-01

-- # Without a year it's the current year, without a month it's the current
-- # month, and without a day it's the first.
VALUES CAST('05' AS DATE FORMAT 'DD');
VALUES CAST('03' AS DATE FORMAT 'MM');
VALUES CAST('2024' AS DATE FORMAT 'YYYY');
-- COL1: 2022-07-05
-- COL1: 2022-03-01
-- COL1: 2024-07-01

-- # A day of year is in the year of the string.
VALUES CAST('2024 60' AS DATE FORMAT 'YYYY DDD');
VALUES CAST('2023 60' AS DATE FORMAT 'YYYY DDD');
VALUES CAST('2024 366' AS DATE FORMAT 'YYYY DDD');
VALUES CAST('2023 366' AS DATE FORMAT 'YYYY DDD');
VALUES CAST('2023 0' AS DATE FORMAT 'YYYY DDD');
-- COL1: 2024-02-29
-- COL1: 2023-03-01
-- COL1: 2024-12-31
-- error 22007: invalid datetime format
-- error 22007: invalid datetime format

-- # A 12-hour of 12 is 0, and P.M. adds 12 hours. A.M. and P.M. are the same
-- # field.
VALUES CAST('12:30 A.M.' AS TIME FORMAT 'HH12:MI A.M.');
VALUES CAST('12:30 P.M.' AS TIME FORMAT 'HH12:MI A.M.');
VALUES CAST('1:30 P.M.' AS TIME FORMAT 'HH:MI P.M.');
VALUES CAST('11:30A.M.' AS TIME FORMAT 'HH:MIP.M.');
VALUES CAST('11:30 AM' AS TIME FORMAT 'HH:MI A.M.');
VALUES CAST('11:30 a.m.' AS TIME FORMAT 'HH:MI A.M.');
VALUES CAST('13:30 P.M.' AS TIME FORMAT 'HH:MI A.M.');
-- COL1: 00:30:00
-- COL1: 12:30:00
-- COL1: 13:30:00
-- COL1: 11:30:00
-- error 22007: invalid datetime format
-- error 22007: invalid datetime format
-- error 22007: invalid datetime format

-- # A second of day, and a fraction of a second.
/* types */
VALUES CAST('3725' AS TIME FORMAT 'SSSSS');
VALUES CAST('86399.5' AS TIME(1) FORMAT 'SSSSS.FF1');
VALUES CAST('86400' AS TIME FORMAT 'SSSSS');
VALUES CAST('14:07:09.123456789' AS TIME(6) FORMAT 'HH24:MI:SS.FF9');
VALUES CAST('14:07:09.5' AS TIME(3) FORMAT 'HH24:MI:SS.FF3');
-- COL1: 01:02:05 (TIME(0) WITHOUT TIME ZONE)
-- COL1: 23:59:59.5 (TIME(1) WITHOUT TIME ZONE)
-- error 22007: invalid datetime format
-- COL1: 14:07:09.123456 (TIME(6) WITHOUT TIME ZONE)
-- COL1: 14:07:09.500 (TIME(3) WITHOUT TIME ZONE)

-- # A time zone hour starts with a sign or space (for +). The minute has the
-- # sign of the hour. Without a time zone, it's +00:00.
/* types */
VALUES CAST('14:07 +05:30' AS TIME WITH TIME ZONE FORMAT 'HH24:MI TZH:TZM');
VALUES CAST('14:07 -5:30' AS TIME WITH TIME ZONE FORMAT 'HH24:MI TZH:TZM');
VALUES CAST('14:07  5' AS TIME WITH TIME ZONE FORMAT 'HH24:MI TZH');
VALUES CAST('2024-03-05 14:07-0530' AS TIMESTAMP(0) WITH TIME ZONE FORMAT 'YYYY-MM-DD HH24:MITZHTZM');
VALUES CAST('2024-03-05 14:07' AS TIMESTAMP(0) WITH TIME ZONE FORMAT 'YYYY-MM-DD HH24:MI');
VALUES CAST('14:07 05:30' AS TIME WITH TIME ZONE FORMAT 'HH24:MI TZH:TZM');
VALUES CAST('14:07 +15:00' AS TIME WITH TIME ZONE FORMAT 'HH24:MI TZH:TZM');
-- COL1: 14:07:00+0530 (TIME(0) WITH TIME ZONE)
-- COL1: 14:07:00-0530 (TIME(0) WITH TIME ZONE)
-- COL1: 14:07:00+0500 (TIME(0) WITH TIME ZONE)
-- COL1: 2024-03-05T14:07:00-0530 (TIMESTAMP(0) WITH TIME ZONE)
-- COL1: 2024-03-05T14:07:00+0000 (TIMESTAMP(0) WITH TIME ZONE)
-- error 22007: invalid datetime format
-- error 22007: invalid datetime format

-- # A string that doesn't match the template, or isn't a valid datetime, is an
-- # error. Spaces aren't trimmed.
VALUES CAST('2024-01-01x' AS DATE FORMAT 'YYYY-MM-DD');
VALUES CAST(' 2024-01-01' AS DATE FORMAT 'YYYY-MM-DD');
VALUES CAST('2024/01/01' AS DATE FORMAT 'YYYY-MM-DD');
VALUES CAST('2024-02-30' AS DATE FORMAT 'YYYY-MM-DD');
VALUES CAST('2024-13-01' AS DATE FORMAT 'YYYY-MM-DD');
VALUES CAST('2024-00-01' AS DATE FORMAT 'YYYY-MM-DD');
VALUES CAST('0000-01-01' AS DATE FORMAT 'YYYY-MM-DD');
VALUES CAST('24:00' AS TIME FORMAT 'HH24:MI');
VALUES CAST('23:60' AS TIME FORMAT 'HH24:MI');
VALUES CAST('23:59:60' AS TIME FORMAT 'HH24:MI:SS');
VALUES CAST('２０２４' AS DATE FORMAT 'YYYY');
-- error 22007: invalid datetime format
-- error 22007: invalid datetime format
-- error 22007: invalid datetime format
-- error 22007: invalid datetime format
-- error 22007: invalid datetime format
-- error 22007: invalid datetime format
-- error 22007: invalid datetime format
-- error 22007: invalid datetime format
-- error 22007: invalid datetime format
-- error 22007: invalid datetime format
-- error 22007: invalid datetime format

-- # The null value is the null value of the datetime type.
/* types */
VALUES CAST(CAST(NULL AS VARCHAR(10)) AS DATE FORMAT 'YYYY-MM-DD');
-- COL1: NULL (DATE)

-- # A dynamic parameter is a character string, which can be any length.
/* params '2024-03-05' */
VALUES CAST(? AS DATE FORMAT 'YYYY-MM-DD');
-- sql: VALUES CAST('2024-03-05' AS DATE FORMAT 'YYYY-MM-DD')
-- COL1: 2024-03-05

/* params '2024-03-05x' */
VALUES CAST(? AS DATE FORMAT 'YYYY-MM-DD');
-- sql: VALUES CAST('2024-03-05x' AS DATE FORMAT 'YYYY-MM-DD')
-- error 22007: invalid datetime format

-- # A column can be cast.
/* define t */
CREATE TABLE t (s VARCHAR(20));
INSERT INTO t VALUES ('05/03/2024'), ('31/12/1999'), (NULL);

/* include t */
SELECT CAST(s AS DATE FORMAT 'DD/MM/YYYY') AS d FROM t ORDER BY d;
-- D: NULL
-- D: 1999-12-31
-- D: 2024-03-05

-- # A template that uses the current date can't be used in a CHECK constraint.
CREATE TABLE c1 (s VARCHAR(10) CHECK (CAST(s AS DATE FORMAT 'YYYY-MM-DD') > DATE '2000-01-01'));
CREATE TABLE c2 (s VARCHAR(10) CHECK (CAST(s AS DATE FORMAT 'YYYYMMDD') > DATE '2000-01-01'));
CREATE TABLE c3 (s VARCHAR(10) CHECK (CAST(s AS DATE FORMAT 'YYYYDDD') > DATE '2000-01-01'));
CREATE TABLE c4 (s VARCHAR(10) CHECK (CAST(s AS DATE FORMAT 'MMDD') > DATE '2000-01-01'));
CREATE TABLE c5 (s VARCHAR(10) CHECK (CAST(s AS TIME FORMAT 'HH24:MI') > TIME '12:00:00'));
-- error 42601: syntax error: CAST with a FORMAT that uses the current date cannot be used in a CHECK constraint
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- error 42601: syntax error: CAST with a FORMAT that uses the current date cannot be used in a CHECK constraint
-- msg: CREATE TABLE 1
