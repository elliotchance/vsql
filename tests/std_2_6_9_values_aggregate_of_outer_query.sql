/* setup */
CREATE TABLE t (x INT, g INT);
CREATE TABLE u (y INT);
CREATE TABLE no_rows (z INT);
INSERT INTO t (x, g) VALUES (1, 10), (2, 10), (3, 20);
INSERT INTO u (y) VALUES (1), (2);

-- # A VALUES isn't a query specification, so an aggregate function in it
-- # without a column reference is of the innermost one that contains it
-- # (Syntax Rules, 6.a).
SELECT (VALUES COUNT(*)) FROM t;
-- COL1: 3

SELECT (VALUES MAX(1)) FROM t;
-- COL1: 1

-- # With a column reference it was already of the outer query
-- # (Syntax Rules, 6.b).
SELECT (VALUES MAX(t.x)) FROM t;
-- COL1: 3

-- # With no rows the outer query is still one group, so COUNT gives 0.
SELECT (VALUES COUNT(*)) FROM no_rows;
-- COL1: 0

SELECT (VALUES COUNT(1)) FROM no_rows;
-- COL1: 0

-- # Anywhere in the VALUES.
SELECT (VALUES COUNT(*) + 1) FROM t;
-- COL1: 4

SELECT (VALUES ABS(COUNT(*))) FROM t;
-- COL1: 3

SELECT (VALUES ROW(COUNT(*))) FROM t;
-- COL1: 3

SELECT (VALUES COUNT(*) FETCH FIRST 1 ROW ONLY) FROM t;
-- COL1: 3

SELECT ((VALUES COUNT(*))) FROM t;
-- COL1: 3

SELECT (VALUES COUNT(*) UNION ALL VALUES 5 FETCH FIRST 1 ROW ONLY) FROM t;
-- COL1: 3

-- # A VALUES in a VALUES still isn't a query specification.
SELECT (VALUES (VALUES COUNT(*))) FROM t;
-- COL1: 3

SELECT (VALUES (VALUES (VALUES COUNT(*)))) FROM t;
-- COL1: 3

-- # It makes the query grouped, and is calculated for each group.
SELECT g, (VALUES COUNT(*)) FROM t GROUP BY g;
-- G: 10 COL2: 2
-- G: 20 COL2: 1

SELECT g FROM t GROUP BY g HAVING (VALUES COUNT(*)) > 1;
-- G: 10

SELECT COUNT(*), (VALUES COUNT(*)), (VALUES MIN(x) + COUNT(*)) FROM t;
-- COL1: 3 COL2: 3 COL3: 4

SELECT x, (VALUES COUNT(*)) FROM t;
-- error 42803: column X must be in the GROUP BY clause or used in an aggregate function

-- # Other kinds of subquery.
SELECT 3 IN (VALUES COUNT(*)) FROM t;
-- COL1: TRUE

SELECT EXISTS (VALUES COUNT(*)) FROM t;
-- COL1: TRUE

-- # The innermost query specification, not the outermost.
SELECT (SELECT (VALUES COUNT(*)) FROM u) FROM t;
-- COL1: 2
-- COL1: 2
-- COL1: 2

SELECT x, (SELECT (VALUES COUNT(*)) FROM u) FROM t;
-- X: 1 COL2: 2
-- X: 2 COL2: 2
-- X: 3 COL2: 2

-- # A query specification in the VALUES has its own aggregate functions.
SELECT (VALUES (SELECT COUNT(*) FROM u)) FROM t;
-- COL1: 2
-- COL1: 2
-- COL1: 2

-- # The select list of a query specification in a derived table.
SELECT (SELECT y FROM (SELECT (VALUES COUNT(*)) AS y FROM u) AS v) FROM t;
-- COL1: 2
-- COL1: 2
-- COL1: 2

SELECT y FROM (SELECT (VALUES COUNT(*)) AS y FROM t) AS v;
-- Y: 3

-- # It must be in the select list or HAVING of its query (Syntax Rules, 7), not
-- # its WHERE or FROM. A derived table in a subquery isn't of the outer query.
SELECT * FROM t WHERE (VALUES COUNT(*)) = 3;
-- error 42601: syntax error: an aggregate function cannot be used in WHERE

SELECT (SELECT y FROM (VALUES COUNT(*)) AS v (y)) FROM t;
-- error 42601: syntax error: an aggregate function cannot be used in VALUES

SELECT (SELECT 1 FROM (VALUES (VALUES COUNT(*))) AS v) FROM t;
-- error 42601: syntax error: an aggregate function cannot be used in VALUES

-- # A column reference can still be of the outer query from there
-- # (Syntax Rules, 6.b).
SELECT (SELECT y FROM (VALUES MAX(t.x)) AS v (y)) FROM t;
-- COL1: 3

-- # Without a query specification there's no aggregation query
-- # (Syntax Rules, 7).
VALUES COUNT(*);
-- error 42601: syntax error: an aggregate function cannot be used in VALUES

VALUES (VALUES COUNT(*));
-- error 42601: syntax error: an aggregate function cannot be used in VALUES

SELECT * FROM (VALUES COUNT(*)) AS v;
-- error 42601: syntax error: an aggregate function cannot be used in VALUES

-- # Nesting is still an error when it's of the outer query
-- # (Syntax Rules, 1).
SELECT (VALUES MAX(COUNT(*))) FROM t;
-- error 42601: syntax error: nested set function: COUNT(*)
