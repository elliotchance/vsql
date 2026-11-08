-- # CREATE SCHEMA IF NOT EXISTS is a vsql extension (V101-01).

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
CREATE SCHEMA foo;
-- flags: F171
-- msg: CREATE SCHEMA 1

/* flags */
/* extensions V101-01 */
CREATE SCHEMA IF NOT EXISTS foo;
-- flags: F171, V101-01
-- msg: CREATE SCHEMA 1

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
