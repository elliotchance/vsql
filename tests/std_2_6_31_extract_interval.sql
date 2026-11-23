-- # EXTRACT of a field of an interval is that field, with the sign of the
-- # interval (6.31, General Rules, 4.a). The start field is the whole number of
-- # that field, and the other fields are less than the field before them. The
-- # result is an INTEGER, except for SECOND, which has the fractional seconds
-- # precision of the interval as its scale (6.31, Syntax Rules, 7.a and 7.b).
/* types */
VALUES EXTRACT(YEAR FROM INTERVAL '-1-02' YEAR TO MONTH);
VALUES EXTRACT(MONTH FROM INTERVAL '-1-02' YEAR TO MONTH);
VALUES EXTRACT(MONTH FROM INTERVAL '30' MONTH);
VALUES EXTRACT(DAY FROM INTERVAL '-1 02:03:04.5' DAY TO SECOND);
VALUES EXTRACT(HOUR FROM INTERVAL '-1 02:03:04.5' DAY TO SECOND);
VALUES EXTRACT(MINUTE FROM INTERVAL '-1 02:03:04.5' DAY TO SECOND);
VALUES EXTRACT(SECOND FROM INTERVAL '-1 02:03:04.5' DAY TO SECOND);
VALUES EXTRACT(HOUR FROM INTERVAL '30' HOUR);
VALUES EXTRACT(MINUTE FROM INTERVAL '30:15' HOUR TO MINUTE);
VALUES EXTRACT(SECOND FROM INTERVAL '125.5' SECOND(3, 1));
VALUES EXTRACT(SECOND FROM INTERVAL '2:05' MINUTE TO SECOND(0));
-- COL1: -1 (INTEGER)
-- COL1: -2 (INTEGER)
-- COL1: 30 (INTEGER)
-- COL1: -1 (INTEGER)
-- COL1: -2 (INTEGER)
-- COL1: -3 (INTEGER)
-- COL1: -4.500000 (NUMERIC(8, 6))
-- COL1: 30 (INTEGER)
-- COL1: 15 (INTEGER)
-- COL1: 125.5 (NUMERIC(4, 1))
-- COL1: 5 (NUMERIC(2))

-- # The field must be one of the fields of the interval (6.31, Syntax Rules,
-- # 6.a), and a time zone field or a field that isn't a primary datetime field
-- # can't be extracted from an interval.
/* extensions V402-02 */
VALUES EXTRACT(YEAR FROM INTERVAL '30' HOUR);
VALUES EXTRACT(SECOND FROM INTERVAL '1 02' DAY TO HOUR);
VALUES EXTRACT(TIMEZONE_HOUR FROM INTERVAL '1' HOUR);
VALUES EXTRACT(DOW FROM INTERVAL '1' DAY);
-- error 42804: data type mismatch in EXTRACT(YEAR FROM ...): expected an interval with YEAR but got INTERVAL HOUR(2)
-- error 42804: data type mismatch in EXTRACT(SECOND FROM ...): expected an interval with SECOND but got INTERVAL DAY(2) TO HOUR
-- error 42804: data type mismatch in EXTRACT(TIMEZONE_HOUR FROM ...): expected TIME WITH TIME ZONE or TIMESTAMP WITH TIME ZONE but got INTERVAL HOUR(2)
-- error 42804: data type mismatch in EXTRACT(DOW FROM ...): expected DATE or TIMESTAMP but got INTERVAL DAY(2)

-- # It's NULL if the interval is NULL.
CREATE TABLE t (x INTERVAL DAY);
INSERT INTO t (x) VALUES (NULL);
SELECT EXTRACT(DAY FROM x) FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: NULL
