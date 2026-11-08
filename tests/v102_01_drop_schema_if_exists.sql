-- # DROP SCHEMA IF EXISTS is a vsql extension (V102-01).

/* extensions V102-01 */
DROP SCHEMA IF EXISTS foo RESTRICT;
DROP SCHEMA IF EXISTS foo CASCADE;
-- msg: DROP SCHEMA 0
-- msg: DROP SCHEMA 0

/* extensions V102-01 */
CREATE SCHEMA foo;
DROP SCHEMA IF EXISTS foo RESTRICT;
DROP SCHEMA IF EXISTS foo RESTRICT;
-- msg: CREATE SCHEMA 1
-- msg: DROP SCHEMA 1
-- msg: DROP SCHEMA 0

/* extensions V102-01 */
CREATE SCHEMA foo;
CREATE TABLE foo.t (x INT);
DROP SCHEMA IF EXISTS foo RESTRICT;
SELECT * FROM foo.t;
DROP SCHEMA IF EXISTS foo CASCADE;
SELECT * FROM foo.t;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- error 2BP01: dependent objects still exist on FOO
-- msg: DROP SCHEMA 1
-- error 3F000: invalid schema name: FOO

-- # One of CASCADE or RESTRICT is still required.
DROP SCHEMA IF EXISTS foo;
-- error 42601: syntax error: unexpected $end, expecting CASCADE or RESTRICT

/* extensions V102-01 */
DROP SCHEMA IF EXISTS nosuch.foo RESTRICT;
-- error 3D000: invalid catalog name: NOSUCH

/* extensions V102-01 */
DROP SCHEMA IF EXISTS information_schema CASCADE;
-- error 42501: insufficient privilege: INFORMATION_SCHEMA is read-only

/* extensions V102-01 */
CREATE SCHEMA foo;
START TRANSACTION;
DROP SCHEMA foo RESTRICT;
DROP SCHEMA IF EXISTS foo RESTRICT;
ROLLBACK;
DROP SCHEMA IF EXISTS foo RESTRICT;
-- msg: CREATE SCHEMA 1
-- msg: START TRANSACTION
-- msg: DROP SCHEMA 1
-- msg: DROP SCHEMA 0
-- msg: ROLLBACK
-- msg: DROP SCHEMA 1

/* connection 1 */
CREATE SCHEMA foo;
DROP SCHEMA foo RESTRICT;
/* connection 2 */
/* extensions V102-01 */
DROP SCHEMA IF EXISTS foo RESTRICT;
-- 1: msg: CREATE SCHEMA 1
-- 1: msg: DROP SCHEMA 1
-- 2: msg: DROP SCHEMA 0

/* extensions V102-01 */
CREATE SCHEMA if;
DROP SCHEMA if RESTRICT;
DROP SCHEMA IF EXISTS if RESTRICT;
-- msg: CREATE SCHEMA 1
-- msg: DROP SCHEMA 1
-- msg: DROP SCHEMA 0

-- # Flagging: only the form that's used, and not the standard forms.

/* flags */
DROP SCHEMA foo RESTRICT;
-- flags: F381
-- error 3F000: invalid schema name: FOO

/* flags */
/* extensions V102-01 */
DROP SCHEMA IF EXISTS foo RESTRICT;
-- flags: F381, V102-01
-- msg: DROP SCHEMA 0

/* flags */
/* extensions V102-01 */
DROP SCHEMA IF EXISTS foo CASCADE;
-- flags: F032, F381, V102-01
-- msg: DROP SCHEMA 0
