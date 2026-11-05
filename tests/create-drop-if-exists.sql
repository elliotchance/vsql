-- # IF [NOT] EXISTS is a vsql extension of CREATE and DROP (V101-01, V102-01, V103-01, V104-02, V106-01 and V107-02) for tables,
-- # schemas and sequences.

-- # CREATE TABLE IF NOT EXISTS

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

/* virtual_table CREATE TABLE fruits (id INT) AS VALUES 1 */
/* extensions V103-01 */
CREATE TABLE IF NOT EXISTS fruits (x INT);
SELECT * FROM fruits;
-- msg: CREATE TABLE 0
-- ID: 1

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
START TRANSACTION;
CREATE TABLE t (x INT);
/* connection 2 */
/* extensions V103-01 */
CREATE TABLE IF NOT EXISTS t (y INT);
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE TABLE 1
-- 2: msg: CREATE TABLE 1

/* connection 1 */
START TRANSACTION;
CREATE TABLE t (x INT);
/* connection 2 */
CREATE TABLE t (y INT);
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE TABLE 1
-- 2: msg: CREATE TABLE 1

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

CREATE TABLE IF NOT (x INT);
-- error 42601: syntax error: unexpected "(", expecting EXISTS

CREATE TABLE IF EXISTS t (x INT);
-- error 42601: syntax error: unexpected EXISTS, expecting "("

-- # CREATE SCHEMA IF NOT EXISTS

/* extensions V101-01 */
CREATE SCHEMA IF NOT EXISTS foo;
CREATE TABLE foo.t (x INT);
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1

/* extensions V101-01 */
CREATE SCHEMA foo;
CREATE TABLE foo.t (x INT);
CREATE SCHEMA IF NOT EXISTS foo;
INSERT INTO foo.t (x) VALUES (1);
SELECT * FROM foo.t;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: CREATE SCHEMA 0
-- msg: INSERT 1
-- X: 1

/* extensions V101-01 */
CREATE SCHEMA IF NOT EXISTS public;
CREATE SCHEMA IF NOT EXISTS information_schema;
-- msg: CREATE SCHEMA 0
-- msg: CREATE SCHEMA 0

/* extensions V101-01 */
CREATE SCHEMA IF NOT EXISTS nosuch.foo;
-- error 3D000: invalid catalog name: NOSUCH

/* extensions V101-01 */
CREATE SCHEMA IF NOT EXISTS foo;
CREATE SCHEMA foo;
-- msg: CREATE SCHEMA 1
-- error 42P06: duplicate schema: FOO

/* extensions V101-01 */
START TRANSACTION;
CREATE SCHEMA foo;
CREATE SCHEMA IF NOT EXISTS foo;
ROLLBACK;
CREATE SCHEMA IF NOT EXISTS foo;
-- msg: START TRANSACTION
-- msg: CREATE SCHEMA 1
-- msg: CREATE SCHEMA 0
-- msg: ROLLBACK
-- msg: CREATE SCHEMA 1

/* extensions V101-01 */
CREATE SCHEMA foo;
CREATE TABLE foo.t (x INT);
START TRANSACTION;
DROP SCHEMA foo CASCADE;
CREATE SCHEMA IF NOT EXISTS foo;
ROLLBACK;
SELECT * FROM foo.t;
CREATE SCHEMA IF NOT EXISTS foo;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: DROP SCHEMA 1
-- msg: CREATE SCHEMA 1
-- msg: ROLLBACK
-- msg: CREATE SCHEMA 0

/* connection 1 */
CREATE SCHEMA foo;
/* connection 2 */
/* extensions V101-01 */
CREATE SCHEMA IF NOT EXISTS foo;
-- 1: msg: CREATE SCHEMA 1
-- 2: msg: CREATE SCHEMA 0

/* extensions V101-01 */
CREATE SCHEMA if;
CREATE SCHEMA IF NOT EXISTS if;
CREATE TABLE if.if (if INT);
SELECT * FROM if.if;
-- msg: CREATE SCHEMA 1
-- msg: CREATE SCHEMA 0
-- msg: CREATE TABLE 1

-- # CREATE SEQUENCE IF NOT EXISTS

