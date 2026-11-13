/* setup */
CREATE TABLE t (a INT NOT NULL, b VARCHAR(10));
INSERT INTO t (a, b) VALUES (1, 'one'), (2, 'two'), (3, NULL);
CREATE SEQUENCE s;

CREATE VIEW v AS SELECT a, b FROM t WHERE a > 1;
SELECT * FROM v;
-- msg: CREATE VIEW 1
-- A: 2 B: two
-- A: 3 B: NULL

CREATE VIEW v AS SELECT * FROM t;
SELECT v.a, x.b FROM v, v AS x WHERE v.a = x.a;
SELECT * FROM v WHERE b IS NULL;
-- msg: CREATE VIEW 1
-- A: 1 B: one
-- A: 2 B: two
-- A: 3 B: NULL
-- A: 3 B: NULL

CREATE VIEW v (x, y) AS SELECT a * 10, UPPER(b) FROM t;
SELECT y, x FROM v ORDER BY x DESC;
-- msg: CREATE VIEW 1
-- Y: NULL X: 30
-- Y: TWO X: 20
-- Y: ONE X: 10

CREATE VIEW v AS SELECT a * 10 FROM t;
-- error 42601: syntax error: view ":memory:".PUBLIC.V needs a column list because column 1 of its query has no name

CREATE VIEW v AS SELECT a, a FROM t;
-- error 42601: syntax error: column A is specified more than once in view ":memory:".PUBLIC.V

CREATE VIEW v (x) AS SELECT a, b FROM t;
-- error 42601: syntax error: view ":memory:".PUBLIC.V has 1 column, but its query has 2

CREATE VIEW t AS SELECT 1 AS x FROM t;
-- error 42P07: duplicate table: ":memory:".PUBLIC.T

CREATE VIEW v AS SELECT a FROM t;
CREATE VIEW v AS SELECT a FROM t;
-- msg: CREATE VIEW 1
-- error 42P07: duplicate table: ":memory:".PUBLIC.V

CREATE VIEW v AS SELECT a FROM t;
CREATE TABLE v (x INT);
-- msg: CREATE VIEW 1
-- error 42P07: duplicate table: ":memory:".PUBLIC.V

CREATE VIEW v AS SELECT a FROM t;
INSERT INTO v (a) VALUES (4);
-- msg: CREATE VIEW 1
-- error 42601: syntax error: ":memory:".PUBLIC.V is a view, not a base table

CREATE VIEW v AS SELECT a FROM t;
UPDATE v SET a = 4;
-- msg: CREATE VIEW 1
-- error 42601: syntax error: ":memory:".PUBLIC.V is a view, not a base table

CREATE VIEW v AS SELECT a FROM t;
DELETE FROM v;
-- msg: CREATE VIEW 1
-- error 42601: syntax error: ":memory:".PUBLIC.V is a view, not a base table

CREATE VIEW v AS SELECT a FROM nope;
-- error 42P01: no such table: ":memory:".PUBLIC.NOPE

CREATE VIEW v AS SELECT a FROM t UNION SELECT a + 10 FROM t EXCEPT SELECT 2 FROM t;
SELECT * FROM v ORDER BY a;
-- msg: CREATE VIEW 1
-- A: 1
-- A: 3
-- A: 11
-- A: 12
-- A: 13

CREATE VIEW v AS SELECT a FROM t ORDER BY a DESC OFFSET 1 ROW FETCH FIRST 1 ROW ONLY;
SELECT * FROM v;
-- msg: CREATE VIEW 1
-- A: 2

CREATE VIEW v AS SELECT a FROM t;
CREATE VIEW w AS SELECT v.a, t.b FROM v JOIN t ON v.a = t.a WHERE v.a < 3;
SELECT * FROM w;
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- A: 1 B: one
-- A: 2 B: two

CREATE VIEW v AS SELECT COUNT(*) AS c FROM t;
INSERT INTO t (a) VALUES (10);
SELECT * FROM v;
-- msg: CREATE VIEW 1
-- msg: INSERT 1
-- C: 4

