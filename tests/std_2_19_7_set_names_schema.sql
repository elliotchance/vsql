SET NAMES 'UTF8';
SET NAMES 'utf8';
SET NAMES '  UTF8  ';
SET NAMES '"UTF8"';
-- msg: SET NAMES
-- msg: SET NAMES
-- msg: SET NAMES
-- msg: SET NAMES

-- # Anything else isn't a character set (19.7, General Rule 2).
SET NAMES 'LATIN1';
SET NAMES 'UTF-8';
SET NAMES '"utf8"';
SET NAMES '';
-- error 2C000: invalid character set name: LATIN1
-- error 2C000: invalid character set name: UTF-8
-- error 2C000: invalid character set name: "utf8"
-- error 2C000: invalid character set name: 

SET NAMES 1;
EXPLAIN SET NAMES 'UTF8';
SET NAMES;
-- error 42804: data type mismatch for SET NAMES: expected character string but got SMALLINT
-- error 42601: syntax error: Cannot EXPLAIN SET NAMES
-- error 42601: syntax error: unexpected $end at line 1, column 10 near "SET NAMES"

/* params 'UTF8' */
SET NAMES ?;
-- sql: SET NAMES 'UTF8'
-- msg: SET NAMES

-- # It doesn't start a transaction or use up a SET TRANSACTION, and it can be used
-- # in one.
CREATE TABLE t (x INT);
SET TRANSACTION READ ONLY;
SET NAMES 'UTF8';
INSERT INTO t (x) VALUES (1);
START TRANSACTION;
SET NAMES 'UTF8';
ROLLBACK;
-- msg: CREATE TABLE 1
-- msg: SET TRANSACTION
-- msg: SET NAMES
-- error 25006: read-only sql transaction: cannot execute INSERT
-- msg: START TRANSACTION
-- msg: SET NAMES
-- msg: ROLLBACK

-- # The key word isn't reserved.
CREATE TABLE names (names INT);
-- msg: CREATE TABLE 1

/* flags */
SET NAMES 'UTF8';
-- flags: F461, F761
-- msg: SET NAMES

-- # The value of SET SCHEMA and SET CATALOG must be a character string (Syntax
-- # Rule 1), and it's trimmed (General Rule 1).
SET SCHEMA 1;
SET CATALOG 1;
SET SCHEMA ' PUBLIC ';
VALUES CURRENT_SCHEMA;
SET CATALOG ' :memory: ';
VALUES CURRENT_CATALOG;
SET SCHEMA '"PUBLIC"';
-- error 42804: data type mismatch for SET SCHEMA: expected character string but got SMALLINT
-- error 42804: data type mismatch for SET CATALOG: expected character string but got SMALLINT
-- msg: SET SCHEMA 1
-- COL1: PUBLIC
-- msg: SET CATALOG 1
-- COL1: :memory:
-- msg: SET SCHEMA 1

-- # A schema name can have a catalog name, which also sets the catalog (19.6,
-- # General Rule 3.a).
/* create_catalog FOO */
CREATE SCHEMA foo.s;
SET SCHEMA 'foo.s';
VALUES CURRENT_CATALOG;
VALUES CURRENT_SCHEMA;
SET SCHEMA '":memory:".PUBLIC';
VALUES CURRENT_CATALOG;
VALUES CURRENT_SCHEMA;
SET SCHEMA ':memory:.PUBLIC';
SET SCHEMA 'nope.PUBLIC';
SET SCHEMA 'foo.nope';
SET SCHEMA 'foo.s.t';
SET SCHEMA 'foo.';
VALUES CURRENT_CATALOG;
VALUES CURRENT_SCHEMA;
-- msg: CREATE SCHEMA 1
-- msg: SET SCHEMA 1
-- COL1: FOO
-- COL1: S
-- msg: SET SCHEMA 1
-- COL1: :memory:
-- COL1: PUBLIC
-- msg: SET SCHEMA 1
-- error 3D000: invalid catalog name: nope
-- error 3F000: invalid schema name: NOPE
-- error 3F000: invalid schema name: foo.s.t
-- error 3F000: invalid schema name: foo.
-- COL1: :memory:
-- COL1: PUBLIC

-- # A period in a delimited identifier doesn't split it.
CREATE SCHEMA "a.b";
SET SCHEMA '"a.b"';
VALUES CURRENT_SCHEMA;
-- msg: CREATE SCHEMA 1
-- msg: SET SCHEMA 1
-- COL1: a.b

-- # A catalog name is its exact name, otherwise an identifier (19.5, General Rule
-- # 2).
/* create_catalog FOO */
SET CATALOG 'foo';
VALUES CURRENT_CATALOG;
SET CATALOG ':memory:';
SET CATALOG '"FOO"';
VALUES CURRENT_CATALOG;
SET CATALOG '"foo"';
SET CATALOG 'foo bar';
VALUES CURRENT_CATALOG;
-- msg: SET CATALOG 1
-- COL1: FOO
-- msg: SET CATALOG 1
-- msg: SET CATALOG 1
-- COL1: FOO
-- error 3D000: invalid catalog name: "foo"
-- error 3D000: invalid catalog name: foo bar
-- COL1: FOO
