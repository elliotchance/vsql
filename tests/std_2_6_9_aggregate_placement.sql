/* setup */
CREATE TABLE t1 (x INT, y INT);
CREATE TABLE t2 (z INT);
CREATE TABLE t3 (w INT);
INSERT INTO t1 (x, y) VALUES (1, 5), (1, 1), (2, 2), (3, 9);
INSERT INTO t2 (z) VALUES (10);
INSERT INTO t3 (w) VALUES (20);

-- # An aggregate function must be in the select list or HAVING of its query
-- # (Syntax Rules, 7), so the rest of this file is every other place.
-- #
-- # UPDATE isn't a query, so a column of the table being updated doesn't make
-- # the subquery's aggregate function an aggregate of anything.
UPDATE t1 SET x = MAX(x);
-- error 42601: syntax error: an aggregate function cannot be used in SET

UPDATE t1 SET x = COUNT(*);
-- error 42601: syntax error: an aggregate function cannot be used in SET

UPDATE t1 SET x = 1 + ABS(MAX(x));
-- error 42601: syntax error: an aggregate function cannot be used in SET

UPDATE t1 SET x = (SELECT MAX(t1.x) FROM t2);
-- error 42601: syntax error: an aggregate function cannot be used in SET

UPDATE t1 SET x = (SELECT z FROM t2 WHERE MAX(t1.x) > 0);
-- error 42601: syntax error: an aggregate function cannot be used in SET

DELETE FROM t1;
UPDATE t1 SET x = MAX(x);
-- msg: DELETE 4
-- error 42601: syntax error: an aggregate function cannot be used in SET

UPDATE t1 SET x = 1 WHERE MAX(x) > 1;
-- error 42601: syntax error: an aggregate function cannot be used in WHERE

UPDATE t1 SET x = 1 WHERE x = (SELECT MAX(t1.x) FROM t2);
-- error 42601: syntax error: an aggregate function cannot be used in WHERE

DELETE FROM t1 WHERE MAX(x) > 1;
-- error 42601: syntax error: an aggregate function cannot be used in WHERE

-- # An aggregate function of the subquery is still fine.
UPDATE t1 SET y = (SELECT MAX(z) FROM t2);
SELECT DISTINCT y FROM t1;
-- msg: UPDATE 4
-- Y: 10

UPDATE t1 SET y = (SELECT MAX(z + t1.x) FROM t2) WHERE x = 3;
SELECT y FROM t1 WHERE x = 3;
-- msg: UPDATE 1
-- Y: 13

-- # A VALUES isn't a query specification, so an aggregate function in it has
-- # no aggregation query (Syntax Rules, 6.a and 7).
INSERT INTO t1 (x) VALUES (MAX(1));
-- error 42601: syntax error: an aggregate function cannot be used in VALUES

INSERT INTO t1 (x) VALUES (COUNT(*));
-- error 42601: syntax error: an aggregate function cannot be used in VALUES

INSERT INTO t1 (x) VALUES (ABS(MAX(1)));
-- error 42601: syntax error: an aggregate function cannot be used in VALUES

VALUES MAX(1);
-- error 42601: syntax error: an aggregate function cannot be used in VALUES

VALUES ROW(COUNT(*));
-- error 42601: syntax error: an aggregate function cannot be used in VALUES

SELECT * FROM (VALUES MAX(1)) AS v;
-- error 42601: syntax error: an aggregate function cannot be used in VALUES

-- # A subquery in a VALUES has its own aggregate functions.
INSERT INTO t2 (z) VALUES ((SELECT MAX(x) FROM t1));
SELECT z FROM t2 WHERE z = 3;
-- msg: INSERT 1
-- Z: 3

-- # A VALUES in a subquery can use an aggregate function of the outer query.
SELECT (VALUES MAX(t1.x)) AS m FROM t1;
-- M: 3

-- # ORDER BY can only have an aggregate function if the query is grouped.
/* extensions V202-03 */
SELECT x FROM t1 ORDER BY MAX(x);
-- error 42601: syntax error: an aggregate function cannot be used in ORDER BY unless the query is grouped

/* extensions V202-01 V202-03 */
SELECT x FROM t1 ORDER BY COUNT(*);
-- error 42601: syntax error: an aggregate function cannot be used in ORDER BY unless the query is grouped

/* extensions V202-03 */
SELECT x FROM t1 ORDER BY ABS(MAX(x));
-- error 42601: syntax error: an aggregate function cannot be used in ORDER BY unless the query is grouped

/* extensions V202-03 */
SELECT DISTINCT x FROM t1 ORDER BY MAX(x);
-- error 42601: syntax error: an aggregate function cannot be used in ORDER BY unless the query is grouped

/* extensions V202-02 V202-03 */
SELECT x FROM t1 ORDER BY (SELECT MAX(t1.x) FROM t2);
-- error 42601: syntax error: an aggregate function cannot be used in ORDER BY unless the query is grouped

