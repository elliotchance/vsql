-- # SET SCHEMA changes the session, so it can't be explained.
EXPLAIN SET SCHEMA 'foo';
-- error 42601: syntax error: Cannot EXPLAIN SET SCHEMA

-- # The value is used as the schema name exactly as it is, not as an
-- # identifier, so CREATE SCHEMA foo is found by 'FOO'. A schema that doesn't
-- # exist is 3F000 and the current schema doesn't change. vsql deviates from
-- # General Rules, 2 here: the value must be the name of an existing schema,
-- # rather than anything that's a valid schema name (#231).
CREATE SCHEMA foo;
VALUES CURRENT_SCHEMA;
SET SCHEMA 'FOO';
VALUES CURRENT_SCHEMA;
-- msg: CREATE SCHEMA 1
-- COL1: PUBLIC
-- msg: SET SCHEMA 1
-- COL1: FOO

SET SCHEMA 'foo';
VALUES CURRENT_SCHEMA;
-- error 3F000: invalid schema name: foo
-- COL1: PUBLIC

-- # The value can be a parameter.
/* params 'PUBLIC' */
SET SCHEMA ?;
VALUES CURRENT_SCHEMA;
-- sql: SET SCHEMA 'PUBLIC'
-- msg: SET SCHEMA 1
-- COL1: PUBLIC