/* extensions V106-01 */
CREATE SEQUENCE IF NOT EXISTS s;
SELECT NEXT VALUE FOR s FROM (VALUES 1) AS t;
-- msg: CREATE SEQUENCE 1
-- COL1: 1

/* extensions V106-01 */
CREATE SEQUENCE IF NOT EXISTS s START WITH 10 INCREMENT BY 5;
SELECT NEXT VALUE FOR s FROM (VALUES 1) AS t;
SELECT NEXT VALUE FOR s FROM (VALUES 1) AS t;
-- msg: CREATE SEQUENCE 1
-- COL1: 10
-- COL1: 15

-- # The current value and options aren't changed or compared.
/* extensions V106-01 */
CREATE SEQUENCE s START WITH 10 INCREMENT BY 5;
SELECT NEXT VALUE FOR s FROM (VALUES 1) AS t;
CREATE SEQUENCE IF NOT EXISTS s;
SELECT NEXT VALUE FOR s FROM (VALUES 1) AS t;
CREATE SEQUENCE IF NOT EXISTS s START WITH 100 INCREMENT BY 2;
SELECT NEXT VALUE FOR s FROM (VALUES 1) AS t;
-- msg: CREATE SEQUENCE 1
-- COL1: 10
-- msg: CREATE SEQUENCE 0
-- COL1: 15
-- msg: CREATE SEQUENCE 0
-- COL1: 20

-- # The options aren't checked when the sequence exists.
/* extensions V106-01 */
CREATE SEQUENCE s;
CREATE SEQUENCE IF NOT EXISTS s START WITH 1 START WITH 2;
-- msg: CREATE SEQUENCE 1
-- msg: CREATE SEQUENCE 0

-- # But they are when it doesn't.
/* extensions V106-01 */
CREATE SEQUENCE IF NOT EXISTS s START WITH 1 START WITH 2;
-- error 42601: syntax error: START WITH is specified more than once

CREATE SEQUENCE s;
CREATE SEQUENCE s START WITH 1 START WITH 2;
-- msg: CREATE SEQUENCE 1
-- error 42P07: duplicate sequence: ":memory:".PUBLIC.S

/* extensions V106-01 */
CREATE SEQUENCE IF NOT EXISTS s;
CREATE SEQUENCE s;
-- msg: CREATE SEQUENCE 1
-- error 42P07: duplicate sequence: ":memory:".PUBLIC.S

/* extensions V106-01 */
CREATE SEQUENCE IF NOT EXISTS nosuch.s;
-- error 3F000: invalid schema name: NOSUCH

/* extensions V106-01 */
CREATE SEQUENCE IF NOT EXISTS information_schema.s;
-- error 42501: insufficient privilege: INFORMATION_SCHEMA is read-only

-- # A sequence in another schema doesn't count, and neither does a table.
/* extensions V106-01 */
CREATE SCHEMA other;
CREATE SEQUENCE other.s START WITH 10;
CREATE TABLE s (x INT);
CREATE SEQUENCE IF NOT EXISTS s;
CREATE SEQUENCE IF NOT EXISTS other.s;
SELECT NEXT VALUE FOR s FROM (VALUES 1) AS t;
SELECT NEXT VALUE FOR other.s FROM (VALUES 1) AS t;
-- msg: CREATE SCHEMA 1
-- msg: CREATE SEQUENCE 1
-- msg: CREATE TABLE 1
-- msg: CREATE SEQUENCE 1
-- msg: CREATE SEQUENCE 0
-- COL1: 1
-- COL1: 10

/* extensions V106-01 */
START TRANSACTION;
CREATE SEQUENCE s START WITH 10;
CREATE SEQUENCE IF NOT EXISTS s;
SELECT NEXT VALUE FOR s FROM (VALUES 1) AS t;
ROLLBACK;
CREATE SEQUENCE IF NOT EXISTS s;
SELECT NEXT VALUE FOR s FROM (VALUES 1) AS t;
-- msg: START TRANSACTION
-- msg: CREATE SEQUENCE 1
-- msg: CREATE SEQUENCE 0
-- COL1: 10
-- msg: ROLLBACK
-- msg: CREATE SEQUENCE 1
-- COL1: 1

