/* setup */
CREATE TABLE t1 (x INT, y VARCHAR(10));
CREATE TABLE t2 (x INT, z INT);
CREATE TABLE t3 (w INT);
INSERT INTO t1 (x, y) VALUES (1, 'a'), (2, 'b'), (3, 'b'), (NULL, 'c');
INSERT INTO t2 (x, z) VALUES (2, 20), (3, 30), (3, 31);

-- # A subquery can refer to the columns of the query that contains it (E061-13).
SELECT * FROM t1 WHERE EXISTS (SELECT * FROM t2 WHERE t2.x = t1.x);
-- X: 2 Y: b
-- X: 3 Y: b

SELECT * FROM t1 WHERE NOT EXISTS (SELECT * FROM t2 WHERE t2.x = t1.x);
-- X: 1 Y: a
-- X: NULL Y: c

SELECT x, (SELECT MAX(z) FROM t2 WHERE t2.x = t1.x) AS m FROM t1;
-- X: 1 M: NULL
-- X: 2 M: 20
-- X: 3 M: 31
-- X: NULL M: NULL

SELECT y FROM t1 WHERE (SELECT COUNT(*) FROM t2 WHERE t2.x = t1.x) > 1;
-- Y: b

SELECT * FROM t1 WHERE 25 IN (SELECT z - 5 * t1.x FROM t2);
-- X: 1 Y: a

-- # ALL is TRUE when there are no rows, even for a NULL.
SELECT * FROM t1 WHERE x * 10 >= ALL (SELECT z FROM t2 WHERE t2.x = t1.x);
-- X: 1 Y: a
-- X: 2 Y: b
-- X: NULL Y: c

SELECT * FROM t1 WHERE 30 = ANY (SELECT z FROM t2 WHERE t2.x = t1.x);
-- X: 3 Y: b

-- # An unqualified column is in the innermost query that has it.
SELECT y FROM t1 WHERE EXISTS (SELECT * FROM t2 WHERE z = x * 10);
-- Y: a
-- Y: b
-- Y: b
-- Y: c

SELECT x FROM t1 WHERE EXISTS (SELECT * FROM t3 WHERE x = 2);
SELECT x FROM t1 WHERE EXISTS (SELECT * FROM t2 WHERE y = 'a');
-- X: 1

-- # A column of the outer query can be ambiguous.
SELECT * FROM t1 INNER JOIN t2 ON t1.x = t2.x WHERE EXISTS (SELECT * FROM t3 WHERE x = 2);
-- error 42702: ambiguous column: X

-- # A correlation name can tell the same table apart.
SELECT * FROM t1 AS a WHERE EXISTS (SELECT * FROM t1 AS b WHERE b.x = a.x + 1);
-- X: 1 Y: a
-- X: 2 Y: b

SELECT * FROM t1 AS a WHERE (SELECT COUNT(*) FROM t1 AS b WHERE b.y = a.y) > 1;
-- X: 2 Y: b
-- X: 3 Y: b

-- # The same table without a correlation name is the inner one.
SELECT x FROM t1 WHERE EXISTS (SELECT * FROM t1 WHERE t1.x = 3);
-- X: 1
-- X: 2
-- X: 3
-- X: NULL

-- # A subquery can refer to any query that contains it.
SELECT * FROM t1 WHERE EXISTS (SELECT * FROM t2 WHERE EXISTS (SELECT * FROM t2 AS q WHERE q.z = t2.z + 1 AND q.x = t1.x));
-- X: 3 Y: b

SELECT * FROM t1 WHERE EXISTS (SELECT * FROM (SELECT x FROM t2 WHERE t2.x = t1.x) AS q);
-- X: 2 Y: b
-- X: 3 Y: b

SELECT x, (VALUES t1.x + 1) AS n FROM t1;
-- X: 1 N: 2
-- X: 2 N: 3
-- X: 3 N: 4
-- X: NULL N: NULL

SELECT * FROM t1 WHERE x IN (SELECT z / 10 FROM t2 WHERE t2.x = t1.x UNION VALUES t1.x - 1);
-- X: 2 Y: b
-- X: 3 Y: b

SELECT x, CASE WHEN EXISTS (SELECT * FROM t2 WHERE t2.x = t1.x) THEN 'yes' ELSE 'no' END AS e FROM t1;
-- X: 1 E: no
-- X: 2 E: yes
-- X: 3 E: yes
-- X: NULL E: no

SELECT x FROM t1 ORDER BY (SELECT COUNT(*) FROM t2 WHERE t2.x = t1.x) DESC, x;
-- X: 3
-- X: 2
-- X: NULL
-- X: 1

SELECT t1.x, t2.z FROM t1 INNER JOIN t2 ON t2.z = (SELECT MAX(z) FROM t2 AS q WHERE q.x = t1.x);
-- X: 2 Z: 20
-- X: 3 Z: 31

-- # In a grouped query, a column of the outer query must be a grouping column.
SELECT y, (SELECT COUNT(*) FROM t2 WHERE t2.x < t1.x) AS c FROM t1 GROUP BY y;
-- error 42803: column T1.X must be in the GROUP BY clause or used in an aggregate function

