-- # A table that doesn't exist is an error.
SELECT * FROM foo;
-- error 42P01: no such table: ":memory:".PUBLIC.FOO

-- # Unquoted names are folded to upper case but delimited names aren't, so
-- # foo and "Foo" are different tables.
CREATE TABLE foo (x FLOAT);
INSERT INTO foo (x) VALUES (1.234);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- X: 1.234e0

CREATE TABLE "Foo" ("a" FLOAT);
INSERT INTO "Foo" ("a") VALUES (4.56);
SELECT * FROM "Foo";
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- a: 4.56e0

CREATE TABLE foo (x FLOAT);
CREATE TABLE "Foo" ("a" FLOAT);
INSERT INTO FOO (x) VALUES (1.234);
INSERT INTO "Foo" ("a") VALUES (4.56);
SELECT * FROM Foo;
SELECT * FROM "Foo";
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- X: 1.234e0
-- a: 4.56e0

-- # A statement can span lines. Each test starts without tables, so both are
-- # missing.
SELECT *
FROM foo;
SELECT * FROM bar;
-- error 42P01: no such table: ":memory:".PUBLIC.FOO
-- error 42P01: no such table: ":memory:".PUBLIC.BAR

-- # A qualified asterisk must name a table in FROM.
/* extensions V001-01 */
CREATE TABLE foo (x FLOAT);
EXPLAIN SELECT foo.* FROM foo;
-- msg: CREATE TABLE 1
-- EXPLAIN: TABLE ":memory:".PUBLIC.FOO (X DOUBLE PRECISION)
-- EXPLAIN: EXPR (":memory:".PUBLIC.FOO.X DOUBLE PRECISION)

CREATE TABLE foo (x FLOAT);
INSERT INTO foo (x) VALUES (1.234);
SELECT foo.* FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- X: 1.234e0

/* extensions V001-01 */
CREATE TABLE foo (x FLOAT);
EXPLAIN SELECT bar.* FROM foo;
-- msg: CREATE TABLE 1
-- error 42P01: no such table: ":memory:".PUBLIC.BAR

-- # A table name can be qualified by its schema, which must exist.
SELECT * FROM foo.bar;
-- error 3F000: invalid schema name: FOO

CREATE SCHEMA foo;
CREATE TABLE foo.bar (x FLOAT);
INSERT INTO foo.bar (x) VALUES (1.234);
SELECT * FROM foo.bar;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- X: 1.234e0

-- # A delimited name can contain a colon, and another connection sees the
-- # same tables.
CREATE TABLE "A" (x INT);
CREATE TABLE "A:B" (y VARCHAR(10));
INSERT INTO "A:B" (y) VALUES ('hello');
SELECT * FROM "A";
SELECT * FROM "A:B";
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- Y: hello

/* connection 1 */
CREATE TABLE "A" (x INT);
CREATE TABLE "A:B" (y VARCHAR(10));
INSERT INTO "A" (x) VALUES (1);
INSERT INTO "A:B" (y) VALUES ('hello');
/* connection 2 */
SELECT * FROM "A";
SELECT * FROM "A:B";
-- 1: msg: CREATE TABLE 1
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: INSERT 1
-- 2: X: 1
-- 2: Y: hello

-- # A dot in a delimited name is part of the name, not a qualifier, so
-- # "A.B".c and a."B.C" are different tables in different schemas.
CREATE SCHEMA "A.B";
CREATE SCHEMA a;
CREATE TABLE "A.B".c (x INT);
CREATE TABLE a."B.C" (y INT);
INSERT INTO "A.B".c (x) VALUES (1);
INSERT INTO a."B.C" (y) VALUES (2);
SELECT * FROM "A.B".c;
SELECT * FROM a."B.C";
DROP SCHEMA "A.B" CASCADE;
SELECT * FROM a."B.C";
-- msg: CREATE SCHEMA 1
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- X: 1
-- Y: 2
-- msg: DROP SCHEMA 1
-- Y: 2

/* connection 1 */
CREATE SCHEMA "A.B";
CREATE SCHEMA a;
CREATE TABLE "A.B".c (x INT);
CREATE TABLE a."B.C" (y INT);
INSERT INTO "A.B".c (x) VALUES (1);
INSERT INTO a."B.C" (y) VALUES (2);
/* connection 2 */
SELECT * FROM "A.B".c;
SELECT * FROM a."B.C";
-- 1: msg: CREATE SCHEMA 1
-- 1: msg: CREATE SCHEMA 1
-- 1: msg: CREATE TABLE 1
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: INSERT 1
-- 2: X: 1
-- 2: Y: 2

-- # A derived table's correlation name doesn't need AS, and can rename the
-- # columns.
SELECT * FROM (VALUES 1) t;
-- COL1: 1

SELECT * FROM (VALUES 1) t (x);
-- X: 1
