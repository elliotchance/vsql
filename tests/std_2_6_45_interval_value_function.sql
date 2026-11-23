-- # ABS of an interval has the type of the interval (6.45, Syntax Rules, 1).
-- # It's the interval, or its negative if it's less than zero (6.45, General
-- # Rules, 1.b and 1.c).
/* types */
VALUES ABS(INTERVAL '-1-02' YEAR TO MONTH);
VALUES ABS(INTERVAL '3 04:05' DAY TO MINUTE);
VALUES ABS(INTERVAL '0' SECOND);
VALUES ABS(-INTERVAL '90' MINUTE(3));
-- COL1: 1-02 (INTERVAL YEAR(2) TO MONTH)
-- COL1: 3 04:05 (INTERVAL DAY(2) TO MINUTE)
-- COL1: 0.000000 (INTERVAL SECOND(2, 6))
-- COL1: 90 (INTERVAL MINUTE(3))

-- # It's NULL if the interval is NULL (6.45, General Rules, 1.a).
CREATE TABLE t (x INTERVAL DAY);
INSERT INTO t (x) VALUES (NULL);
SELECT ABS(x) FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: NULL

-- # An interval value function needs F052 (6.45, Conformance Rules, 1).
/* flags */
VALUES ABS(INTERVAL '-1' DAY);
-- flags: F052, F641, F661, T441
-- COL1: 1
