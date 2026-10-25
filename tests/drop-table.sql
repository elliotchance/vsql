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

CREATE TABLE foo (x INT);
DROP TABLE foo RESTRICT;
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: DROP TABLE 1
-- error 42P01: no such table: ":memory:".PUBLIC.FOO

CREATE TABLE foo (x INT);
INSERT INTO foo (x) VALUES (1);
DROP TABLE foo CASCADE;
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: DROP TABLE 1
-- error 42P01: no such table: ":memory:".PUBLIC.FOO

-- # A FOREIGN KEY of the table itself doesn't stop RESTRICT.
CREATE TABLE foo (id INT PRIMARY KEY, parent INT REFERENCES foo);
INSERT INTO foo (id, parent) VALUES (1, NULL), (2, 1);
DROP TABLE foo RESTRICT;
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: DROP TABLE 1
-- error 42P01: no such table: ":memory:".PUBLIC.FOO

DROP TABLE foo RESTRICT;
-- error 42P01: no such table: ":memory:".PUBLIC.FOO

DROP TABLE foo CASCADE;
-- error 42P01: no such table: ":memory:".PUBLIC.FOO

EXPLAIN DROP TABLE foo CASCADE;
-- error 42601: syntax error: Cannot EXPLAIN DROP TABLE

CREATE TABLE foo (x INT);
DROP TABLE foo RESTRICT CASCADE;
-- msg: CREATE TABLE 1
-- error 42601: syntax error: unexpected CASCADE
