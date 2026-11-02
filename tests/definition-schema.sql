-- # DEFINITION_SCHEMA can't be the name of a schema, however it's used (#740).
CREATE SCHEMA DEFINITION_SCHEMA;
CREATE SCHEMA definition_schema;
CREATE SCHEMA "DEFINITION_SCHEMA";
CREATE SCHEMA ":memory:".DEFINITION_SCHEMA;
DROP SCHEMA DEFINITION_SCHEMA RESTRICT;
CREATE TABLE DEFINITION_SCHEMA.t (x INT);
CREATE TABLE ":memory:".DEFINITION_SCHEMA.t (x INT);
SELECT * FROM DEFINITION_SCHEMA.t;
-- error 42601: syntax error: DEFINITION_SCHEMA cannot be used as a schema name
-- error 42601: syntax error: DEFINITION_SCHEMA cannot be used as a schema name
-- error 42601: syntax error: DEFINITION_SCHEMA cannot be used as a schema name
-- error 42601: syntax error: DEFINITION_SCHEMA cannot be used as a schema name
-- error 42601: syntax error: DEFINITION_SCHEMA cannot be used as a schema name
-- error 42601: syntax error: DEFINITION_SCHEMA cannot be used as a schema name
-- error 42601: syntax error: DEFINITION_SCHEMA cannot be used as a schema name
-- error 42601: syntax error: DEFINITION_SCHEMA cannot be used as a schema name

/* setup */
CREATE TABLE t (x INT);

SELECT DEFINITION_SCHEMA.t.x FROM t;
SELECT ":memory:".DEFINITION_SCHEMA.t.x FROM t;
-- error 42601: syntax error: DEFINITION_SCHEMA cannot be used as a schema name
-- error 42601: syntax error: DEFINITION_SCHEMA cannot be used as a schema name

-- # The name only applies to schemas, and it's case sensitive when delimited.
CREATE SCHEMA "definition_schema";
CREATE TABLE definition_schema (definition_schema INT);
SELECT definition_schema FROM definition_schema;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
