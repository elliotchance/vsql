EXPLAIN SET SCHEMA 'foo';
-- error 42601: syntax error: Cannot EXPLAIN SET SCHEMA

CREATE SCHEMA foo;
VALUES CURRENT_SCHEMA;
SET SCHEMA 'FOO';
VALUES CURRENT_SCHEMA;
-- msg: CREATE SCHEMA 1
-- COL1: PUBLIC
-- msg: SET SCHEMA 1
-- COL1: FOO

-- # The value is an identifier, so 'foo' is FOO, and a lower case name must be
-- # delimited.
CREATE SCHEMA foo;
CREATE SCHEMA "bar";
SET SCHEMA 'foo';
VALUES CURRENT_SCHEMA;
SET SCHEMA 'bar';
SET SCHEMA '"bar"';
VALUES CURRENT_SCHEMA;
SET SCHEMA 'information_schema';
VALUES CURRENT_SCHEMA;
-- msg: CREATE SCHEMA 1
-- msg: CREATE SCHEMA 1
-- msg: SET SCHEMA 1
-- COL1: FOO
-- error 3F000: invalid schema name: BAR
-- msg: SET SCHEMA 1
-- COL1: bar
-- msg: SET SCHEMA 1
-- COL1: INFORMATION_SCHEMA

-- # A value that isn't one identifier.
SET SCHEMA 'foo bar';
SET SCHEMA '';
SET SCHEMA '"foo';
VALUES CURRENT_SCHEMA;
-- error 3F000: invalid schema name: foo bar
-- error 3F000: invalid schema name: 
-- error 3F000: invalid schema name: "foo
-- COL1: PUBLIC

/* params 'PUBLIC' */
SET SCHEMA ?;
VALUES CURRENT_SCHEMA;
-- sql: SET SCHEMA 'PUBLIC'
-- msg: SET SCHEMA 1
-- COL1: PUBLIC