CREATE VIEW v AS SELECT * FROM t;
ALTER TABLE t ADD COLUMN c INT;
SELECT * FROM v;
-- msg: CREATE VIEW 1
-- msg: ALTER TABLE 1
-- A: 1 B: one
-- A: 2 B: two
-- A: 3 B: NULL

CREATE VIEW v AS SELECT a FROM t WHERE a IN (SELECT a FROM t WHERE b IS NOT NULL);
SELECT * FROM v;
-- msg: CREATE VIEW 1
-- A: 1
-- A: 2

CREATE VIEW v AS SELECT NEXT VALUE FOR s FROM t;
-- error 42601: syntax error: NEXT VALUE FOR cannot be used in a view

/* extensions V001-01 */
EXPLAIN SELECT * FROM v;
-- error 42P01: no such table: ":memory:".PUBLIC.V

/* extensions V001-01 */
CREATE VIEW v AS SELECT a FROM t;
EXPLAIN SELECT * FROM v;
-- msg: CREATE VIEW 1
-- EXPLAIN: :memory:.PUBLIC.V:
-- EXPLAIN:   VIEW ":memory:".PUBLIC.V
-- EXPLAIN:     TABLE ":memory:".PUBLIC.T (A INTEGER NOT NULL, B CHARACTER VARYING(10))
-- EXPLAIN:     EXPR (A INTEGER NOT NULL)
-- EXPLAIN: TABLE ":memory:".PUBLIC.V (A INTEGER NOT NULL)
-- EXPLAIN: EXPR (":memory:".PUBLIC.V.A INTEGER NOT NULL)

EXPLAIN CREATE VIEW v AS SELECT a FROM t;
-- error 42601: syntax error: Cannot EXPLAIN CREATE VIEW

CREATE TABLE u (a INT, c INT);
INSERT INTO u (a, c) VALUES (1, 100), (2, 200);
CREATE VIEW v AS SELECT * FROM t JOIN u USING (a);
CREATE VIEW w AS SELECT u.*, x.* FROM u, (SELECT b FROM t WHERE a = 1) AS x;
CREATE VIEW x AS SELECT * FROM (VALUES ROW(1, 2)) AS z (p, q);
ALTER TABLE t ADD COLUMN d INT;
ALTER TABLE u ADD COLUMN e INT;
SELECT * FROM v;
SELECT * FROM w;
SELECT * FROM x;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- A: 1 B: one C: 100
-- A: 2 B: two C: 200
-- A: 1 C: 100 B: one
-- A: 2 C: 200 B: one
-- P: 1 Q: 2

CREATE VIEW v AS SELECT * FROM t;
SELECT x.a FROM v AS x WHERE x.a = 2;
SELECT v.* FROM v WHERE v.a = 2;
SELECT public.v.a FROM public.v WHERE a = 3;
SELECT y.p FROM v AS y (p, q) WHERE y.p = 1;
-- msg: CREATE VIEW 1
-- A: 2
-- A: 2 B: two
-- A: 3
-- P: 1

-- # A name in the query of a view without a schema is in the current schema
-- # when the view is created (5.4, Syntax Rules, 4), even when the view is in
-- # another schema, and wherever it's read from.
CREATE SCHEMA s2;
CREATE TABLE s2.t (z VARCHAR(10));
INSERT INTO s2.t (z) VALUES ('in s2');
CREATE VIEW s2.v AS SELECT a, (SELECT COUNT(*) FROM t) AS n FROM t WHERE t.a = 1;
SET SCHEMA 'S2';
CREATE VIEW w AS SELECT z, (SELECT COUNT(*) FROM t) AS n FROM t;
SELECT * FROM v;
SELECT * FROM w;
SET SCHEMA 'PUBLIC';
SELECT * FROM s2.v;
SELECT * FROM s2.w;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: CREATE VIEW 1
-- msg: SET SCHEMA 1
-- msg: CREATE VIEW 1
-- A: 1 N: 3
-- Z: in s2 N: 1
-- msg: SET SCHEMA 1
-- A: 1 N: 3
-- Z: in s2 N: 1

