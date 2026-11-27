/* setup */
CREATE TABLE edges (a INTEGER, b INTEGER);
INSERT INTO edges (a, b) VALUES (1, 2), (2, 3), (3, 4), (4, 2), (5, 6);

-- # A query of a WITH RECURSIVE can read itself. The left side of its UNION is
-- # the first rows, and the right side reads the rows that were added last time
-- # to add more, until it doesn't add any (General Rules, 2).
WITH RECURSIVE n (x) AS (VALUES 1 UNION ALL SELECT x + 1 FROM n WHERE x < 5) SELECT * FROM n;
-- X: 1
-- X: 2
-- X: 3
-- X: 4
-- X: 5

-- # UNION (DISTINCT) doesn't add a row that's already there, so a cycle stops.
WITH RECURSIVE r (node) AS (VALUES 1 UNION SELECT b FROM edges JOIN r ON a = node) SELECT * FROM r;
WITH RECURSIVE r (node) AS (VALUES 1, 1 UNION SELECT b FROM edges, r WHERE a = node AND b > 2) SELECT * FROM r;
-- NODE: 1
-- NODE: 2
-- NODE: 3
-- NODE: 4
-- NODE: 1

-- # The right side can also read tables, a derived table that reads the query,
-- # and other WITH queries.
WITH RECURSIVE path (node, depth) AS (
  SELECT a, 0 FROM edges WHERE a = 1
  UNION ALL
  SELECT e.b, p.depth + 1 FROM edges AS e JOIN (SELECT * FROM path) AS p ON e.a = p.node WHERE p.depth < 4
) SELECT * FROM path;
-- NODE: 1 DEPTH: 0
-- NODE: 2 DEPTH: 1
-- NODE: 3 DEPTH: 2
-- NODE: 4 DEPTH: 3
-- NODE: 2 DEPTH: 4

-- # The query that follows can read it any number of times, renamed, and in a
-- # subquery. So can the queries after it, and a query in a WITH RECURSIVE
-- # doesn't have to read itself.
WITH RECURSIVE n (x) AS (VALUES 1 UNION ALL SELECT x + 1 FROM n WHERE x < 3) SELECT m.v, (SELECT COUNT(*) FROM n) FROM n AS m (v) JOIN n ON m.v = n.x - 1;
WITH RECURSIVE a (x) AS (VALUES 10), b (y) AS (SELECT x FROM a UNION ALL SELECT y + 1 FROM b WHERE y < 12), c (z) AS (SELECT y * 2 FROM b) SELECT * FROM c;
-- V: 1 COL2: 3
-- V: 2 COL2: 3
-- Z: 20
-- Z: 22
-- Z: 24

-- # The columns have the types of the left side.
WITH RECURSIVE n (x) AS (VALUES CAST(1 AS DOUBLE PRECISION) UNION ALL SELECT x * 2 FROM n WHERE x < 3) SELECT x FROM n;
WITH RECURSIVE n (x) AS (VALUES 'a' UNION ALL SELECT 1 FROM n) SELECT x FROM n;
-- X: 1e0
-- X: 2e0
-- X: 4e0
-- error 42804: data type mismatch in column 1 of UNION: expected CHARACTER(1) but got INTEGER

-- # A column that's recursively derived (it reads a column of the query) has
-- # the type of the left side, and any other column has the types of both
-- # sides combined (Syntax Rules, 19.b.ii.2).
/* types */
WITH RECURSIVE n (x, s, d) AS (VALUES (1, 'a', 'z') UNION ALL SELECT x + 1, 'abc', d FROM n WHERE x < 3) SELECT * FROM n;
WITH RECURSIVE n (x, s) AS (VALUES (1, 'a') UNION ALL SELECT x + 1, d.s FROM n, (VALUES 'abc') AS d (s) WHERE x < 2) SELECT * FROM n;
WITH RECURSIVE n (x, s) AS (VALUES (1, 'a') UNION ALL SELECT x + 1, d.s FROM (SELECT x, 'xyz' || 'w' AS s FROM n) AS d WHERE x < 2) SELECT * FROM n;
-- X: 1 (INTEGER) S: a   (CHARACTER(3)) D: z (CHARACTER(1))
-- X: 2 (INTEGER) S: abc (CHARACTER(3)) D: z (CHARACTER(1))
-- X: 3 (INTEGER) S: abc (CHARACTER(3)) D: z (CHARACTER(1))
-- X: 1 (INTEGER) S: a   (CHARACTER(3))
-- X: 2 (INTEGER) S: abc (CHARACTER(3))
-- X: 1 (INTEGER) S: a    (CHARACTER(4))
-- X: 2 (INTEGER) S: xyzw (CHARACTER(4))

