-- # Table, schema and sequence names can be qualified with a catalog.
/* create_catalog FOO */
SET CATALOG 'FOO';
CREATE TABLE foo.public.bar (baz INTEGER);
INSERT INTO foo.public.bar (baz) VALUES (123);
SELECT * FROM foo.public.bar;
UPDATE foo.public.bar SET baz = 456;
SELECT bar.baz FROM foo.public.bar;
DELETE FROM foo.public.bar;
SELECT * FROM foo.public.bar;
DROP TABLE foo.public.bar RESTRICT;
-- msg: SET CATALOG 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- BAZ: 123
-- msg: UPDATE 1
-- BAZ: 456
-- msg: DELETE 1
-- msg: DROP TABLE 1

/* create_catalog FOO */
/* extensions V001-01 */
SET CATALOG 'FOO';
CREATE SCHEMA foo.s1;
CREATE TABLE foo.s1.t1 (x INT);
EXPLAIN SELECT * FROM foo.s1.t1;
DROP SCHEMA foo.s1 CASCADE;
-- msg: SET CATALOG 1
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- EXPLAIN: TABLE FOO.S1.T1 (X INTEGER)
-- EXPLAIN: EXPR (FOO.S1.T1.X INTEGER)
-- msg: DROP SCHEMA 1

-- # A catalog that isn't the current one can be used in every statement.
/* create_catalog FOO */
SET CATALOG 'FOO';
CREATE TABLE public.bar (baz INTEGER);
INSERT INTO public.bar (baz) VALUES (123);
SET CATALOG ':memory:';
SELECT * FROM foo.public.bar;
UPDATE foo.public.bar SET baz = 5;
INSERT INTO foo.public.bar (baz) VALUES (7);
DELETE FROM foo.public.bar WHERE baz = 5;
SELECT * FROM foo.public.bar;
DROP TABLE foo.public.bar RESTRICT;
SELECT * FROM foo.public.bar;
-- msg: SET CATALOG 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: SET CATALOG 1
-- BAZ: 123
-- msg: UPDATE 1
-- msg: INSERT 1
-- msg: DELETE 1
-- BAZ: 7
-- msg: DROP TABLE 1
-- error 42P01: no such table: FOO.PUBLIC.BAR

/* create_catalog FOO */
/* extensions V001-01 */
SET CATALOG ':memory:';
CREATE TABLE foo.public.qux (baz INTEGER NOT NULL, PRIMARY KEY (baz));
INSERT INTO foo.public.qux (baz) VALUES (1), (2);
EXPLAIN SELECT * FROM foo.public.qux WHERE baz = 2;
SELECT * FROM foo.public.qux WHERE baz = 2;
SELECT * FROM qux;
SET CATALOG 'FOO';
SELECT * FROM qux;
-- msg: SET CATALOG 1
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- EXPLAIN: PRIMARY KEY FOO.PUBLIC.QUX (BAZ INTEGER NOT NULL) BETWEEN 2 AND 2
-- EXPLAIN: EXPR (FOO.PUBLIC.QUX.BAZ INTEGER NOT NULL)
-- BAZ: 2
-- error 42P01: no such table: ":memory:".PUBLIC.QUX
-- msg: SET CATALOG 1
-- BAZ: 1
-- BAZ: 2

/* create_catalog FOO */
SET CATALOG ':memory:';
CREATE SCHEMA foo.s2;
CREATE SEQUENCE foo.s2.seq;
VALUES NEXT VALUE FOR foo.s2.seq;
ALTER SEQUENCE foo.s2.seq RESTART WITH 10;
VALUES NEXT VALUE FOR foo.s2.seq;
DROP SEQUENCE foo.s2.seq RESTRICT;
DROP SCHEMA foo.s2 RESTRICT;
SET CATALOG 'FOO';
SET SCHEMA 'S2';
-- msg: SET CATALOG 1
-- msg: CREATE SCHEMA 1
-- msg: CREATE SEQUENCE 1
-- COL1: 1
-- msg: ALTER SEQUENCE 1
-- COL1: 10
-- msg: DROP SEQUENCE 1
-- msg: DROP SCHEMA 1
-- msg: SET CATALOG 1
-- error 3F000: invalid schema name: S2

SELECT * FROM nope.public.t1;
-- error 3D000: invalid catalog name: NOPE

CREATE TABLE nope.public.t1 (x INT);
-- error 3D000: invalid catalog name: NOPE

CREATE SCHEMA nope.s1;
-- error 3D000: invalid catalog name: NOPE

VALUES NEXT VALUE FOR nope.public.seq;
-- error 3D000: invalid catalog name: NOPE

CREATE TABLE "my catalog".public.t1 (x INT);
-- error 3D000: invalid catalog name: my catalog

SELECT * FROM a.b.c.d;
-- error 42601: syntax error: unexpected "."