/* extensions V202-03 */
SELECT x FROM t1 UNION SELECT y FROM t1 ORDER BY MAX(x);
-- error 42601: syntax error: an aggregate function cannot be used in ORDER BY unless the query is grouped

/* extensions V202-01 V202-03 */
VALUES 1 ORDER BY COUNT(*);
-- error 42601: syntax error: an aggregate function cannot be used in ORDER BY unless the query is grouped

/* extensions V202-03 */
SELECT (SELECT z FROM t2 ORDER BY MAX(z)) FROM t1;
-- error 42601: syntax error: an aggregate function cannot be used in ORDER BY unless the query is grouped

/* extensions V202-02 V202-03 */
SELECT x FROM t1 ORDER BY (SELECT MAX(z) FROM t2), x FETCH FIRST 1 ROW ONLY;
-- X: 1

-- # An aggregate function in the ORDER BY is calculated, even if it's not used
-- # by anything else.
/* extensions V202-03 */
SELECT x FROM t1 GROUP BY x ORDER BY MAX(y);
-- X: 2
-- X: 1
-- X: 3

/* extensions V202-01 V202-03 */
SELECT x FROM t1 GROUP BY x ORDER BY COUNT(*) DESC, x DESC;
-- X: 1
-- X: 3
-- X: 2

/* extensions V202-03 */
SELECT x FROM t1 GROUP BY x ORDER BY ABS(MIN(y)) DESC;
-- X: 3
-- X: 2
-- X: 1

/* extensions V202-03 */
SELECT x, MAX(y) AS m FROM t1 GROUP BY x ORDER BY MAX(y) DESC;
-- X: 3 M: 9
-- X: 1 M: 5
-- X: 2 M: 2

/* extensions V202-03 */
SELECT x FROM t1 GROUP BY x HAVING MAX(y) > 2 ORDER BY MAX(y) DESC;
-- X: 3
-- X: 1

/* extensions V202-03 */
SELECT COUNT(*) AS c FROM t1 ORDER BY MIN(x);
-- C: 4

/* extensions V202-01 V202-03 */
SELECT 1 AS a FROM t1 HAVING COUNT(*) > 0 ORDER BY COUNT(*);
-- A: 1

/* extensions V202-03 */
(SELECT x FROM t1 GROUP BY x) ORDER BY MAX(y);
-- X: 2
-- X: 1
-- X: 3

/* extensions V202-02 V202-03 */
SELECT x FROM t1 GROUP BY x ORDER BY (SELECT MAX(t1.y) FROM t2);
-- X: 2
-- X: 1
-- X: 3

/* extensions V202-02 V202-03 */
SELECT MAX(x) AS m FROM t1 ORDER BY (SELECT MAX(t1.x) FROM t2);
-- M: 3

-- # A join condition isn't the select list or HAVING, so it can't have an
-- # aggregate function of its query, even from inside a subquery (Syntax Rules,
-- # 7).
SELECT * FROM t1 JOIN t1 AS b ON MAX(b.x) > 1;
-- error 42601: syntax error: an aggregate function cannot be used in a join condition

SELECT * FROM t1 JOIN t2 ON COUNT(*) > 1;
-- error 42601: syntax error: an aggregate function cannot be used in a join condition

SELECT * FROM t1 JOIN t2 ON ABS(MAX(z)) > 1;
-- error 42601: syntax error: an aggregate function cannot be used in a join condition

SELECT * FROM t1 LEFT JOIN t2 ON x = (SELECT MAX(t1.x) FROM t3);
-- error 42601: syntax error: an aggregate function cannot be used in a join condition

SELECT (SELECT 1 FROM t2 JOIN t3 ON MAX(z) > 0) FROM t1;
-- error 42601: syntax error: an aggregate function cannot be used in a join condition

SELECT (SELECT 1 FROM t2 JOIN t3 ON COUNT(*) > 0) FROM t1;
-- error 42601: syntax error: an aggregate function cannot be used in a join condition

-- # An aggregate function in the select list of a subquery is still fine.
SELECT x, z FROM t1 JOIN t2 ON z = (SELECT MAX(w) - 10 FROM t3) AND x = 2;
-- X: 2 Z: 10

-- # A join condition or WHERE in a subquery can use an aggregate function of an
-- # outer query, as long as the subquery is in its select list or HAVING.
SELECT (SELECT z FROM t2 JOIN t3 ON MAX(t1.x) = 3) AS z FROM t1;
-- Z: 10

SELECT (SELECT w FROM t3 WHERE MAX(t1.x) = 3) AS w FROM t1;
-- W: 20

SELECT 1 AS a FROM t1 HAVING EXISTS (SELECT z FROM t2 JOIN t3 ON MAX(t1.x) = 3);
-- A: 1

SELECT (SELECT w FROM t3 WHERE w = (SELECT MAX(t1.y) + 11 FROM t2)) AS w FROM t1;
-- W: 20

