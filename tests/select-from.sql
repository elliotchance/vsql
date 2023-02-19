SELECT * FROM foo;
-- error 42P01: no such table: ":memory:".PUBLIC.FOO

CREATE TABLE foo (x FLOAT);
INSERT INTO foo (x) VALUES (1.234);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- X: 1.234

CREATE TABLE "Foo" ("a" FLOAT);
INSERT INTO "Foo" ("a") VALUES (4.56);
SELECT * FROM "Foo";
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- a: 4.56

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
-- X: 1.234
-- a: 4.56

SELECT *
FROM foo;
SELECT * FROM bar;
-- error 42P01: no such table: ":memory:".PUBLIC.FOO
-- error 42P01: no such table: ":memory:".PUBLIC.BAR

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
-- X: 1.234

CREATE TABLE foo (x FLOAT);
EXPLAIN SELECT bar.* FROM foo;
-- msg: CREATE TABLE 1
-- error 42P01: no such table: ":memory:".PUBLIC.BAR

SELECT * FROM foo.bar;
-- error 3F000: invalid schema name: FOO

CREATE SCHEMA foo;
CREATE TABLE foo.bar (x FLOAT);
INSERT INTO foo.bar (x) VALUES (1.234);
SELECT * FROM foo.bar;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- X: 1.234