-- # A WITH RECURSIVE can be in a subquery or a view.
SELECT * FROM (WITH RECURSIVE n (x) AS (VALUES 1 UNION ALL SELECT x + 1 FROM n WHERE x < 2) SELECT x FROM n) AS d;
CREATE VIEW v AS WITH RECURSIVE n (x) AS (VALUES 1 UNION ALL SELECT x + 1 FROM n WHERE x < 2) SELECT x * 10 AS y FROM n;
SELECT * FROM v;
-- X: 1
-- X: 2
-- msg: CREATE VIEW 1
-- Y: 10
-- Y: 20

-- # Every query of a WITH RECURSIVE needs a column list (Syntax Rules, 3.j.i).
WITH RECURSIVE n AS (VALUES 1) SELECT * FROM n;
WITH RECURSIVE n (x, y) AS (VALUES 1 UNION ALL SELECT x FROM n) SELECT * FROM n;
WITH RECURSIVE n (x) AS (VALUES 1), n (y) AS (VALUES 2) SELECT * FROM n;
-- error 42601: syntax error: WITH RECURSIVE query N needs a column list
-- error 42601: syntax error: WITH query N has 2 columns, but its query has 1
-- error 42601: syntax error: WITH query N is specified more than once

-- # A query that reads itself must be a UNION, where only one side reads it
-- # (Syntax Rules, 3.j.vii.1).
WITH RECURSIVE n (x) AS (SELECT x FROM n) SELECT * FROM n;
WITH RECURSIVE n (x) AS (SELECT x + 1 FROM n WHERE x < 3 UNION VALUES 1) SELECT * FROM n;
WITH RECURSIVE n (x) AS (SELECT x FROM n UNION SELECT x FROM n) SELECT * FROM n;
WITH RECURSIVE n (x) AS (VALUES 1 INTERSECT SELECT x FROM n) SELECT * FROM n;
WITH RECURSIVE n (x) AS (VALUES 1 UNION ALL SELECT x, x FROM n) SELECT * FROM n;
-- error 42601: syntax error: WITH RECURSIVE query N must be a UNION of a query that does not read N and one that does
-- X: 1
-- X: 2
-- X: 3
-- error 42601: syntax error: WITH RECURSIVE query N must be a UNION of a query that does not read N and one that does
-- error 42601: syntax error: WITH RECURSIVE query N must be a UNION of a query that does not read N and one that does
-- error 42601: syntax error: each UNION query must have the same number of columns

-- # A query can only read it once in its own query (Syntax Rules, 3.j.x), and
-- # not in a subquery other than in FROM (3.j.ix.5.B), a query with an aggregate
-- # function (3.j.ix.5.C), the right side of EXCEPT (3.j.ix.5.E), INTERSECT ALL
-- # or EXCEPT ALL (3.j.ix.5.D), the side of an outer join that has NULLs added
-- # (3.j.ix.5.F), or with FETCH FIRST (3.j.ix.3 and 3.j.ix.4).
WITH RECURSIVE n (x) AS (VALUES 1 UNION ALL SELECT n1.x FROM n AS n1, n AS n2) SELECT * FROM n;
WITH RECURSIVE n (x) AS (VALUES 1 UNION ALL SELECT a FROM edges WHERE a IN (SELECT x FROM n)) SELECT * FROM n;
WITH RECURSIVE n (x) AS (VALUES 1 UNION ALL SELECT MAX(x) FROM n) SELECT * FROM n;
WITH RECURSIVE n (x) AS (VALUES 1 UNION ALL SELECT x FROM n GROUP BY x HAVING COUNT(*) > 1) SELECT * FROM n;
WITH RECURSIVE n (x) AS (VALUES 1 UNION ALL SELECT x + 1 FROM n WHERE x < 3 GROUP BY x HAVING x > 0) SELECT * FROM n;
WITH RECURSIVE n (x) AS (VALUES 1 UNION ALL (SELECT a FROM edges EXCEPT SELECT x FROM n)) SELECT * FROM n;
WITH RECURSIVE n (x) AS (VALUES 1 UNION ALL (SELECT x FROM n INTERSECT ALL SELECT a FROM edges)) SELECT * FROM n;
WITH RECURSIVE n (x) AS (VALUES 1 UNION ALL SELECT b FROM edges LEFT JOIN n ON a = x) SELECT * FROM n;
WITH RECURSIVE n (x) AS (VALUES 1 UNION ALL SELECT x + 1 FROM n FETCH FIRST 3 ROWS ONLY) SELECT * FROM n;
-- error 42601: syntax error: a query can only read a WITH RECURSIVE query once in its own query
-- error 42601: syntax error: WITH RECURSIVE query N cannot be read in a subquery of its own query, other than in FROM
-- error 42601: syntax error: a query that reads a WITH RECURSIVE query in its own query cannot use an aggregate function
-- error 42601: syntax error: a query that reads a WITH RECURSIVE query in its own query cannot use an aggregate function
-- X: 1
-- X: 2
-- X: 3
-- error 42601: syntax error: the right side of EXCEPT cannot read a WITH RECURSIVE query in its own query
-- error 42601: syntax error: INTERSECT ALL cannot read a WITH RECURSIVE query in its own query
-- error 42601: syntax error: a WITH RECURSIVE query cannot be read in its own query on the side of an outer join that has NULLs added
-- error 42601: syntax error: a query that reads a WITH RECURSIVE query in its own query cannot have FETCH FIRST