-- # But not in the subquery's own WHERE or ON, or the outer query's.
SELECT (SELECT z FROM t2 WHERE MAX(t2.z) > 0) FROM t1;
-- error 42601: syntax error: an aggregate function cannot be used in WHERE

SELECT (SELECT z FROM t2 WHERE MAX(t1.x + z) > 0) FROM t1;
-- error 42601: syntax error: an aggregate function cannot be used in WHERE

SELECT * FROM t1 WHERE EXISTS (SELECT z FROM t2 JOIN t3 ON MAX(t1.x) = 3);
-- error 42601: syntax error: an aggregate function cannot be used in WHERE

SELECT * FROM t1 WHERE ABS(MAX(x)) > 0;
-- error 42601: syntax error: an aggregate function cannot be used in WHERE

SELECT * FROM t1 WHERE COUNT(*) > 0;
-- error 42601: syntax error: an aggregate function cannot be used in WHERE

SELECT * FROM t1 WHERE SUBSTRING('abc' FROM MAX(x)) = 'c';
-- error 42601: syntax error: an aggregate function cannot be used in WHERE

SELECT * FROM t1 WHERE SUBSTRING('abc' FROM 1 FOR MAX(x)) = 'abc';
-- error 42601: syntax error: an aggregate function cannot be used in WHERE

-- # GROUP BY can only be column names.
SELECT x FROM t1 GROUP BY MAX(x);
-- error 42601: syntax error: unexpected MAX

-- # Nested aggregate functions (Syntax Rules, 1), even if the inner one is of
-- # an outer query.
SELECT MAX(MIN(x)) FROM t1;
-- error 42601: syntax error: nested set function: MAX(MIN(X))

SELECT MAX(COUNT(*)) FROM t1;
-- error 42601: syntax error: nested set function: MAX(COUNT(*))

SELECT MAX(ABS(MIN(x))) FROM t1;
-- error 42601: syntax error: nested set function: MAX(ABS(MIN(X)))

SELECT MAX(1 + MIN(x)) FROM t1;
-- error 42601: syntax error: nested set function: MAX(1 + MIN(X))

SELECT (SELECT MAX(MIN(z)) FROM t2) FROM t1;
-- error 42601: syntax error: nested set function: MAX(MIN(Z))

SELECT (SELECT MAX(MIN(t1.x)) FROM t2) FROM t1;
-- error 42601: syntax error: nested set function: MIN(T1.X)

SELECT (SELECT MAX(z + COUNT(t1.x)) FROM t2) FROM t1;
-- error 42601: syntax error: nested set function: COUNT(T1.X)

-- # The argument can't contain a subquery either (Syntax Rules, 1).
SELECT MAX((SELECT MAX(z) FROM t2)) FROM t1;
-- error 42601: syntax error: a subquery cannot be used in an aggregate function

SELECT MAX((SELECT MAX(t1.x) FROM t2)) FROM t1;
-- error 42601: syntax error: a subquery cannot be used in an aggregate function

-- # CHECK and generation expressions, including as a function argument, and
-- # DEFAULT which can only be a literal or a datetime value function.
CREATE TABLE c1 (a INT CHECK (ABS(MAX(a)) > 0));
-- error 42601: syntax error: an aggregate function cannot be used in a CHECK constraint

CREATE TABLE c2 (a INT, CHECK (COUNT(*) > 0));
-- error 42601: syntax error: an aggregate function cannot be used in a CHECK constraint

CREATE TABLE c3 (a INT, b INT GENERATED ALWAYS AS (ABS(MAX(a))));
-- error 42601: syntax error: an aggregate function cannot be used in a generation expression

CREATE TABLE c4 (a INT, b INT GENERATED ALWAYS AS (COUNT(*)));
-- error 42601: syntax error: an aggregate function cannot be used in a generation expression

CREATE TABLE c5 (a INT DEFAULT MAX(1));
-- error 42601: syntax error: unexpected MAX

-- # An aggregate function in a function argument makes the query grouped.
SELECT ABS(MAX(y)) AS m FROM t1;
-- M: 9

SELECT x, ABS(MAX(y)) AS m FROM t1 GROUP BY x;
-- X: 1 M: 5
-- X: 2 M: 2
-- X: 3 M: 9

SELECT x FROM t1 GROUP BY x HAVING ABS(MAX(y)) > 5;
-- X: 3

SELECT y, ABS(MAX(y)) FROM t1 GROUP BY x;
-- error 42803: column Y must be in the GROUP BY clause or used in an aggregate function

SELECT x, ABS(MAX(y)) FROM t1;
-- error 42803: column X must be in the GROUP BY clause or used in an aggregate function

SELECT MOD(COUNT(*), 3) AS m FROM t1;
-- M: 1

SELECT (SELECT ABS(MAX(t1.y)) FROM t2) AS m FROM t1;
-- M: 9

SELECT SUBSTRING('abcd' FROM MAX(x)) AS s, SUBSTRING('abcd' FROM 1 FOR MAX(x)) AS f FROM t1;
-- S: cd F: abc
