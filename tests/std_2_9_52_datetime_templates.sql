-- # A <datetime template> is the FORMAT of a CAST between a datetime and a
-- # character string (T839). It's made of fields and delimiters.
/* flags */
/* types */
VALUES CAST(TIMESTAMP '2024-03-05 14:07:09' AS VARCHAR(16) FORMAT 'YYYY-MM-DD HH24:MI');
-- flags: F641, F661, T839
-- COL1: 2024-03-05 14:07 (CHARACTER VARYING(16))

-- # Every delimiter: - . / , ' ; : and space.
VALUES CAST(TIMESTAMP '2024-03-05 14:07:09' AS VARCHAR(30) FORMAT 'YYYY-MM.DD/HH24,MI''SS;');
VALUES CAST(TIME '14:07:09' AS VARCHAR(30) FORMAT ':HH24 MI');
-- COL1: 2024-03.05/14,07'09;
-- COL1: :14 07

-- # A fraction of more than 6 digits is F555, and a time zone is F411.
/* flags */
VALUES CAST(TIME '14:07:09.123456' AS VARCHAR(20) FORMAT 'HH24:MI:SS.FF9');
-- flags: F555, F641, F661, T839
-- COL1: 14:07:09.123456000

/* flags */
VALUES CAST(TIMESTAMP '2024-03-05 14:07:09+05:30' AS VARCHAR(20) FORMAT 'YYYY TZH:TZM');
-- flags: F411, F641, F661, T839
-- COL1: 2024 +05:30

-- # The fields are upper case.
VALUES CAST(DATE '2024-03-05' AS VARCHAR(10) FORMAT 'yyyy');
VALUES CAST(DATE '2024-03-05' AS VARCHAR(10) FORMAT 'YYYY-Mm');
-- error 42601: syntax error: invalid datetime template 'yyyy': unknown field at "yyyy"
-- error 42601: syntax error: invalid datetime template 'YYYY-Mm': unknown field at "Mm"

-- # Anything else isn't a field or delimiter.
VALUES CAST(DATE '2024-03-05' AS VARCHAR(10) FORMAT '');
VALUES CAST(DATE '2024-03-05' AS VARCHAR(10) FORMAT 'YYYY_MM');
VALUES CAST(TIME '14:07:09' AS VARCHAR(10) FORMAT 'FF');
VALUES CAST(TIME '14:07:09' AS VARCHAR(10) FORMAT 'AM');
-- error 42601: syntax error: invalid datetime template '': it is empty
-- error 42601: syntax error: invalid datetime template 'YYYY_MM': unknown field at "_MM"
-- error 42601: syntax error: invalid datetime template 'FF': unknown field at "FF"
-- error 42601: syntax error: invalid datetime template 'AM': unknown field at "AM"

-- # Two delimiters can't be next to each other.
VALUES CAST(DATE '2024-03-05' AS VARCHAR(10) FORMAT 'YYYY--MM');
VALUES CAST(DATE '2024-03-05' AS VARCHAR(10) FORMAT 'YYYY- MM');
-- error 42601: syntax error: invalid datetime template 'YYYY--MM': two delimiters cannot be next to each other
-- error 42601: syntax error: invalid datetime template 'YYYY- MM': two delimiters cannot be next to each other

