-- # CREATE TABLE IF NOT EXISTS is a vsql extension (V103-01).

-- # A table that doesn't exist is created as usual (CREATE TABLE 1).
/* extensions V103-01 */
CREATE TABLE IF NOT EXISTS t (x INT);
INSERT INTO t (x) VALUES (1);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- X: 1

-- # The existing table isn't changed, or compared with the new definition.
/* extensions V103-01 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
CREATE TABLE IF NOT EXISTS t (y VARCHAR(10), z INT);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: CREATE TABLE 0
-- X: 1

-- # The new definition isn't checked when the table exists.
/* extensions V103-01 */
CREATE TABLE t (x INT);
CREATE TABLE IF NOT EXISTS t (y INT, y INT);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 0

-- # But it is when the table doesn't exist.
/* extensions V103-01 */
CREATE TABLE IF NOT EXISTS t (y INT, y INT);
-- error 42601: syntax error: column Y is defined more than once

-- # Only the table is optional: a later CREATE TABLE without IF NOT EXISTS
-- # still fails, and so does a schema or catalog that doesn't exist, or the
-- # read-only INFORMATION_SCHEMA (even though its TABLES exists).
/* extensions V103-01 */
CREATE TABLE IF NOT EXISTS t (x INT);
CREATE TABLE t (x INT);
-- msg: CREATE TABLE 1
-- error 42P07: duplicate table: ":memory:".PUBLIC.T

/* extensions V103-01 */
CREATE TABLE IF NOT EXISTS nosuch.t (x INT);
-- error 3F000: invalid schema name: NOSUCH

/* extensions V103-01 */
CREATE TABLE IF NOT EXISTS nosuch.public.t (x INT);
-- error 3D000: invalid catalog name: NOSUCH

/* extensions V103-01 */
CREATE TABLE IF NOT EXISTS information_schema.tables (x INT);
-- error 42501: insufficient privilege: INFORMATION_SCHEMA is read-only

-- # A table in another schema doesn't count.
/* extensions V103-01 */
CREATE SCHEMA other;
CREATE TABLE other.t (x INT);
CREATE TABLE IF NOT EXISTS t (y INT);
CREATE TABLE IF NOT EXISTS other.t (z INT);
SELECT * FROM t;
INSERT INTO other.t (x) VALUES (1);
SELECT * FROM other.t;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 0
-- msg: INSERT 1
-- X: 1

-- # A virtual table is an existing table, so it's left alone.
/* virtual_table CREATE TABLE fruits (id INT) AS VALUES 1 */
/* extensions V103-01 */
CREATE TABLE IF NOT EXISTS fruits (x INT);
SELECT * FROM fruits;
-- msg: CREATE TABLE 0
-- ID: 1

-- # Whether it exists is what this transaction can see: a table created or
-- # dropped earlier in the transaction counts, and ROLLBACK undoes a table that
-- # IF NOT EXISTS created.
/* extensions V103-01 */
START TRANSACTION;
CREATE TABLE t (x INT);
CREATE TABLE IF NOT EXISTS t (y INT);
INSERT INTO t (x) VALUES (1);
SELECT * FROM t;
COMMIT;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 0
-- msg: INSERT 1
-- X: 1
-- msg: COMMIT
-- X: 1

/* extensions V104-01 V103-01 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
START TRANSACTION;
DROP TABLE t;
CREATE TABLE IF NOT EXISTS t (y INT);
INSERT INTO t (y) VALUES (2);
SELECT * FROM t;
ROLLBACK;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: DROP TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- Y: 2
-- msg: ROLLBACK
-- X: 1

/* extensions V103-01 */
START TRANSACTION;
CREATE TABLE IF NOT EXISTS t (x INT);
ROLLBACK;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: CREATE TABLE 1
-- msg: ROLLBACK
-- error 42P01: no such table: ":memory:".PUBLIC.T

-- # Nothing that it did can be rolled back when the table exists.
/* extensions V103-01 */
CREATE TABLE t (x INT);
START TRANSACTION;
CREATE TABLE IF NOT EXISTS t (y INT);
ROLLBACK;
INSERT INTO t (x) VALUES (1);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: CREATE TABLE 0
-- msg: ROLLBACK
-- msg: INSERT 1
-- X: 1

-- # A table that another connection has committed exists.
/* connection 1 */
CREATE TABLE t (x INT);
/* connection 2 */
/* extensions V103-01 */
CREATE TABLE IF NOT EXISTS t (y INT);
INSERT INTO t (x) VALUES (1);
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 2: msg: CREATE TABLE 0
-- 2: msg: INSERT 1
-- 2: X: 1

