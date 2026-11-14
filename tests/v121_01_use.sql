-- # USE is a vsql extension (V121-01) for SET SCHEMA, with the name of the
-- # schema rather than a character string.

/* setup */
CREATE SCHEMA foo;
CREATE SCHEMA "bar";

-- # A regular identifier is upper case, so USE foo is SET SCHEMA 'foo'.
/* extensions V121-01 */
USE foo;
VALUES CURRENT_SCHEMA;
use public;
VALUES CURRENT_SCHEMA;
-- msg: SET SCHEMA 1
-- COL1: FOO
-- msg: SET SCHEMA 1
-- COL1: PUBLIC

-- # A lower case name is delimited.
/* extensions V121-01 */
USE bar;
USE "bar";
VALUES CURRENT_SCHEMA;
-- error 3F000: invalid schema name: BAR
-- msg: SET SCHEMA 1
-- COL1: bar

-- # The name can have a catalog, which sets the catalog as well.
/* extensions V121-01 */
/* create_catalog OTHER */
USE other.public;
VALUES CURRENT_CATALOG, CURRENT_SCHEMA;
USE "OTHER".foo;
USE ":memory:".foo;
VALUES CURRENT_CATALOG, CURRENT_SCHEMA;
USE nope.public;
-- msg: SET SCHEMA 1
-- COL1: OTHER
-- COL1: PUBLIC
-- error 3F000: invalid schema name: FOO
-- msg: SET SCHEMA 1
-- COL1: :memory:
-- COL1: FOO
-- error 3D000: invalid catalog name: nope

-- # A name must be an identifier, not a string or more than two parts.
USE 'foo';
USE a.b.c;
USE;
-- error 42601: syntax error: unexpected string at line 1, column 5 near "USE 'foo'"
-- error 42601: syntax error: unexpected "." at line 1, column 8 near "a.b.c"
-- error 42601: syntax error: unexpected $end at line 1, column 4 near "USE"

-- # USE isn't a reserved word, so it can be a name.
CREATE TABLE use (use INTEGER);
INSERT INTO use (use) VALUES (1);
SELECT use FROM use;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- USE: 1

-- # The flagger: what the standard form needs, and which alias was used.
/* flags */
/* extensions V121-01 */
USE foo;
-- flags: F761, V121-01
-- msg: SET SCHEMA 1