/* extensions V107-01 V106-01 */
CREATE SEQUENCE s START WITH 10;
START TRANSACTION;
DROP SEQUENCE s;
CREATE SEQUENCE IF NOT EXISTS s;
SELECT NEXT VALUE FOR s FROM (VALUES 1) AS t;
ROLLBACK;
SELECT NEXT VALUE FOR s FROM (VALUES 1) AS t;
-- msg: CREATE SEQUENCE 1
-- msg: START TRANSACTION
-- msg: DROP SEQUENCE 1
-- msg: CREATE SEQUENCE 1
-- COL1: 1
-- msg: ROLLBACK
-- COL1: 10

/* connection 1 */
CREATE SEQUENCE s START WITH 10;
/* connection 2 */
/* extensions V106-01 */
CREATE SEQUENCE IF NOT EXISTS s;
-- 1: msg: CREATE SEQUENCE 1
-- 2: msg: CREATE SEQUENCE 0

/* extensions V106-01 */
CREATE SEQUENCE if;
CREATE SEQUENCE IF NOT EXISTS if;
CREATE SEQUENCE IF NOT EXISTS public.if START WITH 5;
SELECT NEXT VALUE FOR if FROM (VALUES 1) AS t;
-- msg: CREATE SEQUENCE 1
-- msg: CREATE SEQUENCE 0
-- msg: CREATE SEQUENCE 0
-- COL1: 1

CREATE SEQUENCE if START WITH 5;
SELECT NEXT VALUE FOR if FROM (VALUES 1) AS t;
-- msg: CREATE SEQUENCE 1
-- COL1: 5

-- # DROP TABLE IF EXISTS

/* extensions V104-01 V104-02 */
DROP TABLE IF EXISTS t;
DROP TABLE IF EXISTS t RESTRICT;
DROP TABLE IF EXISTS t CASCADE;
-- msg: DROP TABLE 0
-- msg: DROP TABLE 0
-- msg: DROP TABLE 0

/* extensions V104-01 V104-02 */
CREATE TABLE t (x INT);
DROP TABLE IF EXISTS t;
SELECT * FROM t;
DROP TABLE IF EXISTS t;
-- msg: CREATE TABLE 1
-- msg: DROP TABLE 1
-- error 42P01: no such table: ":memory:".PUBLIC.T
-- msg: DROP TABLE 0

-- # A table in a schema that doesn't exist doesn't exist.
/* extensions V104-01 V104-02 */
DROP TABLE IF EXISTS nosuch.t;
-- msg: DROP TABLE 0

/* extensions V104-01 V104-02 */
DROP TABLE IF EXISTS nosuch.public.t;
-- error 3D000: invalid catalog name: NOSUCH

/* extensions V104-01 V104-02 */
DROP TABLE IF EXISTS information_schema.tables;
-- error 42501: insufficient privilege: INFORMATION_SCHEMA is read-only

/* extensions V104-01 V104-02 */
DROP TABLE IF EXISTS information_schema.nosuch;
-- error 42501: insufficient privilege: INFORMATION_SCHEMA is read-only

-- # A virtual table can't be dropped, it's not a table for DROP TABLE.
/* virtual_table CREATE TABLE fruits (id INT) AS VALUES 1 */
/* extensions V104-01 V104-02 */
DROP TABLE IF EXISTS fruits;
SELECT * FROM fruits;
-- msg: DROP TABLE 0
-- ID: 1

-- # A table in another schema doesn't count.
/* extensions V104-01 V104-02 */
CREATE SCHEMA other;
CREATE TABLE other.t (x INT);
DROP TABLE IF EXISTS t;
SELECT * FROM other.t;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: DROP TABLE 0

/* extensions V104-01 V104-02 */
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (id INT, FOREIGN KEY (id) REFERENCES parent (id));
DROP TABLE IF EXISTS parent;
DROP TABLE IF EXISTS parent RESTRICT;
DROP TABLE IF EXISTS parent CASCADE;
INSERT INTO child (id) VALUES (1);
DROP TABLE IF EXISTS parent CASCADE;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- error 2BP01: dependent objects still exist on ":memory:".PUBLIC.PARENT
-- error 2BP01: dependent objects still exist on ":memory:".PUBLIC.PARENT
-- msg: DROP TABLE 1
-- msg: INSERT 1
-- msg: DROP TABLE 0