/* params 1 */
CREATE VIEW v AS SELECT a FROM t WHERE a = ?;
-- sql: CREATE VIEW v AS SELECT a FROM t WHERE a = 1.0e0
-- error 42601: syntax error: a view cannot contain parameters

CREATE VIEW information_schema.v AS SELECT a FROM t;
-- error 42501: insufficient privilege: INFORMATION_SCHEMA is read-only

CREATE VIEW nope.v AS SELECT a FROM t;
-- error 3F000: invalid schema name: NOPE

/* create_catalog FOO */
SET CATALOG ':memory:';
CREATE TABLE foo.public.bar (baz INTEGER);
CREATE VIEW v AS SELECT baz FROM foo.public.bar;
-- msg: SET CATALOG 1
-- msg: CREATE TABLE 1
-- error 42601: syntax error: a view cannot read FOO.PUBLIC.BAR because it is in another catalog

-- # A view can't be changed through a cursor, but it can be read with one.
/* extensions V108-01 V109-01 V110-01 */
CREATE VIEW v AS SELECT a FROM t;
START TRANSACTION;
DECLARE c CURSOR FOR SELECT a FROM v;
OPEN c;
FETCH NEXT FROM c;
ROLLBACK;
DECLARE d CURSOR FOR SELECT a FROM v FOR UPDATE;
-- msg: CREATE VIEW 1
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- A: 1
-- msg: ROLLBACK
-- error 42601: syntax error: cursor D is not updatable

/* flags */
CREATE VIEW v AS SELECT a FROM t;
-- flags:
-- msg: CREATE VIEW 1

/* flags */
CREATE VIEW v (x) AS SELECT a FROM t UNION SELECT a FROM t;
-- flags:
-- msg: CREATE VIEW 1

/* flags */
CREATE VIEW v AS SELECT a FROM t ORDER BY a;
-- flags: F852
-- msg: CREATE VIEW 1

/* flags */
CREATE VIEW v AS SELECT a FROM t OFFSET 1 ROW;
-- flags: F864
-- msg: CREATE VIEW 1

/* flags */
CREATE VIEW v AS SELECT a FROM t FETCH FIRST 1 ROW ONLY;
-- flags: F859
-- msg: CREATE VIEW 1

-- # The features that the query of a view uses aren't flagged when it's read.
CREATE VIEW v AS SELECT a FROM t ORDER BY a FETCH FIRST 1 ROW ONLY;
/* flags */
SELECT * FROM v;
-- flags: F852, F859
-- msg: CREATE VIEW 1
-- flags:
-- A: 1

-- # A view can only read a view that exists, so it can't read itself.
CREATE VIEW v AS SELECT * FROM v;
-- error 42P01: no such table: ":memory:".PUBLIC.V

CREATE VIEW v (x, y) AS VALUES ROW(1, 'a'), ROW(2, 'b');
SELECT * FROM v WHERE x = 2;
-- msg: CREATE VIEW 1
-- X: 2 Y: b

CREATE VIEW v AS (SELECT * FROM t ORDER BY a DESC FETCH FIRST 1 ROW ONLY) UNION SELECT * FROM t WHERE a = 1;
SELECT * FROM v ORDER BY a;
-- msg: CREATE VIEW 1
-- A: 1 B: one
-- A: 3 B: NULL

CREATE VIEW v AS SELECT a FROM t;
MERGE INTO v USING t ON v.a = t.a WHEN MATCHED THEN UPDATE SET a = 1;
-- msg: CREATE VIEW 1
-- error 42601: syntax error: ":memory:".PUBLIC.V is a view, not a base table

CREATE VIEW v AS SELECT * FROM FINAL TABLE (INSERT INTO t (a) VALUES (4));
-- error 42601: syntax error: FINAL TABLE can only be the only table in the FROM of a query that is a statement or cursor
