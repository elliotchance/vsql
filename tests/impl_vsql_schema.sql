-- # The VSQL schema is in every catalog, like the INFORMATION_SCHEMA.
SELECT schema_name, schema_owner FROM information_schema.schemata;
-- SCHEMA_NAME: INFORMATION_SCHEMA SCHEMA_OWNER: _SYSTEM
-- SCHEMA_NAME: PUBLIC SCHEMA_OWNER: _SYSTEM
-- SCHEMA_NAME: VSQL SCHEMA_OWNER: _SYSTEM

-- # It can't be created, dropped or changed.
CREATE SCHEMA vsql;
-- error 42P06: duplicate schema: VSQL

/* extensions V101-01 */
CREATE SCHEMA IF NOT EXISTS vsql;
-- msg: CREATE SCHEMA 0

DROP SCHEMA vsql CASCADE;
-- error 42501: insufficient privilege: VSQL is read-only

CREATE TABLE vsql.t (x INT);
-- error 42501: insufficient privilege: VSQL is read-only

CREATE SEQUENCE vsql.s;
-- error 42501: insufficient privilege: VSQL is read-only

-- # It can be the default schema, but nothing can be created in it.
SET SCHEMA 'VSQL';
CREATE TABLE t (x INT);
-- msg: SET SCHEMA 1
-- error 42501: insufficient privilege: VSQL is read-only

-- # A function that's a vsql extension is a routine of the VSQL schema, so it
-- # can be qualified by its name. VSQL is always the last schema of the
-- # SQL-path, so it's also found without it.
VALUES VSQL.GCD(12, 18);
VALUES vsql.gcd(12, 18);
VALUES GCD(12, 18);
-- COL1: 6
-- COL1: 6
-- COL1: 6

VALUES ":memory:".VSQL.GCD(12, 18);
-- COL1: 6

VALUES nosuch.VSQL.GCD(12, 18);
-- error 3D000: invalid catalog name: NOSUCH

-- # A standard function isn't a routine, so it isn't in the VSQL schema (and
-- # its name is a reserved word, so it has to be quoted). Neither is an
-- # aggregate function.
VALUES VSQL."LOWER"('A');
-- error 42883: function does not exist: VSQL.LOWER(CHARACTER(1))

CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (2), (3);
SELECT VSQL.PRODUCT(x) FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- error 42883: function does not exist: VSQL.PRODUCT(INTEGER)

-- # A qualified name only finds the routines of that schema, and the schema must
-- # exist.
VALUES information_schema.gcd(12, 18);
-- error 42883: function does not exist: INFORMATION_SCHEMA.GCD(SMALLINT, SMALLINT)

VALUES public.gcd(12, 18);
-- error 42883: function does not exist: PUBLIC.GCD(SMALLINT, SMALLINT)

VALUES nosuch.gcd(12, 18);
-- error 3F000: invalid schema name: NOSUCH

-- # The same for a variadic function, such as CONCAT.
VALUES vsql.concat('a', 'b', 'c');
VALUES vsql.concat_ws('-', 'a', 'b');
VALUES public.concat('a');
VALUES nosuch.concat('a');
-- COL1: abc
-- COL1: a-b
-- error 42883: function does not exist: PUBLIC.CONCAT(CHARACTER(1))
-- error 3F000: invalid schema name: NOSUCH

-- # A qualified name is kept, such as in a CHECK constraint.
CREATE TABLE t (x INT CHECK (VSQL.GCD(x, 4) = 2), y INT CHECK (":memory:".vsql.gcd(y, 4) = 2));
SELECT check_clause FROM information_schema.check_constraints;
INSERT INTO t (x, y) VALUES (6, 6);
INSERT INTO t (x, y) VALUES (6, 8);
-- msg: CREATE TABLE 1
-- CHECK_CLAUSE: VSQL.GCD(X, 4) = 2
-- CHECK_CLAUSE: ":memory:".VSQL.GCD(Y, 4) = 2
-- msg: INSERT 1
-- error 23514: violates check constraint: CHECK (":memory:".VSQL.GCD(Y, 4) = 2) on ":memory:".PUBLIC.T
