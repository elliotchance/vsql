/* setup */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);

-- # The view must exist and be a view (Syntax Rules, 1 and 2).
DROP VIEW v RESTRICT;
-- error 42P01: no such view: ":memory:".PUBLIC.V

DROP VIEW t RESTRICT;
-- error 42601: syntax error: ":memory:".PUBLIC.T is a table, not a view

DROP VIEW s.v RESTRICT;
-- error 3F000: invalid schema name: S

-- # The view is destroyed (General Rules, 5), so it can't be read, and the
-- # name can be used again.
CREATE VIEW v AS SELECT x FROM t;
DROP VIEW v RESTRICT;
SELECT * FROM v;
DROP VIEW v RESTRICT;
CREATE TABLE v (y INT);
-- msg: CREATE VIEW 1
-- msg: DROP VIEW 1
-- error 42P01: no such table: ":memory:".PUBLIC.V
-- error 42P01: no such view: ":memory:".PUBLIC.V
-- msg: CREATE TABLE 1

-- # CASCADE works the same as RESTRICT. Nothing records which views read a
-- # view yet (#1264), so a view that reads a dropped view is an error when it's
-- # read.
CREATE VIEW v AS SELECT x FROM t;
CREATE VIEW w AS SELECT x FROM v;
DROP VIEW v CASCADE;
SELECT * FROM w;
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: DROP VIEW 1
-- error 42P01: no such table: ":memory:".PUBLIC.V

-- # A ROLLBACK undoes it.
CREATE VIEW v AS SELECT x FROM t;
START TRANSACTION;
DROP VIEW v RESTRICT;
ROLLBACK;
SELECT * FROM v;
-- msg: CREATE VIEW 1
-- msg: START TRANSACTION
-- msg: DROP VIEW 1
-- msg: ROLLBACK
-- X: 1

-- # DROP SCHEMA drops its views with CASCADE, but not with RESTRICT.
CREATE SCHEMA s;
CREATE VIEW s.v AS SELECT x FROM public.t;
DROP SCHEMA s RESTRICT;
DROP SCHEMA s CASCADE;
SELECT * FROM s.v;
-- msg: CREATE SCHEMA 1
-- msg: CREATE VIEW 1
-- error 2BP01: dependent objects still exist on S
-- msg: DROP SCHEMA 1
-- error 3F000: invalid schema name: S

EXPLAIN DROP VIEW v RESTRICT;
-- error 42601: syntax error: Cannot EXPLAIN DROP VIEW
