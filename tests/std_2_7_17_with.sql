/* setup */
CREATE TABLE t (x INTEGER, y VARCHAR(10));
INSERT INTO t (x, y) VALUES (1, 'a'), (2, 'b'), (3, 'c');

-- # A WITH names queries that the rest of the query can read like tables
-- # (General Rules, 1.b and 1.c). The columns have the names of the query's
-- # columns, or of the column list.
WITH big AS (SELECT x, y FROM t WHERE x > 1) SELECT * FROM big;
WITH a (n) AS (SELECT x FROM t) SELECT n FROM a WHERE n < 3;
-- X: 2 Y: b
-- X: 3 Y: c
-- N: 1
-- N: 2

-- # A name can be read by the queries after it (Syntax Rules, 3.i.i), more
-- # than once, and in a subquery of the query.
WITH a (n) AS (SELECT x FROM t), b AS (SELECT n * 10 AS m FROM a) SELECT n, m FROM a JOIN b ON a.n * 10 = b.m;
WITH a AS (SELECT x FROM t) SELECT a1.x, a2.x FROM a a1, a a2 WHERE a1.x + 1 = a2.x;
WITH a AS (SELECT x FROM t WHERE x < 3) SELECT y FROM t WHERE x IN (SELECT x FROM a);
WITH a AS (SELECT x FROM t) SELECT COUNT(*) FROM a WHERE x > (SELECT MIN(x) FROM a);
-- N: 1 M: 10
-- N: 2 M: 20
-- N: 3 M: 30
-- X: 1 X: 2
-- X: 2 X: 3
-- Y: a
-- Y: b
-- COL1: 2

-- # It can be renamed when it's read, and read with TABLE.
WITH a (n) AS (SELECT x FROM t) SELECT z.n FROM a AS z WHERE z.n = 1;
WITH a AS (SELECT x FROM t) SELECT k FROM a AS z (k) WHERE k = 2;
WITH a AS (VALUES 7) TABLE a;
-- N: 1
-- K: 2
-- COL1: 7

-- # A name hides a table with the same name, unless the table is qualified by
-- # its schema (Syntax Rules, 9.a.i in 7.6).
WITH t AS (VALUES 42) SELECT * FROM t;
WITH t AS (VALUES 42) SELECT COUNT(*) FROM public.t;
-- COL1: 42
-- COL1: 3

-- # The query after the WITH can be in parentheses, or have a UNION, ORDER BY,
-- # OFFSET and FETCH FIRST.
WITH a AS (SELECT x FROM t) (SELECT x FROM a WHERE x = 1);
WITH a AS (SELECT x FROM t) SELECT x FROM a UNION VALUES 9 ORDER BY x DESC FETCH FIRST 2 ROWS ONLY;
-- X: 1
-- X: 9
-- X: 3

-- # Each name can only be used once (Syntax Rules, 3.c), the column list must
-- # have a name for each column, each only once (Syntax Rules, 3.d.ii), and it's
-- # needed when two columns have the same name (Syntax Rules, 3.d.i). Each query
-- # is checked even when it isn't read.
WITH a AS (VALUES 1), a AS (VALUES 2) SELECT 1 FROM t;
WITH a (p, q) AS (VALUES 1) SELECT 1 FROM t;
WITH a (p, p) AS (VALUES (1, 2)) SELECT 1 FROM t;
WITH a AS (SELECT x AS p, y AS p FROM t) SELECT 1 FROM t;
WITH a (p, q) AS (SELECT x AS p, y AS p FROM t) SELECT q FROM a WHERE p = 2;
WITH a AS (SELECT * FROM nope) SELECT 1 FROM t;
-- error 42601: syntax error: WITH query A is specified more than once
-- error 42601: syntax error: WITH query A has 2 columns, but its query has 1
-- error 42601: syntax error: column P is specified more than once
-- error 42601: syntax error: WITH query A has more than one column named P, so it needs a column list
-- Q: b
-- error 42P01: no such table: ":memory:".PUBLIC.NOPE

-- # A query can't read its own name, which would make it recursive (#1284), or
-- # a name after it.
WITH a AS (SELECT * FROM a) SELECT 1 FROM t;
WITH a AS (SELECT * FROM b), b AS (VALUES 1) SELECT 1 FROM t;
-- error 42P01: no such table: ":memory:".PUBLIC.A
-- error 42P01: no such table: ":memory:".PUBLIC.B

-- # A name is only in scope in its query, not after it.
WITH a AS (VALUES 1) SELECT * FROM t WHERE x = 0;
SELECT * FROM a;
-- error 42P01: no such table: ":memory:".PUBLIC.A

-- # A subquery can have a WITH too (T122), such as a derived table, a scalar
-- # subquery, the query of IN or EXISTS, a query in parentheses, or another
-- # WITH query.
SELECT * FROM (WITH a AS (VALUES 1) SELECT * FROM a) AS d;
SELECT x, (WITH a (n) AS (VALUES 10) SELECT n FROM a) FROM t WHERE x = 1;
SELECT y FROM t WHERE x IN (WITH a (n) AS (VALUES 2) SELECT n FROM a);
(WITH a (n) AS (VALUES 4) SELECT n FROM a);
SELECT x FROM t WHERE x = 1 UNION (WITH a (n) AS (VALUES 7) SELECT n FROM a) ORDER BY x;
WITH a AS (WITH b (n) AS (VALUES 3) SELECT n FROM b) SELECT * FROM a;
-- COL1: 1
-- X: 1 COL2: 10
-- Y: b
-- N: 4
-- X: 1
-- X: 7
-- N: 3

-- # A WITH in a subquery can read the names of the WITH around it, and its own
-- # names hide them. A query of the WITH can refer to the columns of the query
-- # that contains the subquery.
WITH a (n) AS (VALUES 5) SELECT y FROM t WHERE x IN (WITH b AS (SELECT n - 3 AS m FROM a) SELECT m FROM b);
WITH a (n) AS (VALUES 1) SELECT * FROM (WITH a (n) AS (VALUES 2) SELECT n FROM a) AS d, a;
SELECT y FROM t WHERE EXISTS (WITH a AS (SELECT x FROM t AS t2 WHERE t2.x = t.x + 1) SELECT * FROM a);
-- Y: b
-- N: 2 N: 1
-- Y: a
-- Y: b

-- # The names of a WITH in a subquery aren't in scope after the subquery.
SELECT * FROM (WITH a AS (VALUES 1) SELECT * FROM a) AS d, a;
-- error 42P01: no such table: ":memory:".PUBLIC.A

-- # A WITH can't start the query after a WITH, unless it's in parentheses
-- # (Syntax Rules, 1).
WITH a AS (VALUES 1) WITH b AS (VALUES 2) SELECT * FROM b;
WITH a (n) AS (VALUES 1) (WITH b (m) AS (VALUES 2) SELECT n, m FROM a, b);
-- error 42601: syntax error: unexpected WITH at line 1, column 22 near "VALUES 1) WITH b", expecting SELECT or TABLE or VALUES or "("
-- N: 1 M: 2

-- # Every query of a statement can have a WITH, such as a view or an INSERT.
CREATE VIEW v AS WITH a AS (SELECT x FROM t WHERE x <> 2) SELECT x * 2 AS d FROM a;
SELECT * FROM v;
INSERT INTO t (x, y) WITH a (n) AS (VALUES 9) SELECT n, 'z' FROM a;
SELECT * FROM t WHERE x = 9;
-- msg: CREATE VIEW 1
-- D: 2
-- D: 6
-- msg: INSERT 1
-- X: 9 Y: z
