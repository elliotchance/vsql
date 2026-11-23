/* setup */
CREATE TABLE t (g INT, x INTERVAL DAY TO SECOND(1), y INTERVAL YEAR(4) TO MONTH);
INSERT INTO t (g, x, y) VALUES (1, INTERVAL '1' DAY, INTERVAL '1-01' YEAR TO MONTH), (1, INTERVAL '2 12' DAY TO HOUR, INTERVAL '-0-02' YEAR TO MONTH), (1, NULL, NULL), (2, INTERVAL '0.5' SECOND, INTERVAL '9999-11' YEAR(4) TO MONTH), (2, INTERVAL '0.25' SECOND(1, 2), INTERVAL '9999-11' YEAR(4) TO MONTH);

-- # The SUM of intervals has the same fields, and the maximum leading field
-- # precision (10.9, Syntax Rules, 7.g.vi). The AVG has the type of the
-- # interval (10.9, Syntax Rules, 12.e.iii), and it's truncated to the least
-- # significant field.
/* types */
SELECT g, SUM(x), AVG(x), MIN(x), MAX(x) FROM t GROUP BY g ORDER BY g;
-- warning 01003: null value eliminated in set function
-- G: 1 (INTEGER) COL2: 3 12:00:00.0 (INTERVAL DAY(8) TO SECOND(1)) COL3: 1 18:00:00.0 (INTERVAL DAY(2) TO SECOND(1)) COL4: 1 00:00:00.0 (INTERVAL DAY(2) TO SECOND(1)) COL5: 2 12:00:00.0 (INTERVAL DAY(2) TO SECOND(1))
-- G: 2 (INTEGER) COL2: 0 00:00:00.7 (INTERVAL DAY(8) TO SECOND(1)) COL3: 0 00:00:00.3 (INTERVAL DAY(2) TO SECOND(1)) COL4: 0 00:00:00.2 (INTERVAL DAY(2) TO SECOND(1)) COL5: 0 00:00:00.5 (INTERVAL DAY(2) TO SECOND(1))

/* types */
SELECT g, SUM(y), AVG(y) FROM t GROUP BY g ORDER BY g;
-- warning 01003: null value eliminated in set function
-- G: 1 (INTEGER) COL2: 0-11 (INTERVAL YEAR(8) TO MONTH) COL3: 0-05 (INTERVAL YEAR(4) TO MONTH)
-- G: 2 (INTEGER) COL2: 19999-10 (INTERVAL YEAR(8) TO MONTH) COL3: 9999-11 (INTERVAL YEAR(4) TO MONTH)

-- # A SUM or AVG of no values is NULL.
SELECT SUM(x), AVG(y) FROM t WHERE x IS NULL;
-- warning 01003: null value eliminated in set function
-- COL1: NULL COL2: NULL

-- # It's 2200P (interval value out of range) if the sum doesn't fit (10.9,
-- # General Rules, 3.a).
CREATE TABLE big (x INTERVAL DAY(8));
INSERT INTO big (x) VALUES (INTERVAL '99999999' DAY(8)), (INTERVAL '1' DAY);
SELECT SUM(x) FROM big;
SELECT AVG(x) FROM big;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- error 2200P: interval value out of range
-- COL1: 50000000

-- # Even when the sum is too big for any interval, but the average isn't.
CREATE TABLE huge (x INTERVAL DAY(8));
INSERT INTO huge (x) VALUES (INTERVAL '-99999999' DAY(8)), (INTERVAL '-99999999' DAY(8)), (INTERVAL '-99999999' DAY(8));
SELECT SUM(x) FROM huge;
SELECT AVG(x) FROM huge;
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- error 2200P: interval value out of range
-- COL1: -99999999