-- # A table that another connection hasn't committed isn't visible, so it's the
-- # same as CREATE TABLE. The next test is the same without IF NOT EXISTS.
/* connection 1 */
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
CREATE TABLE t (x INT);
/* connection 2 */
/* extensions V103-01 */
CREATE TABLE IF NOT EXISTS t (y INT);
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE TABLE 1
-- 2: msg: CREATE TABLE 1

-- # The same test with the default isolation level (SERIALIZABLE).
/* connection 1 */
START TRANSACTION;
CREATE TABLE t (x INT);
/* connection 2 */
/* extensions V103-01 */
CREATE TABLE IF NOT EXISTS t (y INT);
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE TABLE 1
-- 2: error 40001: serialization failure: another connection has a transaction that must finish first

/* connection 1 */
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
CREATE TABLE t (x INT);
/* connection 2 */
CREATE TABLE t (y INT);
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE TABLE 1
-- 2: msg: CREATE TABLE 1

-- # The same test with the default isolation level (SERIALIZABLE).
/* connection 1 */
START TRANSACTION;
CREATE TABLE t (x INT);
/* connection 2 */
CREATE TABLE t (y INT);
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE TABLE 1
-- 2: error 40001: serialization failure: another connection has a transaction that must finish first

-- # IF is still a name.
/* extensions V103-01 */
CREATE TABLE if (if INT);
CREATE TABLE IF NOT EXISTS if (x INT);
INSERT INTO if (if) VALUES (1);
SELECT if FROM if;
SELECT if.if FROM if;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 0
-- msg: INSERT 1
-- IF: 1
-- IF: 1

/* extensions V103-01 */
CREATE TABLE IF NOT EXISTS if (if INT);
INSERT INTO if (if) VALUES (1);
SELECT * FROM if;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- IF: 1

-- # EXISTS must follow IF NOT. IF EXISTS is only for DROP: here IF is read as
-- # the table name, so EXISTS is unexpected.
CREATE TABLE IF NOT (x INT);
-- error 42601: syntax error: unexpected "(" at line 1, column 21 near "TABLE IF NOT (x", expecting EXISTS

CREATE TABLE IF EXISTS t (x INT);
-- error 42601: syntax error: unexpected EXISTS at line 1, column 17 near "CREATE TABLE IF EXISTS t", expecting "("

-- # IF NOT EXISTS isn't kept: "vsql out" writes plain CREATE statements, and
-- # the dump is the same after they're read back in.

/* extensions V103-01 V101-01 V106-01 */
CREATE SCHEMA IF NOT EXISTS foo;
CREATE TABLE IF NOT EXISTS foo.t (x INT);
CREATE SEQUENCE IF NOT EXISTS foo.s;
/* out */
/* in */
SELECT table_schema, table_name FROM information_schema.tables WHERE table_schema = 'FOO';
CREATE TABLE IF NOT EXISTS foo.t (y INT);
/* out */
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: CREATE SEQUENCE 1
-- out: CREATE SCHEMA "FOO";
-- out: CREATE SEQUENCE "FOO"."S" START WITH 1;
-- out: CREATE TABLE "FOO"."T" (
-- out:   "X" INTEGER
-- out: );
-- TABLE_SCHEMA: FOO TABLE_NAME: T
-- msg: CREATE TABLE 0
-- out: CREATE SCHEMA "FOO";
-- out: CREATE SEQUENCE "FOO"."S" START WITH 1;
-- out: CREATE TABLE "FOO"."T" (
-- out:   "X" INTEGER
-- out: );

-- # Flagging: only the form that's used, and not the standard forms.

/* flags */
CREATE TABLE t (x INT);
-- flags:
-- msg: CREATE TABLE 1

/* flags */
/* extensions V103-01 */
CREATE TABLE IF NOT EXISTS t (x INT);
-- flags: V103-01
-- msg: CREATE TABLE 1

/* flags */
CREATE TABLE if (x INT);
-- flags:
-- msg: CREATE TABLE 1

-- # IF NOT EXISTS also works on a table or sequence in CREATE SCHEMA: the
-- # second one with the same name is skipped, so the first one is kept.
/* extensions V103-01 V106-01 */
CREATE SCHEMA foo
  CREATE TABLE IF NOT EXISTS t (x INT)
  CREATE TABLE IF NOT EXISTS t (y INT)
  CREATE SEQUENCE IF NOT EXISTS s
  CREATE SEQUENCE IF NOT EXISTS s;
INSERT INTO foo.t (x) VALUES (1);
SELECT * FROM foo.t;
-- msg: CREATE SCHEMA 1
-- msg: INSERT 1
-- X: 1
