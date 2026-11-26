/* setup */
CREATE TABLE t (x INT, y VARCHAR(10));
INSERT INTO t (x, y) VALUES (1, 'a'), (2, 'b'), (3, NULL);

-- # A view is read like a table, by planning its query each time (General
-- # Rules, 2). It sees the rows of the table as they are when it's read.
/* types */
CREATE VIEW v AS SELECT x, y FROM t WHERE x > 1;
SELECT * FROM v;
INSERT INTO t (x, y) VALUES (4, 'd');
SELECT x FROM v;
-- msg: CREATE VIEW 1
-- X: 2 (INTEGER) Y: b (CHARACTER VARYING(10))
-- X: 3 (INTEGER) Y: NULL (CHARACTER VARYING(10))
-- msg: INSERT 1
-- X: 2 (INTEGER)
-- X: 3 (INTEGER)
-- X: 4 (INTEGER)

-- # A view column list names the columns (General Rules, 1.e.i.1), otherwise
-- # they're the names of the query's columns (General Rules, 1.e.i.2).
CREATE VIEW v (a, b) AS SELECT x, y FROM t;
CREATE VIEW w AS SELECT x * 10 AS ten, UPPER(y) FROM t;
SELECT a, b FROM v WHERE a = 1;
SELECT * FROM w;
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- A: 1 B: a
-- TEN: 10 COL2: A
-- TEN: 20 COL2: B
-- TEN: 30 COL2: NULL

CREATE VIEW v (a, b) AS SELECT x, y FROM t;
SELECT x FROM v;
-- msg: CREATE VIEW 1
-- error 42703: no such column: ":memory:".PUBLIC.X

-- # The number of columns must match (Syntax Rules, 14), and each name can only
-- # be used once (Syntax Rules, 24.a).
CREATE VIEW v (a) AS SELECT x, y FROM t;
-- error 42601: syntax error: view ":memory:".PUBLIC.V has 1 columns, but its query has 2

CREATE VIEW v (a, b, c) AS SELECT x, y FROM t;
-- error 42601: syntax error: view ":memory:".PUBLIC.V has 3 columns, but its query has 2

CREATE VIEW v (a, a) AS SELECT x, y FROM t;
-- error 42601: syntax error: column A is specified more than once

CREATE VIEW v AS SELECT x, x FROM t;
-- error 42601: syntax error: column X is specified more than once

CREATE VIEW v (a, b) AS SELECT x, x FROM t;
SELECT * FROM v;
-- msg: CREATE VIEW 1
-- A: 1 B: 1
-- A: 2 B: 2
-- A: 3 B: 3

-- # A view can be read with a correlation name, which can also rename its
-- # columns, and it can be qualified by its schema.
CREATE VIEW v AS SELECT x FROM t;
SELECT v.x, public.v.x FROM v;
SELECT z.x FROM v AS z WHERE z.x = 2;
SELECT z.a FROM v AS z (a) WHERE z.a = 3;
SELECT v.* FROM v WHERE x = 1;
-- msg: CREATE VIEW 1
-- X: 1 X: 1
-- X: 2 X: 2
-- X: 3 X: 3
-- X: 2
-- A: 3
-- X: 1

-- # A view can be joined, used in a subquery, or read by another view.
CREATE VIEW v AS SELECT x AS a FROM t WHERE x < 3;
CREATE VIEW w AS SELECT a + 100 AS b FROM v;
SELECT t.x, v.a FROM t JOIN v ON t.x = v.a;
SELECT x FROM t WHERE x NOT IN (SELECT a FROM v);
SELECT * FROM w;
SELECT COUNT(*) FROM v, w;
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- X: 1 A: 1
-- X: 2 A: 2
-- X: 3
-- B: 101
-- B: 102
-- COL1: 4

-- # The query can be anything that can be in a derived table.
CREATE VIEW v AS SELECT y, COUNT(*) AS n FROM t GROUP BY y;
CREATE VIEW w (k) AS VALUES 1, 2;
CREATE VIEW u AS SELECT x FROM t UNION SELECT k FROM w;
SELECT n FROM v WHERE y = 'a';
SELECT * FROM w;
SELECT COUNT(*) FROM u;
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- N: 1
-- K: 1
-- K: 2
-- COL1: 3

