/* setup */
CREATE TABLE t (a INT NOT NULL, b VARCHAR(10));
INSERT INTO t (a, b) VALUES (1, 'one'), (2, 'two');

CREATE VIEW v AS SELECT a FROM t;
DROP VIEW v RESTRICT;
SELECT * FROM v;
-- msg: CREATE VIEW 1
-- msg: DROP VIEW 1
-- error 42P01: no such table: ":memory:".PUBLIC.V

DROP VIEW v RESTRICT;
-- error 42P01: no such view: ":memory:".PUBLIC.V

DROP VIEW t CASCADE;
-- error 42601: syntax error: ":memory:".PUBLIC.T is a base table, not a view

CREATE VIEW v AS SELECT a FROM t;
DROP TABLE v RESTRICT;
-- msg: CREATE VIEW 1
-- error 42601: syntax error: ":memory:".PUBLIC.V is a view, not a base table

EXPLAIN DROP VIEW v RESTRICT;
-- error 42601: syntax error: Cannot EXPLAIN DROP VIEW

CREATE VIEW v AS SELECT a FROM t;
CREATE VIEW w AS SELECT a + 1 AS b FROM v;
DROP VIEW v RESTRICT;
SELECT * FROM w;
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- error 2BP01: dependent objects still exist on ":memory:".PUBLIC.V (view ":memory:".PUBLIC.W depends on it)
-- B: 2
-- B: 3

CREATE VIEW v AS SELECT a FROM t;
CREATE VIEW w AS SELECT a + 1 AS b FROM v;
CREATE VIEW x AS SELECT b FROM w;
CREATE VIEW y AS SELECT b FROM t;
DROP VIEW v CASCADE;
SELECT * FROM w;
SELECT * FROM x;
SELECT * FROM y;
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: DROP VIEW 1
-- error 42P01: no such table: ":memory:".PUBLIC.W
-- error 42P01: no such table: ":memory:".PUBLIC.X
-- B: one
-- B: two

/* extensions V120-01 */
CREATE VIEW v AS SELECT a FROM t;
DROP VIEW v;
-- msg: CREATE VIEW 1
-- msg: DROP VIEW 1

CREATE VIEW v AS SELECT a FROM t;
DROP TABLE t RESTRICT;
SELECT * FROM t;
-- msg: CREATE VIEW 1
-- error 2BP01: dependent objects still exist on ":memory:".PUBLIC.T (view ":memory:".PUBLIC.V depends on it)
-- A: 1 B: one
-- A: 2 B: two

CREATE VIEW v AS SELECT a FROM t;
CREATE VIEW w AS SELECT a FROM v;
CREATE TABLE u (x INT);
INSERT INTO u (x) VALUES (7);
CREATE VIEW x AS SELECT x FROM u;
DROP TABLE t CASCADE;
SELECT * FROM v;
SELECT * FROM w;
SELECT * FROM x;
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: CREATE VIEW 1
-- msg: DROP TABLE 1
-- error 42P01: no such table: ":memory:".PUBLIC.V
-- error 42P01: no such table: ":memory:".PUBLIC.W
-- X: 7

CREATE VIEW v AS SELECT a FROM t;
CREATE VIEW w AS SELECT * FROM t;
CREATE VIEW x AS SELECT COUNT(*) AS c FROM t;
ALTER TABLE t DROP COLUMN b RESTRICT;
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- error 2BP01: dependent objects still exist on column B on ":memory:".PUBLIC.T (view ":memory:".PUBLIC.W depends on it)

CREATE VIEW v AS SELECT a FROM t;
CREATE VIEW w AS SELECT * FROM t;
CREATE VIEW x AS SELECT a FROM t WHERE b = 'one';
ALTER TABLE t DROP COLUMN b CASCADE;
SELECT * FROM v;
SELECT * FROM w;
SELECT * FROM x;
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: ALTER TABLE 1
-- A: 1
-- A: 2
-- error 42P01: no such table: ":memory:".PUBLIC.W
-- error 42P01: no such table: ":memory:".PUBLIC.X

CREATE SCHEMA s;
CREATE VIEW s.v AS SELECT a FROM public.t;
DROP SCHEMA s RESTRICT;
-- msg: CREATE SCHEMA 1
-- msg: CREATE VIEW 1
-- error 2BP01: dependent objects still exist on S

CREATE SCHEMA s;
CREATE TABLE s.u (x INT);
CREATE VIEW s.v AS SELECT x FROM s.u;
CREATE VIEW public.w AS SELECT x FROM s.v;
CREATE VIEW public.x AS SELECT a FROM t;
DROP SCHEMA s CASCADE;
SELECT * FROM w;
SELECT * FROM x;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: DROP SCHEMA 1
-- error 42P01: no such table: ":memory:".PUBLIC.W
-- A: 1
-- A: 2

/* flags */
DROP VIEW v CASCADE;
-- flags: F032
-- error 42P01: no such view: ":memory:".PUBLIC.V

/* flags */
DROP VIEW v RESTRICT;
-- flags:
-- error 42P01: no such view: ":memory:".PUBLIC.V

/* flags */
/* extensions V120-01 */
DROP VIEW v;
-- flags: V120-01
-- error 42P01: no such view: ":memory:".PUBLIC.V

-- # A view also depends on a column when dropping it would change the view,
-- # even though the view can still be read. Here the c of the subquery would be
-- # the c of u (an outer reference), which has another data type.
CREATE TABLE u (c VARCHAR(10));
INSERT INTO u (c) VALUES ('x');
ALTER TABLE t ADD COLUMN c INT;
CREATE VIEW v AS SELECT (SELECT MAX(c) FROM t) AS m FROM u;
ALTER TABLE t DROP COLUMN c RESTRICT;
ALTER TABLE t DROP COLUMN c CASCADE;
SELECT * FROM v;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: ALTER TABLE 1
-- msg: CREATE VIEW 1
-- error 2BP01: dependent objects still exist on column C on ":memory:".PUBLIC.T (view ":memory:".PUBLIC.V depends on it)
-- msg: ALTER TABLE 1
-- error 42P01: no such table: ":memory:".PUBLIC.V
