/* setup */
CREATE TABLE t1 (x INT, g INT);
CREATE TABLE t2 (x INT, z INT);
CREATE TABLE t3 (w INT);
INSERT INTO t1 (x, g) VALUES (1, 1), (2, 1), (3, 2), (NULL, 2);
INSERT INTO t2 (x, z) VALUES (2, 20), (3, 30), (3, 31);

-- # A subquery without outer references has the same result for every row.
SELECT x, x IN (SELECT x FROM t2) AS i, EXISTS (SELECT * FROM t2 WHERE z > 30) AS e, (SELECT MAX(z) FROM t2) AS m, x = ANY (SELECT x FROM t2) AS a FROM t1;
-- X: 1 I: FALSE E: TRUE M: 31 A: FALSE
-- X: 2 I: TRUE E: TRUE M: 31 A: TRUE
-- X: 3 I: TRUE E: TRUE M: 31 A: TRUE
-- X: NULL I: UNKNOWN E: TRUE M: 31 A: UNKNOWN

SELECT * FROM t1 WHERE x IN (SELECT x FROM t2) AND x < (SELECT MAX(x) FROM t2);
-- X: 2 G: 1

/* extensions V202-01 V202-02 V202-03 */
SELECT x FROM t1 WHERE x * 10 >= ALL (SELECT z FROM t2 WHERE z < 30) ORDER BY (SELECT COUNT(*) FROM t3), x;
-- X: 2
-- X: 3

-- # An outer reference anywhere in the subquery, or in a subquery in it, makes
-- # it evaluated for each row.
SELECT x, (SELECT MAX(z) FROM t2 WHERE t2.x = t1.x) AS m FROM t1;
-- X: 1 M: NULL
-- X: 2 M: 20
-- X: 3 M: 31
-- X: NULL M: NULL

SELECT x, (SELECT MAX(z + t1.x) FROM t2) AS m FROM t1;
-- warning 01003: null value eliminated in set function
-- X: 1 M: 32
-- X: 2 M: 33
-- X: 3 M: 34
-- X: NULL M: NULL

SELECT x, (SELECT COUNT(*) FROM t2 JOIN t3 ON t2.x = t3.w OR t1.x = 2) AS c FROM t1;
-- X: 1 C: 0
-- X: 2 C: 0
-- X: 3 C: 0
-- X: NULL C: 0

SELECT x, (SELECT z FROM t2 ORDER BY z * t1.x DESC FETCH FIRST 1 ROW ONLY) AS z FROM t1 WHERE x IS NOT NULL;
-- X: 1 Z: 31
-- X: 2 Z: 31
-- X: 3 Z: 31

SELECT x, (SELECT COUNT(*) FROM t2 WHERE EXISTS (SELECT * FROM t3 WHERE t1.x = 3) OR z = t1.x * 10) AS c FROM t1;
-- X: 1 C: 0
-- X: 2 C: 1
-- X: 3 C: 1
-- X: NULL C: 0

SELECT x, (SELECT COUNT(*) FROM t2 WHERE z IN (SELECT t1.x * 10 FROM t3) OR z IN (SELECT z FROM t2 WHERE z = t1.x * 10)) AS c FROM t1;
-- X: 1 C: 0
-- X: 2 C: 1
-- X: 3 C: 1
-- X: NULL C: 0

-- # An uncorrelated subquery in a correlated one.
SELECT x, (SELECT COUNT(*) FROM t2 WHERE t2.x = t1.x AND z IN (SELECT MAX(z) FROM t2)) AS c FROM t1;
-- X: 1 C: 0
-- X: 2 C: 0
-- X: 3 C: 1
-- X: NULL C: 0

-- # An aggregate function of the outer query is a value of its group.
SELECT g, (SELECT MAX(t1.x) + COUNT(*) FROM t2) AS m FROM t1 GROUP BY g;
-- warning 01003: null value eliminated in set function
-- G: 1 M: 5
-- G: 2 M: 6

SELECT g, (SELECT (SELECT MAX(t1.x) FROM t3) FROM t2 FETCH FIRST 1 ROW ONLY) AS m FROM t1 GROUP BY g;
-- warning 01003: null value eliminated in set function
-- G: 1 M: NULL
-- G: 2 M: NULL

-- # Each statement evaluates it again.
SELECT x FROM t1 WHERE x IN (SELECT w FROM t3);
INSERT INTO t3 (w) VALUES (1);
SELECT x FROM t1 WHERE x IN (SELECT w FROM t3);
SELECT x, (SELECT COUNT(*) FROM t2 JOIN t3 ON t2.x = t3.w OR t1.x = 2) AS c FROM t1;
-- msg: INSERT 1
-- X: 1
-- X: 1 C: 0
-- X: 2 C: 3
-- X: 3 C: 0
-- X: NULL C: 0

-- # Changes are made after the subquery is evaluated for every row.
UPDATE t1 SET x = (SELECT MAX(x) FROM t1) + x WHERE x < (SELECT AVG(x) FROM t1);
SELECT * FROM t1;
-- warning 01003: null value eliminated in set function
-- warning 01003: null value eliminated in set function
-- msg: UPDATE 1
-- X: 4 G: 1
-- X: 2 G: 1
-- X: 3 G: 2
-- X: NULL G: 2

INSERT INTO t3 (w) VALUES (1);
INSERT INTO t3 (w) SELECT (SELECT COUNT(*) FROM t3) FROM t2;
DELETE FROM t3 WHERE w = (SELECT COUNT(*) FROM t3) - 3;
SELECT * FROM t3;
-- msg: INSERT 1
-- msg: INSERT 3
-- msg: DELETE 4
