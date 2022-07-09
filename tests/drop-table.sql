DROP TABLE foo;
-- error 42P01: no such table: FOO

CREATE TABLE foo (x FLOAT);
DROP TABLE foo;
DROP TABLE foo;
-- msg: CREATE TABLE 1
-- msg: DROP TABLE 1
-- error 42P01: no such table: FOO

DROP TABLE foo.bar;
-- error 3F000: invalid schema name: FOO

CREATE SCHEMA foo;
CREATE TABLE foo.bar (baz BIGINT);
DROP TABLE foo.bar;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: DROP TABLE 1