-- # A view's query can use UNION and EXCEPT (F081), and INTERSECT. Each column
-- # has the type of the columns of both sides combined, and the view uses the
-- # tables of both sides.
/* types */
CREATE TABLE f081 (x BIGINT, y VARCHAR(20));
INSERT INTO f081 (x, y) VALUES (2, 'b'), (5, 'e'), (5, 'e');
CREATE VIEW v AS SELECT x, y FROM t UNION SELECT x, y FROM f081;
CREATE VIEW w (k) AS SELECT x FROM f081 EXCEPT ALL SELECT x FROM t;
CREATE VIEW u AS SELECT x FROM t EXCEPT SELECT x FROM f081 UNION ALL VALUES 9;
CREATE VIEW s AS SELECT x FROM t INTERSECT SELECT x FROM f081;
SELECT * FROM v;
SELECT * FROM w;
SELECT * FROM u;
SELECT * FROM s;
DROP TABLE f081 RESTRICT;
SELECT view_name, table_name FROM information_schema.view_table_usage WHERE table_name = 'F081';
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- X: 1 (BIGINT) Y: a (CHARACTER VARYING(20))
-- X: 2 (BIGINT) Y: b (CHARACTER VARYING(20))
-- X: 3 (BIGINT) Y: NULL (CHARACTER VARYING(20))
-- X: 5 (BIGINT) Y: e (CHARACTER VARYING(20))
-- K: 5 (BIGINT)
-- K: 5 (BIGINT)
-- X: 1 (BIGINT)
-- X: 3 (BIGINT)
-- X: 9 (BIGINT)
-- X: 2 (BIGINT)
-- error 2BP01: dependent objects still exist on ":memory:".PUBLIC.F081
-- VIEW_NAME: S (CHARACTER VARYING(128)) TABLE_NAME: F081 (CHARACTER VARYING(128))
-- VIEW_NAME: U (CHARACTER VARYING(128)) TABLE_NAME: F081 (CHARACTER VARYING(128))
-- VIEW_NAME: V (CHARACTER VARYING(128)) TABLE_NAME: F081 (CHARACTER VARYING(128))
-- VIEW_NAME: W (CHARACTER VARYING(128)) TABLE_NAME: F081 (CHARACTER VARYING(128))

-- # The name can't already be a table or a view (Syntax Rules, 4).
CREATE VIEW t AS SELECT x FROM t;
-- error 42P07: duplicate table: ":memory:".PUBLIC.T

CREATE VIEW v AS SELECT x FROM t;
CREATE VIEW v AS SELECT y FROM t;
-- msg: CREATE VIEW 1
-- error 42P07: duplicate table: ":memory:".PUBLIC.V

CREATE VIEW v AS SELECT x FROM t;
CREATE TABLE v (x INT);
-- msg: CREATE VIEW 1
-- error 42P07: duplicate table: ":memory:".PUBLIC.V

CREATE VIEW information_schema.tables AS SELECT x FROM t;
-- error 42501: insufficient privilege: INFORMATION_SCHEMA is read-only

-- # The query must be valid when the view is created, and can't use the view
-- # itself (Syntax Rules, 5), since it doesn't exist yet.
CREATE VIEW v AS SELECT z FROM t;
-- error 42703: no such column: ":memory:".PUBLIC.Z

CREATE VIEW v AS SELECT x FROM v;
-- error 42P01: no such table: ":memory:".PUBLIC.V

CREATE VIEW s.v AS SELECT x FROM t;
-- error 3F000: invalid schema name: S

-- # It can't have a parameter (Syntax Rules, 2), or NEXT VALUE FOR.
CREATE VIEW v AS SELECT x FROM t WHERE x = ?;
-- error 42601: syntax error: a view can't contain a parameter

CREATE SEQUENCE seq;
CREATE VIEW v AS SELECT NEXT VALUE FOR seq FROM t;
-- msg: CREATE SEQUENCE 1
-- error 42601: syntax error: NEXT VALUE FOR cannot be used in a view

-- # The query can end with an ORDER BY (F852), OFFSET (F864) and FETCH FIRST
-- # (F859), which pick the rows of the view.
CREATE VIEW v AS SELECT x FROM t ORDER BY x DESC;
CREATE VIEW w AS SELECT x FROM t ORDER BY x FETCH FIRST 2 ROWS ONLY;
CREATE VIEW u AS SELECT x FROM t ORDER BY x OFFSET 1 ROW;
CREATE VIEW s AS SELECT x FROM t ORDER BY y DESC OFFSET 1 ROW FETCH NEXT 1 ROW ONLY;
CREATE VIEW r AS SELECT x FROM t UNION VALUES 9 ORDER BY x DESC FETCH FIRST 2 ROWS ONLY;
SELECT * FROM v;
SELECT * FROM w;
SELECT * FROM u;
SELECT * FROM s;
SELECT * FROM r;
SELECT * FROM w JOIN u ON w.x + 1 = u.x ORDER BY w.x DESC;
SELECT view_name, column_name FROM information_schema.view_column_usage WHERE view_name = 'S';
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- X: 3
-- X: 2
-- X: 1
-- X: 1
-- X: 2
-- X: 2
-- X: 3
-- X: 1
-- X: 9
-- X: 3
-- X: 2 X: 3
-- X: 1 X: 2
-- VIEW_NAME: S COLUMN_NAME: X
-- VIEW_NAME: S COLUMN_NAME: Y