-- # Each field can only be used once.
VALUES CAST(DATE '2024-03-05' AS VARCHAR(10) FORMAT 'YYYY YY');
VALUES CAST(DATE '2024-03-05' AS VARCHAR(10) FORMAT 'RR RR');
VALUES CAST(DATE '2024-03-05' AS VARCHAR(10) FORMAT 'MM MM');
VALUES CAST(DATE '2024-03-05' AS VARCHAR(10) FORMAT 'DD DD');
VALUES CAST(DATE '2024-03-05' AS VARCHAR(10) FORMAT 'DDD DDD');
VALUES CAST(TIME '14:07:09' AS VARCHAR(10) FORMAT 'HH HH12 A.M.');
VALUES CAST(TIME '14:07:09' AS VARCHAR(10) FORMAT 'HH24 HH24');
VALUES CAST(TIME '14:07:09' AS VARCHAR(10) FORMAT 'MI MI');
VALUES CAST(TIME '14:07:09' AS VARCHAR(10) FORMAT 'SS SS');
VALUES CAST(TIME '14:07:09' AS VARCHAR(20) FORMAT 'SSSSS SSSSS');
VALUES CAST(TIME '14:07:09' AS VARCHAR(10) FORMAT 'FF1 FF2');
VALUES CAST(TIME '14:07:09' AS VARCHAR(20) FORMAT 'HH A.M. P.M.');
VALUES CAST(TIMESTAMP '2024-03-05 14:07:09+05:30' AS VARCHAR(10) FORMAT 'TZH TZH');
VALUES CAST(TIMESTAMP '2024-03-05 14:07:09+05:30' AS VARCHAR(10) FORMAT 'TZH TZM TZM');
-- error 42601: syntax error: invalid datetime template 'YYYY YY': the year field can only be used once
-- error 42601: syntax error: invalid datetime template 'RR RR': the rounded year field can only be used once
-- error 42601: syntax error: invalid datetime template 'MM MM': the month field can only be used once
-- error 42601: syntax error: invalid datetime template 'DD DD': the day of month field can only be used once
-- error 42601: syntax error: invalid datetime template 'DDD DDD': the day of year field can only be used once
-- error 42601: syntax error: invalid datetime template 'HH HH12 A.M.': the 12-hour field can only be used once
-- error 42601: syntax error: invalid datetime template 'HH24 HH24': the 24-hour field can only be used once
-- error 42601: syntax error: invalid datetime template 'MI MI': the minute field can only be used once
-- error 42601: syntax error: invalid datetime template 'SS SS': the second of minute field can only be used once
-- error 42601: syntax error: invalid datetime template 'SSSSS SSSSS': the second of day field can only be used once
-- error 42601: syntax error: invalid datetime template 'FF1 FF2': the fraction field can only be used once
-- error 42601: syntax error: invalid datetime template 'HH A.M. P.M.': the am/pm field can only be used once
-- error 42601: syntax error: invalid datetime template 'TZH TZH': the time zone hour field can only be used once
-- error 42601: syntax error: invalid datetime template 'TZH TZM TZM': the time zone minute field can only be used once

-- # Fields that can't be used together.
VALUES CAST(DATE '2024-03-05' AS VARCHAR(10) FORMAT 'YYYY RR');
VALUES CAST(DATE '2024-03-05' AS VARCHAR(10) FORMAT 'YYYY DDD MM');
VALUES CAST(DATE '2024-03-05' AS VARCHAR(10) FORMAT 'YYYY DD DDD');
VALUES CAST(TIME '14:07:09' AS VARCHAR(10) FORMAT 'HH24 HH');
VALUES CAST(TIME '14:07:09' AS VARCHAR(10) FORMAT 'HH24 A.M.');
VALUES CAST(TIME '14:07:09' AS VARCHAR(10) FORMAT 'HH12:MI');
VALUES CAST(TIME '14:07:09' AS VARCHAR(10) FORMAT 'MI A.M.');
VALUES CAST(TIME '14:07:09' AS VARCHAR(10) FORMAT 'SSSSS MI');
VALUES CAST(TIME '14:07:09' AS VARCHAR(10) FORMAT 'SSSSS SS');
VALUES CAST(TIME '14:07:09' AS VARCHAR(20) FORMAT 'SSSSS HH24');
VALUES CAST(TIME '14:07:09' AS VARCHAR(20) FORMAT 'SSSSS HH A.M.');
VALUES CAST(TIMESTAMP '2024-03-05 14:07:09+05:30' AS VARCHAR(10) FORMAT 'YYYY TZM');
-- error 42601: syntax error: invalid datetime template 'YYYY RR': cannot have both a year and a rounded year
-- error 42601: syntax error: invalid datetime template 'YYYY DDD MM': cannot have both a day of year and a month or day of month
-- error 42601: syntax error: invalid datetime template 'YYYY DD DDD': cannot have both a day of year and a month or day of month
-- error 42601: syntax error: invalid datetime template 'HH24 HH': cannot have both a 24-hour and a 12-hour or am/pm
-- error 42601: syntax error: invalid datetime template 'HH24 A.M.': cannot have both a 24-hour and a 12-hour or am/pm
-- error 42601: syntax error: invalid datetime template 'HH12:MI': a 12-hour must be used with an am/pm
-- error 42601: syntax error: invalid datetime template 'MI A.M.': a 12-hour must be used with an am/pm
-- error 42601: syntax error: invalid datetime template 'SSSSS MI': cannot have both a second of day and an hour, minute or second of minute
-- error 42601: syntax error: invalid datetime template 'SSSSS SS': cannot have both a second of day and an hour, minute or second of minute
-- error 42601: syntax error: invalid datetime template 'SSSSS HH24': cannot have both a second of day and an hour, minute or second of minute
-- error 42601: syntax error: invalid datetime template 'SSSSS HH A.M.': cannot have both a second of day and an hour, minute or second of minute
-- error 42601: syntax error: invalid datetime template 'YYYY TZM': a time zone minute must be used with a time zone hour

