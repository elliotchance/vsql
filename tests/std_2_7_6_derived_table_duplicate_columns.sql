/* setup */
CREATE TABLE j1 (id INT);
CREATE TABLE j2 (id INT);
INSERT INTO j1 VALUES (1), (2);
INSERT INTO j2 VALUES (1);
CREATE TABLE t1 (x INT);
INSERT INTO t1 VALUES (0);

-- # Two columns of a derived table can have the same name, and each one keeps
-- # its own value and type.
SELECT * FROM (SELECT 1 AS a, 2 AS a FROM t1) AS d;
-- A: 1 A: 2

SELECT * FROM (SELECT 1 AS a, 'x' AS b, 2.5e0 AS a FROM t1) AS d;
-- A: 1 B: x A: 2.5e0

SELECT d.* FROM (SELECT 1 AS a, 2 AS a FROM t1) AS d;
-- A: 1 A: 2

SELECT * FROM (SELECT j1.id, j2.id FROM j1 LEFT JOIN j2 ON j1.id = j2.id) AS d;
-- ID: 1 ID: 1
-- ID: 2 ID: NULL

SELECT * FROM (SELECT 1 AS a, 2 AS a FROM t1 UNION SELECT 3, 4 FROM t1) AS d;
-- A: 1 A: 2
-- A: 3 A: 4

SELECT * FROM (SELECT * FROM (SELECT 1 AS a, 2 AS a FROM t1) AS d) AS e;
-- A: 1 A: 2

-- # A column with a name that's not duplicated can be referenced.
SELECT b FROM (SELECT 1 AS a, 2 AS b, 3 AS a FROM t1) AS d;
-- B: 2

-- # A reference to a duplicated name is ambiguous.
SELECT a FROM (SELECT 1 AS a, 2 AS a FROM t1) AS d;
-- error 42702: ambiguous column: A

SELECT d.id FROM (SELECT j1.id, j2.id FROM j1 LEFT JOIN j2 ON j1.id = j2.id) AS d;
-- error 42702: ambiguous column: ID

SELECT (SELECT a FROM t1) FROM (SELECT 1 AS a, 2 AS a FROM t1) AS d;
-- error 42702: ambiguous column: A

SELECT * FROM (SELECT 1 AS a, 2 AS a FROM t1) AS d ORDER BY a;
-- error 42702: ambiguous column: A

SELECT b FROM (SELECT 1 AS a, 2 AS a, 3 AS b FROM t1) AS d GROUP BY b HAVING a > 0;
-- error 42702: ambiguous column: A

-- # A column with a duplicated name must still be grouped when it's in the
-- # result of "*".
SELECT * FROM (SELECT j1.id, j2.id, j1.id AS b FROM j1 LEFT JOIN j2 ON j1.id = j2.id) AS d GROUP BY b;
-- error 42803: column D.ID must be in the GROUP BY clause or used in an aggregate function

SELECT b, COUNT(*) FROM (SELECT j1.id, j2.id, j1.id AS b FROM j1 LEFT JOIN j2 ON j1.id = j2.id) AS d GROUP BY b;
-- B: 1 COL2: 1
-- B: 2 COL2: 1

SELECT DISTINCT * FROM (SELECT 1 AS a, 2 AS a FROM j1) AS d;
-- A: 1 A: 2

-- # A derived column list renames the columns by position.
SELECT * FROM (SELECT 1 AS a, 2 AS a FROM t1) AS d (x, y);
-- X: 1 Y: 2

SELECT y, x FROM (SELECT j1.id, j2.id FROM j1 LEFT JOIN j2 ON j1.id = j2.id) AS d (x, y);
-- Y: 1 X: 1
-- Y: NULL X: 2

SELECT * FROM (SELECT 1 AS a, 2 AS a FROM t1 UNION SELECT 3, 4 FROM t1) AS d (x, y);
-- X: 1 Y: 2
-- X: 3 Y: 4

-- # A derived column list can't have the same name twice.
SELECT * FROM (SELECT 1 AS a, 2 AS b FROM t1) AS d (x, x);
-- error 42601: syntax error: column X is specified more than once