/* extensions V104-01 V104-02 */
CREATE TABLE t (x INT);
START TRANSACTION;
DROP TABLE t;
DROP TABLE IF EXISTS t;
ROLLBACK;
INSERT INTO t (x) VALUES (1);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: DROP TABLE 1
-- msg: DROP TABLE 0
-- msg: ROLLBACK
-- msg: INSERT 1
-- X: 1

/* extensions V104-01 V104-02 */
CREATE TABLE t (x INT);
START TRANSACTION;
DROP TABLE IF EXISTS t;
ROLLBACK;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: DROP TABLE 1
-- msg: ROLLBACK

/* extensions V104-01 V104-02 */
START TRANSACTION;
CREATE TABLE t (x INT);
DROP TABLE IF EXISTS t;
DROP TABLE IF EXISTS t;
COMMIT;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: CREATE TABLE 1
-- msg: DROP TABLE 1
-- msg: DROP TABLE 0
-- msg: COMMIT
-- error 42P01: no such table: ":memory:".PUBLIC.T

-- # A table that another connection dropped doesn't exist.
/* connection 1 */
CREATE TABLE t (x INT);
DROP TABLE t;
/* connection 2 */
/* extensions V104-01 V104-02 */
DROP TABLE IF EXISTS t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: DROP TABLE 1
-- 2: msg: DROP TABLE 0

/* extensions V104-01 V104-02 */
CREATE TABLE if (x INT);
DROP TABLE if;
DROP TABLE IF EXISTS if;
CREATE TABLE if (x INT);
DROP TABLE if CASCADE;
CREATE TABLE if (x INT);
DROP TABLE IF EXISTS if CASCADE;
-- msg: CREATE TABLE 1
-- msg: DROP TABLE 1
-- msg: DROP TABLE 0
-- msg: CREATE TABLE 1
-- msg: DROP TABLE 1
-- msg: CREATE TABLE 1
-- msg: DROP TABLE 1

DROP TABLE IF NOT EXISTS t;
-- error 42601: syntax error: unexpected NOT

-- # DROP SCHEMA IF EXISTS

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

-- # DROP SEQUENCE IF EXISTS

/* extensions V107-01 V107-02 */
DROP SEQUENCE IF EXISTS s;
DROP SEQUENCE IF EXISTS s RESTRICT;
DROP SEQUENCE IF EXISTS s CASCADE;
-- msg: DROP SEQUENCE 0
-- msg: DROP SEQUENCE 0
-- msg: DROP SEQUENCE 0

/* extensions V107-01 V107-02 */
CREATE SEQUENCE s;
DROP SEQUENCE IF EXISTS s;
DROP SEQUENCE IF EXISTS s;
CREATE SEQUENCE s;
DROP SEQUENCE IF EXISTS s CASCADE;
DROP SEQUENCE s;
-- msg: CREATE SEQUENCE 1
-- msg: DROP SEQUENCE 1
-- msg: DROP SEQUENCE 0
-- msg: CREATE SEQUENCE 1
-- msg: DROP SEQUENCE 1
-- error 42P01: no such sequence: ":memory:".PUBLIC.S

/* extensions V107-01 V107-02 */
DROP SEQUENCE IF EXISTS nosuch.s;
-- msg: DROP SEQUENCE 0

DROP SEQUENCE nosuch.s RESTRICT;
-- error 3F000: invalid schema name: NOSUCH

/* extensions V107-01 V107-02 */
DROP SEQUENCE IF EXISTS nosuch.public.s;
-- error 3D000: invalid catalog name: NOSUCH

/* extensions V107-01 V107-02 */
DROP SEQUENCE IF EXISTS information_schema.s;
-- error 42501: insufficient privilege: INFORMATION_SCHEMA is read-only

-- # A sequence in another schema doesn't count, and neither does a table.
/* extensions V107-01 V107-02 */
CREATE SCHEMA other;
CREATE SEQUENCE other.s;
CREATE TABLE s (x INT);
DROP SEQUENCE IF EXISTS s;
SELECT * FROM s;
DROP SEQUENCE IF EXISTS other.s;
-- msg: CREATE SCHEMA 1
-- msg: CREATE SEQUENCE 1
-- msg: CREATE TABLE 1
-- msg: DROP SEQUENCE 0
-- msg: DROP SEQUENCE 1