-- # The fields that can be used depend on the datetime type.
VALUES CAST(DATE '2024-03-05' AS VARCHAR(10) FORMAT 'HH24');
VALUES CAST(DATE '2024-03-05' AS VARCHAR(10) FORMAT 'TZH');
VALUES CAST(TIME '14:07:09' AS VARCHAR(10) FORMAT 'YYYY');
VALUES CAST(TIME '14:07:09' AS VARCHAR(10) FORMAT 'TZH');
VALUES CAST(TIME '14:07:09+05:00' AS VARCHAR(10) FORMAT 'DDD');
VALUES CAST(TIMESTAMP '2024-03-05 14:07:09' AS VARCHAR(10) FORMAT 'TZH');
VALUES CAST(TIMESTAMP '2024-03-05 14:07:09' AS VARCHAR(10) FORMAT 'TZH:TZM');
-- error 42601: syntax error: invalid datetime template 'HH24': HH24 cannot be used with DATE
-- error 42601: syntax error: invalid datetime template 'TZH': TZH cannot be used with DATE
-- error 42601: syntax error: invalid datetime template 'YYYY': YYYY cannot be used with TIME(0) WITHOUT TIME ZONE
-- error 42601: syntax error: invalid datetime template 'TZH': TZH cannot be used with TIME(0) WITHOUT TIME ZONE
-- error 42601: syntax error: invalid datetime template 'DDD': DDD cannot be used with TIME(0) WITH TIME ZONE
-- error 42601: syntax error: invalid datetime template 'TZH': TZH cannot be used with TIMESTAMP(0) WITHOUT TIME ZONE
-- error 42601: syntax error: invalid datetime template 'TZH:TZM': TZH cannot be used with TIMESTAMP(0) WITHOUT TIME ZONE

-- # Every field can be used with a TIMESTAMP WITH TIME ZONE.
VALUES CAST(TIMESTAMP '2024-03-05 14:07:09.5+05:30' AS VARCHAR(40) FORMAT 'YYYY-MM-DD HH:MI:SS.FF1 P.M. TZH:TZM');
-- COL1: 2024-03-05 02:07:09.5 P.M. +05:30

-- # The template must fit in the character string type, with each delimited
-- # field (between delimiters) as short as 1 digit. 'YYYY-MM' is at least 3
-- # characters.
VALUES CAST(DATE '2024-03-05' AS VARCHAR(2) FORMAT 'YYYY-MM');
VALUES CAST(CAST('2024-3' AS VARCHAR(2)) AS DATE FORMAT 'YYYY-MM');
-- error 42601: syntax error: invalid datetime template 'YYYY-MM': CHARACTER VARYING(2) is shorter than the template (3)
-- error 42601: syntax error: invalid datetime template 'YYYY-MM': CHARACTER VARYING(2) is shorter than the template (3)

-- # Fields that aren't delimited must be their full length, so 'YYYYMM' is at
-- # least 6 characters.
VALUES CAST(DATE '2024-03-05' AS CHAR(5) FORMAT 'YYYYMM');
VALUES CAST(DATE '2024-03-05' AS CHAR(6) FORMAT 'YYYYMM');
-- error 42601: syntax error: invalid datetime template 'YYYYMM': CHARACTER(5) is shorter than the template (6)
-- COL1: 202403

-- # A time zone hour is always a sign and at least 1 digit.
VALUES CAST(TIME '14:07:09+05:00' AS VARCHAR(1) FORMAT 'TZH');
VALUES CAST(TIME '14:07:09+05:00' AS VARCHAR(2) FORMAT 'TZH');
-- error 42601: syntax error: invalid datetime template 'TZH': CHARACTER VARYING(1) is shorter than the template (2)
-- error 22001: string data right truncation for CHARACTER VARYING(2)

-- # A cast template can only be used between a datetime and a character
-- # string.
VALUES CAST(1 AS VARCHAR(10) FORMAT 'YYYY');
VALUES CAST('2024' AS INT FORMAT 'YYYY');
VALUES CAST(DATE '2024-03-05' AS TIMESTAMP FORMAT 'YYYY');
VALUES CAST('2024' AS VARCHAR(10) FORMAT 'YYYY');
VALUES CAST(NULL AS DATE FORMAT 'YYYY');
-- error 42601: syntax error: CAST from INTEGER to CHARACTER VARYING(10) cannot have a FORMAT
-- error 42601: syntax error: CAST from CHARACTER(4) to INTEGER cannot have a FORMAT
-- error 42601: syntax error: CAST from DATE to TIMESTAMP(6) WITHOUT TIME ZONE cannot have a FORMAT
-- error 42601: syntax error: CAST from CHARACTER(4) to CHARACTER VARYING(10) cannot have a FORMAT
-- error 42601: syntax error: NULL cannot be cast with a FORMAT

-- # The template is a character string literal.
VALUES CAST(DATE '2024-03-05' AS VARCHAR(10) FORMAT 'YY' || 'YY');
-- error 42601: syntax error: unexpected "||" at line 1, column 58 near ") FORMAT 'YY' || 'YY'", expecting ")"
