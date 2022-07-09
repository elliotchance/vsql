EXPLAIN DROP SCHEMA foo RESTRICT;
-- error 42601: syntax error: Cannot EXPLAIN DROP SCHEMA

DROP SCHEMA foo RESTRICT;
-- error 3F000: invalid schema name: FOO

CREATE SCHEMA foo;
DROP SCHEMA foo RESTRICT;
-- msg: CREATE SCHEMA 1
-- msg: DROP SCHEMA 1

CREATE SCHEMA foo;
DROP SCHEMA foo RESTRICT;
DROP SCHEMA foo RESTRICT;
-- msg: CREATE SCHEMA 1
-- msg: DROP SCHEMA 1
-- error 3F000: invalid schema name: FOO

CREATE SCHEMA foo;
CREATE TABLE foo.bar (baz INT);
DROP SCHEMA foo RESTRICT;
INSERT INTO foo.bar (baz) VALUES (123);
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- error 2BP01: dependent objects still exist on FOO
-- msg: INSERT 1

CREATE SCHEMA foo;
CREATE TABLE foo.bar (baz INT);
DROP SCHEMA foo CASCADE;
INSERT INTO foo.bar (baz) VALUES (123);
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: DROP SCHEMA 1
-- error 3F000: invalid schema name: FOO
