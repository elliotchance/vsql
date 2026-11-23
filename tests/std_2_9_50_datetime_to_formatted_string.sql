-- # CAST(datetime AS character string FORMAT template) formats each field with
-- # its full length.
/* types */
VALUES CAST(TIMESTAMP '2024-03-05 04:07:09' AS VARCHAR(30) FORMAT 'YYYY-MM-DD HH24:MI:SS');
-- COL1: 2024-03-05 04:07:09 (CHARACTER VARYING(30))

-- # A year is the last digits of the 4-digit year, the same for a rounded
-- # year.
VALUES CAST(DATE '2024-03-05' AS VARCHAR(30) FORMAT 'YYYY');
VALUES CAST(DATE '2024-03-05' AS VARCHAR(30) FORMAT 'YYY');
VALUES CAST(DATE '2024-03-05' AS VARCHAR(30) FORMAT 'YY');
VALUES CAST(DATE '0987-03-05' AS VARCHAR(30) FORMAT 'Y');
VALUES CAST(DATE '0987-03-05' AS VARCHAR(30) FORMAT 'RRRR');
VALUES CAST(DATE '0987-03-05' AS VARCHAR(30) FORMAT 'RR');
-- COL1: 2024
-- COL1: 024
-- COL1: 24
-- COL1: 7
-- COL1: 0987
-- COL1: 87

-- # A day of year is 3 digits.
VALUES CAST(DATE '2024-01-09' AS VARCHAR(30) FORMAT 'YYYY DDD');
VALUES CAST(DATE '2024-12-31' AS VARCHAR(30) FORMAT 'DDD');
-- COL1: 2024 009
-- COL1: 366

-- # A 12-hour is 12 for midnight and noon, with A.M. before noon, and P.M. from
-- # noon. A.M. and P.M. are the same field.
VALUES CAST(TIME '00:30:00' AS VARCHAR(30) FORMAT 'HH12:MI A.M.');
VALUES CAST(TIME '11:30:00' AS VARCHAR(30) FORMAT 'HH12:MI P.M.');
VALUES CAST(TIME '12:30:00' AS VARCHAR(30) FORMAT 'HH:MI A.M.');
VALUES CAST(TIME '23:30:00' AS VARCHAR(30) FORMAT 'HH:MIA.M.');
-- COL1: 12:30 A.M.
-- COL1: 11:30 A.M.
-- COL1: 12:30 P.M.
-- COL1: 11:30P.M.

-- # A second of day is 5 digits.
VALUES CAST(TIME '00:01:05' AS VARCHAR(30) FORMAT 'SSSSS');
VALUES CAST(TIME '23:59:59.9' AS VARCHAR(30) FORMAT 'SSSSS.FF1');
-- COL1: 00065
-- COL1: 86399.9

-- # The fraction of a second is truncated to its digits.
VALUES CAST(TIME '14:07:09.987654' AS VARCHAR(30) FORMAT 'SS.FF1');
VALUES CAST(TIME '14:07:09.987654' AS VARCHAR(30) FORMAT 'SS.FF3');
VALUES CAST(TIME '14:07:09.987654' AS VARCHAR(30) FORMAT 'SS.FF6');
VALUES CAST(TIME '14:07:09' AS VARCHAR(30) FORMAT 'SS.FF2');
-- COL1: 09.9
-- COL1: 09.987
-- COL1: 09.987654
-- COL1: 09.00

-- # A time zone hour is a sign and 2 digits. The sign is negative if the hour
-- # or minute is negative, and the minute is always positive.
VALUES CAST(TIME '14:07:09+05:30' AS VARCHAR(30) FORMAT 'TZH:TZM');
VALUES CAST(TIME '14:07:09-05:30' AS VARCHAR(30) FORMAT 'TZHTZM');
VALUES CAST(TIME '14:07:09-00:30' AS VARCHAR(30) FORMAT 'TZH TZM');
VALUES CAST(TIME '14:07:09+00:00' AS VARCHAR(30) FORMAT 'HH24TZH');
-- COL1: +05:30
-- COL1: -0530
-- COL1: -00 30
-- COL1: 14+00

-- # The fields of a datetime with a time zone are in its own time zone.
VALUES CAST(TIMESTAMP '2024-03-05 23:30:00-05:00' AS VARCHAR(30) FORMAT 'YYYY-MM-DD HH24:MI TZH');
-- COL1: 2024-03-05 23:30 -05

-- # CHAR is padded with spaces, and VARCHAR isn't.
/* types */
VALUES CAST(DATE '2024-03-05' AS CHAR(12) FORMAT 'YYYY-MM-DD');
VALUES CAST(DATE '2024-03-05' AS VARCHAR(12) FORMAT 'YYYY-MM-DD');
-- COL1: 2024-03-05   (CHARACTER(12))
-- COL1: 2024-03-05 (CHARACTER VARYING(12))

-- # A string that's too long is an error, rather than being truncated.
VALUES CAST(DATE '2024-03-05' AS CHAR(9) FORMAT 'YYYY-MM-DD');
VALUES CAST(DATE '2024-03-05' AS VARCHAR(9) FORMAT 'YYYY-MM-DD');
-- error 22001: string data right truncation for CHARACTER(9)
-- error 22001: string data right truncation for CHARACTER VARYING(9)

-- # The null value is the null value of the character string type.
/* types */
VALUES CAST(CAST(NULL AS DATE) AS VARCHAR(10) FORMAT 'YYYY-MM-DD');
-- COL1: NULL (CHARACTER VARYING(10))

-- # A column can be formatted.
/* define t */
CREATE TABLE t (id INT, ts TIMESTAMP(3));
INSERT INTO t VALUES (1, TIMESTAMP '2024-03-05 14:07:09.123'), (2, NULL);

/* include t */
SELECT id, CAST(ts AS VARCHAR(30) FORMAT 'DD/MM/YYYY HH24:MI:SS.FF3') AS f FROM t;
-- ID: 1 F: 05/03/2024 14:07:09.123
-- ID: 2 F: NULL
