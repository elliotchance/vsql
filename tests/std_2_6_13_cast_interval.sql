-- # An interval cast to a character string is its literal, with the sign in
-- # the string (6.13, General Rules, 11.e.i.2 and 12.e.i.2).
/* types */
VALUES CAST(INTERVAL '-1-02' YEAR TO MONTH AS VARCHAR(50));
VALUES CAST(INTERVAL '3 04:05:06.5' DAY TO SECOND(1) AS CHARACTER(50));
-- COL1: INTERVAL '-1-02' YEAR(2) TO MONTH (CHARACTER VARYING(50))
-- COL1: INTERVAL '3 04:05:06.5' DAY(2) TO SECOND(1)        (CHARACTER(50))

VALUES CAST(INTERVAL '1' DAY AS VARCHAR(5));
-- error 22001: string data right truncation for CHARACTER VARYING(5)

-- # A character string cast to an interval is an unquoted interval string of
-- # the type, or an interval literal whose value can be cast to the type, once
-- # the spaces around it are removed (6.13, General Rules, 20.b and 20.b.i).
/* types */
VALUES CAST(' 1-02 ' AS INTERVAL YEAR TO MONTH);
VALUES CAST('-3 04' AS INTERVAL DAY TO HOUR);
VALUES CAST('INTERVAL -''3'' month' AS INTERVAL YEAR TO MONTH);
VALUES CAST('interval ''25'' hour(3)' AS INTERVAL DAY TO HOUR);
VALUES CAST('INTERVAL ''1.25'' SECOND(2, 1)' AS INTERVAL SECOND(2, 2));
VALUES CAST('INTERVAL ''1:30'' HOUR TO MINUTE' AS INTERVAL MINUTE(3));
-- COL1: 1-02 (INTERVAL YEAR(2) TO MONTH)
-- COL1: -3 04 (INTERVAL DAY(2) TO HOUR)
-- COL1: -0-03 (INTERVAL YEAR(2) TO MONTH)
-- COL1: 1 01 (INTERVAL DAY(2) TO HOUR)
-- COL1: 1.20 (INTERVAL SECOND(2, 2))
-- COL1: 90 (INTERVAL MINUTE(3))

-- # Otherwise, it's 22006 (invalid interval format) (6.13, General Rules,
-- # 20.b.ii).
VALUES CAST('x' AS INTERVAL YEAR TO MONTH);
VALUES CAST('1' AS INTERVAL YEAR TO MONTH);
VALUES CAST('100' AS INTERVAL DAY);
VALUES CAST('INTERVAL ''1'' DAY' AS INTERVAL YEAR);
VALUES CAST('INTERVAL ''1'' FORTNIGHT' AS INTERVAL DAY);
VALUES CAST('INTERVAL ''1' AS INTERVAL DAY);
VALUES CAST('INTERVAL 1 DAY' AS INTERVAL DAY);
VALUES CAST('INTERVAL ''1'' DAY TO MONTH' AS INTERVAL DAY);
VALUES CAST('INTERVAL ''1'' DAY(2) TO HOUR(3)' AS INTERVAL DAY);
VALUES CAST('INTERVAL ''1'' DAY(2, 3)' AS INTERVAL DAY);
VALUES CAST('INTERVAL ''1'' DAY(x)' AS INTERVAL DAY);
VALUES CAST('INTERVAL ''1'' DAY(2' AS INTERVAL DAY);
VALUES CAST('INTERVAL ''1'' DAY TO HOUR TO MINUTE' AS INTERVAL DAY);
VALUES CAST('INTERVAL ''1'' SECOND(1, 2, 3)' AS INTERVAL DAY);
VALUES CAST('INTERVAL ''1'' DAY(9)' AS INTERVAL DAY);
VALUES CAST('INTERVAL ''1'' DAY TO SECOND(1, 2)' AS INTERVAL DAY);
VALUES CAST('INTERVAL ''1'' DAY(2) TO HOUR' AS INTERVAL DAY);
-- error 22006: invalid interval format
-- error 22006: invalid interval format
-- error 22006: invalid interval format
-- error 22006: invalid interval format
-- error 22006: invalid interval format
-- error 22006: invalid interval format
-- error 22006: invalid interval format
-- error 22006: invalid interval format
-- error 22006: invalid interval format
-- error 22006: invalid interval format
-- error 22006: invalid interval format
-- error 22006: invalid interval format
-- error 22006: invalid interval format
-- error 22006: invalid interval format
-- error 22006: invalid interval format
-- error 22006: invalid interval format
-- error 22006: invalid interval format