/* extensions V107-01 V107-02 */
CREATE SEQUENCE s;
START TRANSACTION;
DROP SEQUENCE s;
DROP SEQUENCE IF EXISTS s;
ROLLBACK;
DROP SEQUENCE IF EXISTS s;
-- msg: CREATE SEQUENCE 1
-- msg: START TRANSACTION
-- msg: DROP SEQUENCE 1
-- msg: DROP SEQUENCE 0
-- msg: ROLLBACK
-- msg: DROP SEQUENCE 1

/* connection 1 */
CREATE SEQUENCE s;
DROP SEQUENCE s RESTRICT;
/* connection 2 */
/* extensions V107-01 V107-02 */
DROP SEQUENCE IF EXISTS s;
-- 1: msg: CREATE SEQUENCE 1
-- 1: msg: DROP SEQUENCE 1
-- 2: msg: DROP SEQUENCE 0

/* extensions V107-01 V107-02 */
CREATE SEQUENCE if;
DROP SEQUENCE if;
DROP SEQUENCE IF EXISTS if;
CREATE SEQUENCE if;
DROP SEQUENCE if RESTRICT;
-- msg: CREATE SEQUENCE 1
-- msg: DROP SEQUENCE 1
-- msg: DROP SEQUENCE 0
-- msg: CREATE SEQUENCE 1
-- msg: DROP SEQUENCE 1

-- # None of it is kept: the definitions and dumps are the same.

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

/* flags */
CREATE SCHEMA foo;
-- flags: F171
-- msg: CREATE SCHEMA 1

/* flags */
/* extensions V101-01 */
CREATE SCHEMA IF NOT EXISTS foo;
-- flags: F171, V101-01
-- msg: CREATE SCHEMA 1

/* flags */
CREATE SEQUENCE s;
-- flags: T176
-- msg: CREATE SEQUENCE 1

/* flags */
/* extensions V106-01 */
CREATE SEQUENCE IF NOT EXISTS s;
-- flags: T176, V106-01
-- msg: CREATE SEQUENCE 1

/* flags */
/* extensions V106-01 */
CREATE SEQUENCE IF NOT EXISTS s START WITH 2;
-- flags: T176, V106-01
-- msg: CREATE SEQUENCE 1

/* flags */
DROP TABLE t RESTRICT;
-- flags:
-- error 42P01: no such table: ":memory:".PUBLIC.T

/* flags */
/* extensions V104-01 V104-02 */
DROP TABLE IF EXISTS t;
-- flags: V104-01, V104-02
-- msg: DROP TABLE 0

/* flags */
/* extensions V104-02 */
DROP TABLE IF EXISTS t RESTRICT;
-- flags: V104-02
-- msg: DROP TABLE 0

/* flags */
/* extensions V104-02 */
DROP TABLE IF EXISTS t CASCADE;
-- flags: F032, V104-02
-- msg: DROP TABLE 0

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

/* flags */
DROP SEQUENCE s RESTRICT;
-- flags: T176
-- error 42P01: no such sequence: ":memory:".PUBLIC.S

/* flags */
/* extensions V107-01 V107-02 */
DROP SEQUENCE IF EXISTS s;
-- flags: T176, V107-01, V107-02
-- msg: DROP SEQUENCE 0

/* flags */
/* extensions V107-02 */
DROP SEQUENCE IF EXISTS s CASCADE;
-- flags: T176, V107-02
-- msg: DROP SEQUENCE 0

-- # CREATE SCHEMA IF NOT EXISTS with schema elements
/* extensions V107-01 V101-01 */
CREATE SCHEMA IF NOT EXISTS foo CREATE TABLE t (x INT) CREATE SEQUENCE s;
CREATE TABLE foo.t2 (x INT);
CREATE SCHEMA IF NOT EXISTS foo CREATE TABLE t3 (x INT);
DROP SEQUENCE foo.s;
SELECT * FROM foo.t;
SELECT * FROM foo.t3;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: CREATE SCHEMA 0
-- msg: DROP SEQUENCE 1
-- error 42P01: no such table: ":memory:".FOO.T3

-- # IF NOT EXISTS on a schema element
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
