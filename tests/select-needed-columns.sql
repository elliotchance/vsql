-- # Only the columns that a query uses are read from each row (see
-- # Plan.needed_columns), so the others must be skipped over correctly. X is
-- # after a column of every type, which are values in one row and NULL in
-- # another.

/* setup */
CREATE TABLE t (b BOOLEAN, si SMALLINT, i INT, bi BIGINT, r REAL, d DOUBLE PRECISION, n NUMERIC(10, 2), de DECIMAL(5, 1), c CHAR(3), vc VARCHAR(5), dt DATE, tm TIME, tmz TIME WITH TIME ZONE, ts TIMESTAMP, tsz TIMESTAMP WITH TIME ZONE, x INT);
INSERT INTO t VALUES (TRUE, 1, 2, 3, 1.5, -2.5, 12.34, -0.5, 'ab', 'a b', DATE '2022-07-04', TIME '12:34:56', TIME '12:34:56+05:00', TIMESTAMP '2022-07-04 12:34:56', TIMESTAMP '2022-07-04 12:34:56+05:00', 1);
INSERT INTO t (x) VALUES (2);

SELECT x FROM t;
-- X: 1
-- X: 2

SELECT x, vc FROM t WHERE x = 1;
-- X: 1 VC: a b

SELECT x * 10 AS y FROM t WHERE tsz IS NULL;
-- Y: 20

-- # A correlation name and a subquery read every column.
SELECT a.x FROM t AS a WHERE a.n IS NOT NULL;
-- X: 1

SELECT x FROM t WHERE x = (SELECT MAX(x) FROM t);
-- X: 2