-- # Its own query can't contain a WITH RECURSIVE (Syntax Rules, 3.g).
WITH RECURSIVE n (x) AS (WITH RECURSIVE m (y) AS (VALUES 1) SELECT y FROM m) SELECT * FROM n;
-- error 42601: syntax error: WITH RECURSIVE query N cannot contain a WITH RECURSIVE

-- # Every name is in scope in all of the queries, so a query can read a query
-- # after it, which hides a table with the same name (Syntax Rules, 3.i.ii).
WITH RECURSIVE a (x) AS (SELECT y FROM b), b (y) AS (VALUES 1) SELECT * FROM a;
WITH RECURSIVE a (x) AS (SELECT y * 2 FROM edges), edges (y) AS (VALUES 7) SELECT * FROM a;
WITH RECURSIVE c (z) AS (SELECT x FROM n UNION ALL SELECT z + 10 FROM c WHERE z < 20), n (x) AS (VALUES 1 UNION ALL SELECT x + 1 FROM n WHERE x < 2) SELECT * FROM c;
-- X: 1
-- X: 14
-- Z: 1
-- Z: 2
-- Z: 11
-- Z: 12
-- Z: 21
-- Z: 22

-- # Queries can read each other (mutual recursion). They're run together, and
-- # each iteration of each one reads the rows that were added last time to the
-- # others (General Rules, 2.c.ii). Only one query of each cycle has to be a
-- # UNION of a query that doesn't read them (Syntax Rules, 3.j.vii and
-- # 3.j.viii).
WITH RECURSIVE even (n) AS (VALUES 0 UNION ALL SELECT n + 1 FROM odd WHERE n < 5), odd (n) AS (SELECT n + 1 FROM even) SELECT * FROM (SELECT 'even' AS k, n FROM even UNION ALL SELECT 'odd', n FROM odd) AS d ORDER BY n;
WITH RECURSIVE a (x) AS (VALUES 1 UNION SELECT y + 1 FROM b WHERE y < 6), b (y) AS (VALUES 10 UNION SELECT x * 2 FROM a WHERE x < 4) SELECT * FROM a;
WITH RECURSIVE a (x) AS (VALUES 1 UNION SELECT y + 1 FROM b WHERE y < 6), b (y) AS (VALUES 10 UNION SELECT x * 2 FROM a WHERE x < 4) SELECT * FROM b;
-- K: even N: 0
-- K: odd  N: 1
-- K: even N: 2
-- K: odd  N: 3
-- K: even N: 4
-- K: odd  N: 5
-- X: 1
-- X: 3
-- Y: 10
-- Y: 2
-- Y: 6

-- # A cycle without a UNION that has a query that doesn't read the others is an
-- # error, and a query can only read one of them once (it's linearly recursive,
-- # Syntax Rules, 3.j.x).
WITH RECURSIVE a (x) AS (SELECT y FROM b), b (y) AS (SELECT x FROM a) SELECT * FROM a;
WITH RECURSIVE a (x) AS (VALUES 1 UNION SELECT y FROM b), b (y) AS (SELECT x FROM a UNION SELECT z FROM c), c (z) AS (SELECT y FROM b) SELECT * FROM a;
WITH RECURSIVE a (x) AS (VALUES 1 UNION ALL SELECT x + y FROM a, b WHERE x < 5), b (y) AS (SELECT x FROM a) SELECT * FROM a;
-- error 42601: syntax error: WITH RECURSIVE queries A, B read each other, so one of them must be a UNION of a query that does not read them and one that does
-- error 42601: syntax error: WITH RECURSIVE queries A, B, C read each other, so one of them must be a UNION of a query that does not read them and one that does
-- error 42601: syntax error: a query can only read a WITH RECURSIVE query once in its own query