SELECT x, (SELECT COUNT(*) FROM t2 WHERE t2.x = t1.x) AS c FROM t1 GROUP BY x;
-- X: NULL C: 0
-- X: 1 C: 0
-- X: 2 C: 1
-- X: 3 C: 2

SELECT x FROM t1 GROUP BY x HAVING EXISTS (SELECT * FROM t2 WHERE t2.x = t1.x);
-- X: 2
-- X: 3

-- # An aggregate function of only outer columns is of the outer query, which is then grouped.
SELECT (SELECT MAX(t1.x) FROM t2 WHERE z = 20) AS m FROM t1;
-- warning 01003: null value eliminated in set function
-- M: 3

SELECT (SELECT MAX(t1.x) FROM t2 WHERE z = 20) AS m FROM t1 WHERE x > 5;
-- M: NULL

SELECT x, (SELECT MAX(t1.x) FROM t2 WHERE z = 20) AS m FROM t1;
-- error 42803: column X must be in the GROUP BY clause or used in an aggregate function

SELECT y, (SELECT COUNT(t1.x) + COUNT(*) FROM t2 WHERE z = 20) AS c FROM t1 GROUP BY y;
-- warning 01003: null value eliminated in set function
-- Y: a C: 2
-- Y: b C: 3
-- Y: c C: 1

SELECT y FROM t1 GROUP BY y HAVING EXISTS (SELECT * FROM t2 WHERE t2.x = MAX(t1.x));
-- warning 01003: null value eliminated in set function
-- Y: b

SELECT 1 IN (SELECT MIN(t1.x) FROM t2 WHERE z = 20) AS a, 1 = ANY (SELECT MIN(t1.x) FROM t2 WHERE z = 20) AS b FROM t1;
-- warning 01003: null value eliminated in set function
-- A: TRUE B: TRUE

SELECT (SELECT (SELECT COUNT(DISTINCT t1.y) FROM t2 AS b WHERE b.z = 20) FROM t2 WHERE z = 20) AS c FROM t1;
-- C: 3

SELECT * FROM t1 WHERE EXISTS (SELECT * FROM t2 WHERE t2.x = MAX(t1.x));
-- error 42601: syntax error: an aggregate function cannot be used in WHERE

SELECT * FROM t1 WHERE MAX(x) > 1;
-- error 42601: syntax error: an aggregate function cannot be used in WHERE

-- # An aggregate function that also uses a column of the subquery is of the subquery.
SELECT x, (SELECT MAX(t2.z + t1.x) FROM t2) AS m FROM t1;
-- warning 01003: null value eliminated in set function
-- X: 1 M: 32
-- X: 2 M: 33
-- X: 3 M: 34
-- X: NULL M: NULL

SELECT y FROM t1 GROUP BY y HAVING (SELECT MAX(t2.z + t1.x) FROM t2) > 0;
-- error 42803: column T1.X must be in the GROUP BY clause or used in an aggregate function

-- # A column must be in the FROM clause of a query that contains it.
SELECT * FROM t3 WHERE EXISTS (SELECT * FROM t2 WHERE t2.x = t1.x);
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.T1.X

SELECT * FROM t3 WHERE EXISTS (SELECT * FROM t2 WHERE y = 'a');
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.Y

SELECT y FROM t2;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.Y

SELECT * FROM t1 AS a WHERE EXISTS (SELECT * FROM t2 WHERE t2.x = t1.x);
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.T1.X

-- # UPDATE and DELETE can use the row being changed.
UPDATE t1 SET y = (SELECT CAST(MAX(z) AS VARCHAR(10)) FROM t2 WHERE t2.x = t1.x) WHERE EXISTS (SELECT * FROM t2 WHERE t2.x = t1.x);
SELECT * FROM t1;
-- msg: UPDATE 2
-- X: 1 Y: a
-- X: 2 Y: 20
-- X: 3 Y: 31
-- X: NULL Y: c

-- # The x is in t2, which is innermost.
UPDATE t1 SET y = (SELECT CAST(COUNT(*) AS VARCHAR(10)) FROM t2 WHERE t2.x = x);
SELECT * FROM t1;
-- msg: UPDATE 4
-- X: 1 Y: 3
-- X: 2 Y: 3
-- X: 3 Y: 3
-- X: NULL Y: 3

DELETE FROM t1 WHERE NOT EXISTS (SELECT * FROM t2 WHERE t2.x = t1.x);
SELECT * FROM t1;
-- msg: DELETE 2
-- X: 2 Y: b
-- X: 3 Y: b

EXPLAIN SELECT * FROM t1 WHERE EXISTS (SELECT * FROM t2 WHERE t2.x = t1.x);
-- EXPLAIN: TABLE ":memory:".PUBLIC.T1 (X INTEGER, Y CHARACTER VARYING(10))
-- EXPLAIN: WHERE EXISTS (SELECT * FROM T2 WHERE T2.X = T1.X)
-- EXPLAIN: EXPR (":memory:".PUBLIC.T1.X INTEGER, ":memory:".PUBLIC.T1.Y CHARACTER VARYING(10))
