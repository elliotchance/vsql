EXPLAIN CREATE SCHEMA foo;
-- error 42601: syntax error: Cannot EXPLAIN CREATE SCHEMA

CREATE SCHEMA foo;
-- msg: CREATE SCHEMA 1

CREATE SCHEMA foo;
CREATE SCHEMA foo;
-- msg: CREATE SCHEMA 1
-- error 42P06: duplicate schema: FOO

CREATE SCHEMA foo;
CREATE TABLE foo.bar (baz INT);
INSERT INTO foo.bar (baz) VALUES (123);
SELECT * FROM foo.bar;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- BAZ: 123