-- # A RECURSIVE view is a view of a WITH RECURSIVE query with the same name and
-- # columns (Part 2, 11.32, Syntax Rules, 9.e), which is how it's kept. It needs
-- # a column list (11.32, Syntax Rules, 9.a).
CREATE RECURSIVE VIEW reach (node) AS VALUES 1 UNION SELECT b FROM edges JOIN reach ON a = node;
SELECT * FROM reach;
SELECT view_definition FROM information_schema.views WHERE table_name = 'REACH';
CREATE RECURSIVE VIEW r2 AS VALUES 1;
-- msg: CREATE VIEW 1
-- NODE: 1
-- NODE: 2
-- NODE: 3
-- NODE: 4
-- VIEW_DEFINITION: WITH RECURSIVE REACH (NODE) AS (VALUES 1 UNION SELECT b FROM edges JOIN reach ON a = node) SELECT * FROM REACH
-- error 42601: syntax error: RECURSIVE view R2 needs a column list

-- # EXPLAIN shows the left side, then the right side, which reads the rows that
-- # were added last time (the working table).
/* extensions V001-01 */
EXPLAIN WITH RECURSIVE n (x) AS (VALUES 1 UNION ALL SELECT x + 1 FROM n WHERE x < 3) SELECT * FROM n;
-- EXPLAIN: N:
-- EXPLAIN:   $1:
-- EXPLAIN:     VALUES (COL1 INTEGER) = ROW(1)
-- EXPLAIN:   $2:
-- EXPLAIN:     N:
-- EXPLAIN:       WORKING TABLE (X INTEGER)
-- EXPLAIN:     TABLE N (X INTEGER)
-- EXPLAIN:     WHERE X < 3
-- EXPLAIN:     EXPR (COL1 INTEGER)
-- EXPLAIN:   RECURSIVE UNION ALL (X INTEGER)
-- EXPLAIN: TABLE N (X INTEGER)
-- EXPLAIN: EXPR (N.X INTEGER)

-- # A recursive query is also run once, so every read of it has the same rows.
WITH RECURSIVE r (n, z) AS (SELECT 1, RANDOM() FROM edges WHERE a = 1 UNION ALL SELECT n + 1, z FROM r WHERE n < 3) SELECT COUNT(*) FROM r AS r1 JOIN r AS r2 ON r1.n = r2.n AND r1.z = r2.z;
-- COL1: 3

-- # A WITH in the query of a WITH RECURSIVE is run again each time.
WITH RECURSIVE r (n) AS (VALUES 1 UNION ALL (WITH s AS (SELECT n + 1 AS m FROM r) SELECT m FROM s WHERE m < 4)) SELECT * FROM r;
-- N: 1
-- N: 2
-- N: 3

-- # A column of a query that reads each other that isn't recursively derived
-- # has the type of both sides combined, and so does the query that reads it.
WITH RECURSIVE even (n, s) AS (VALUES (0, 'a') UNION ALL SELECT n + 1, 'abc' FROM odd WHERE n < 2), odd (n, s) AS (SELECT n + 1, s FROM even) SELECT * FROM odd;
-- N: 1 S: a
-- N: 3 S: abc

-- # Queries that aren't a UNION can read each other, as long as each cycle has
-- # one that is.
WITH RECURSIVE a (x) AS (VALUES 1 UNION ALL SELECT x FROM b), b (x) AS (SELECT x FROM d UNION ALL SELECT x FROM c), c (x) AS (SELECT x FROM d), d (x) AS (SELECT x + 1 FROM a WHERE x < 3) SELECT COUNT(*) FROM a;
-- COL1: 7

-- # The names of a WITH RECURSIVE are found before its queries are parsed, but
-- # a syntax error is still an error.
WITH RECURSIVE 1 (x) AS (VALUES 1) SELECT 1 FROM edges;
WITH RECURSIVE a (x) (VALUES 1) SELECT * FROM a;
WITH RECURSIVE a (x) AS VALUES 1 SELECT * FROM a;
WITH RECURSIVE "a"."b"."c"."d"."e" (x) AS (VALUES 1) SELECT * FROM a;
WITH RECURSIVE 'a' (x) AS (VALUES 1) SELECT 1 FROM edges;
WITH RECURSIVE "" (x) AS (VALUES 1) SELECT 1 FROM edges;
-- error 42601: syntax error: unexpected number at line 1, column 16 near "WITH RECURSIVE 1 ("
-- error 42601: syntax error: unexpected "(" at line 1, column 22 near "(x) (VALUES", expecting AS
-- error 42601: syntax error: unexpected VALUES at line 1, column 25 near "x) AS VALUES 1", expecting "("
-- error 42601: syntax error: unexpected "." at line 1, column 19 near "WITH RECURSIVE "a"."b"", expecting AS or "("
-- error 42601: syntax error: unexpected string at line 1, column 16 near "WITH RECURSIVE 'a' ("
-- error 42601: syntax error: a delimited identifier cannot be empty
