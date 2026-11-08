/* setup */
CREATE TABLE t (g INT, n NUMERIC(5, 2), d DOUBLE PRECISION, c CHARACTER(3), v VARCHAR(10), tz TIME(0) WITH TIME ZONE, b BOOLEAN, s SMALLINT, i INT);
INSERT INTO t (g, n, d, c, v, tz, b, s, i) VALUES (1, 1.5, 0e0, 'a', 'a', TIME '12:00:00+05:00', TRUE, 1, 1);
INSERT INTO t (g, n, d, c, v, tz, b, s, i) VALUES (1, 1.50, -0e0, 'a  ', 'a ', TIME '07:00:00+00:00', TRUE, 2, 2);
INSERT INTO t (g, n, d, c, v, tz, b, s, i) VALUES (1, -1.5, 1.5e0, 'b', 'a  ', TIME '07:00:00+01:00', FALSE, 3, 4);
INSERT INTO t (g, n, d, c, v, tz, b, s, i) VALUES (2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO t (g, n, d, c, v, tz, b, s, i) VALUES (2, 0.00, 2e0, 'A', 'A', TIME '00:00:00+00:00', FALSE, 4, 3);
INSERT INTO t (g, n, d, c, v, tz, b, s, i) VALUES (2, 0, 2e0, 'A', 'a', TIME '00:00:00+00:00', FALSE, 4, 3);

-- # Values that are equal with = are the same value.
SELECT COUNT(DISTINCT n), SUM(DISTINCT n), COUNT(DISTINCT d), COUNT(DISTINCT c), COUNT(DISTINCT v), COUNT(DISTINCT tz), COUNT(DISTINCT b) FROM t;
-- warning 01003: null value eliminated in set function
-- COL1: 3 COL2: 0.00 COL3: 3 COL4: 3 COL5: 2 COL6: 3 COL7: 2

SELECT g, COUNT(DISTINCT n), COUNT(DISTINCT v), COUNT(DISTINCT tz), COUNT(DISTINCT b) FROM t GROUP BY g;
-- warning 01003: null value eliminated in set function
-- G: 1 COL2: 2 COL3: 1 COL4: 2 COL5: 2
-- G: 2 COL2: 1 COL3: 2 COL4: 1 COL5: 1

-- # Each value is cast to the type of the argument, so values of different
-- # types are the same value if they're equal.
SELECT COUNT(DISTINCT CASE WHEN g = 1 THEN s ELSE i END), SUM(DISTINCT CASE WHEN g = 1 THEN s ELSE i END) FROM t;
-- warning 01003: null value eliminated in set function
-- COL1: 3 COL2: 6

SELECT COUNT(DISTINCT CASE WHEN g = 1 THEN n ELSE d END), COUNT(DISTINCT COALESCE(s, 1.50)) FROM t;
-- warning 01003: null value eliminated in set function
-- COL1: 3 COL2: 5

-- # The first of the duplicates is kept.
SELECT MIN(DISTINCT v), MAX(DISTINCT v), MIN(DISTINCT c) FROM t WHERE g = 1;
-- COL1: a COL2: a COL3: a