-- # The names in the query are resolved in the schema of the view, whatever the
-- # current schema is when it's created or read.
CREATE SCHEMA s;
CREATE TABLE s.t (x INT);
INSERT INTO s.t (x) VALUES (100);
CREATE VIEW s.v AS SELECT x FROM t;
SELECT * FROM s.v;
SET SCHEMA 's';
SELECT * FROM v;
CREATE VIEW public.w AS SELECT x FROM t;
SELECT * FROM public.w;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: CREATE VIEW 1
-- X: 100
-- msg: SET SCHEMA 1
-- X: 100
-- msg: CREATE VIEW 1
-- X: 1
-- X: 2
-- X: 3

-- # A view can be created by a CREATE SCHEMA (Syntax Rules, 3).
CREATE SCHEMA s CREATE TABLE u (x INT) CREATE VIEW v AS SELECT x FROM u;
INSERT INTO s.u (x) VALUES (7);
SELECT * FROM s.v;
-- msg: CREATE SCHEMA 1
-- msg: INSERT 1
-- X: 7

CREATE SCHEMA s CREATE VIEW public.v AS SELECT x FROM t;
-- error 42601: syntax error: PUBLIC.V must be in schema S

-- # The columns are fixed when the view is created. A column that's added to a
-- # table read with * isn't in the view, but the view is an error when its
-- # query has fewer columns.
CREATE VIEW v AS SELECT * FROM t;
ALTER TABLE t ADD COLUMN z INT DEFAULT 5;
SELECT * FROM v WHERE x = 1;
SELECT * FROM t WHERE x = 1;
SELECT v.* FROM v WHERE x = 2;
-- msg: CREATE VIEW 1
-- msg: ALTER TABLE 1
-- X: 1 Y: a
-- X: 1 Y: a Z: 5
-- X: 2 Y: b

-- # A column that a view uses can't be dropped (see
-- # std_2_11_23_drop_column.sql), but a view that can't be read (here, because
-- # k is a column of both tables) doesn't use anything.
CREATE TABLE u (k INT);
CREATE VIEW v AS SELECT * FROM t, u WHERE k = 1;
ALTER TABLE t ADD COLUMN k INT;
ALTER TABLE t DROP COLUMN y RESTRICT;
ALTER TABLE t DROP COLUMN k RESTRICT;
SELECT * FROM v;
-- msg: CREATE TABLE 1
-- msg: CREATE VIEW 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- error 42601: syntax error: view ":memory:".PUBLIC.V has 3 columns, but its query has 2

-- # A view can't be changed yet (#1448).
CREATE VIEW v AS SELECT x FROM t;
INSERT INTO v (x) VALUES (1);
UPDATE v SET x = 1;
DELETE FROM v;
DROP TABLE v RESTRICT;
-- msg: CREATE VIEW 1
-- error 42601: syntax error: ":memory:".PUBLIC.V is a view, not a table
-- error 42601: syntax error: ":memory:".PUBLIC.V is a view, not a table
-- error 42601: syntax error: ":memory:".PUBLIC.V is a view, not a table
-- error 42601: syntax error: ":memory:".PUBLIC.V is a view, not a table

-- # A view is kept in the file, and a ROLLBACK undoes it.
CREATE VIEW v AS SELECT x FROM t;
START TRANSACTION;
CREATE VIEW w AS SELECT y FROM t;
ROLLBACK;
SELECT COUNT(*) FROM v;
SELECT * FROM w;
-- msg: CREATE VIEW 1
-- msg: START TRANSACTION
-- msg: CREATE VIEW 1
-- msg: ROLLBACK
-- COL1: 3
-- error 42P01: no such table: ":memory:".PUBLIC.W

-- # EXPLAIN only works for queries, but it can explain a query of a view.
EXPLAIN CREATE VIEW v AS SELECT x FROM t;
-- error 42601: syntax error: Cannot EXPLAIN CREATE VIEW
