DROP TABLE foo;
-- error 42P01: no such table: ":memory:".PUBLIC.FOO

CREATE TABLE foo (x FLOAT);
DROP TABLE foo;
DROP TABLE foo;
-- msg: CREATE TABLE 1
-- msg: DROP TABLE 1
-- error 42P01: no such table: ":memory:".PUBLIC.FOO

DROP TABLE foo.bar;
-- error 3F000: invalid schema name: FOO

CREATE SCHEMA foo;
CREATE TABLE foo.bar (baz BIGINT);
DROP TABLE foo.bar;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: DROP TABLE 1

CREATE TABLE foo (x INT);
INSERT INTO foo (x) VALUES (1);
INSERT INTO foo (x) VALUES (2);
DROP TABLE foo;
CREATE TABLE foo (x INT);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: DROP TABLE 1
-- msg: CREATE TABLE 1

CREATE TABLE foo (x INT);
INSERT INTO foo (x) VALUES (1);
CREATE TABLE "FOO:BAR" (y INT);
INSERT INTO "FOO:BAR" (y) VALUES (2);
DROP TABLE foo;
SELECT * FROM "FOO:BAR";
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: DROP TABLE 1
-- Y: 2