-- # The value of an interval literal must still fit in the type.
VALUES CAST('INTERVAL ''100'' HOUR(3)' AS INTERVAL HOUR);
-- error 22015: interval field overflow

-- # An exact numeric cast to an interval with one field is a number of that
-- # field. Digits after the fractional seconds precision (or a fraction of
-- # another field) are truncated, and it's 22015 (interval field overflow) if
-- # there are too many digits in the leading field (6.13, Syntax Rules, 8, and
-- # General Rules, 20.a).
/* types */
VALUES CAST(90 AS INTERVAL MINUTE);
VALUES CAST(-3 AS INTERVAL YEAR);
VALUES CAST(1.2345678 AS INTERVAL SECOND(3, 2));
VALUES CAST(1.9 AS INTERVAL DAY);
VALUES CAST(CAST(15 AS BIGINT) AS INTERVAL MONTH);
-- COL1: 90 (INTERVAL MINUTE(2))
-- COL1: -3 (INTERVAL YEAR(2))
-- COL1: 1.23 (INTERVAL SECOND(3, 2))
-- COL1: 1 (INTERVAL DAY(2))
-- COL1: 15 (INTERVAL MONTH(2))

VALUES CAST(100 AS INTERVAL DAY);
VALUES CAST(1 AS INTERVAL DAY TO HOUR);
VALUES CAST(1.5e0 AS INTERVAL DAY);
-- error 22015: interval field overflow
-- error 42846: cannot coerce INTEGER to INTERVAL DAY(2) TO HOUR
-- error 42846: cannot coerce DOUBLE PRECISION to INTERVAL DAY(2)

-- # An interval with one field cast to an exact numeric is a number of that
-- # field, and it's 22003 (numeric value out of range) if it doesn't fit (6.13,
-- # Syntax Rules, 9, and General Rules, 8.c).
/* types */
VALUES CAST(INTERVAL '90' MINUTE AS INTEGER);
VALUES CAST(INTERVAL '-1.5' SECOND AS NUMERIC(10, 2));
VALUES CAST(INTERVAL '3' YEAR AS BIGINT);
VALUES CAST(INTERVAL '14' MONTH AS DECIMAL(4, 1));
VALUES CAST(INTERVAL '5' SECOND(2, 0) AS SMALLINT);
-- COL1: 90 (INTEGER)
-- COL1: -1.50 (NUMERIC(10, 2))
-- COL1: 3 (BIGINT)
-- COL1: 14.0 (DECIMAL(4, 1))
-- COL1: 5 (SMALLINT)

VALUES CAST(INTERVAL '99999999' DAY(8) AS SMALLINT);
VALUES CAST(INTERVAL '1-02' YEAR TO MONTH AS INTEGER);
VALUES CAST(INTERVAL '1' DAY AS DOUBLE PRECISION);
VALUES CAST(INTERVAL '1' DAY AS BOOLEAN);
VALUES CAST(INTERVAL '1' DAY AS DATE);
-- error 22003: numeric value out of range
-- error 42846: cannot coerce INTERVAL YEAR(2) TO MONTH to INTEGER
-- error 42846: cannot coerce INTERVAL DAY(2) to DOUBLE PRECISION
-- error 42846: cannot coerce INTERVAL DAY(2) to BOOLEAN
-- error 42846: cannot coerce INTERVAL DAY(2) to DATE
