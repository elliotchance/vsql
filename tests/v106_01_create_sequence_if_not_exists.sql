-- # CREATE SEQUENCE IF NOT EXISTS is a vsql extension (V106-01).

-- # A sequence that doesn't exist is created as usual, with its options.
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

-- # Without IF NOT EXISTS, it's the existing sequence that's the error.
CREATE SEQUENCE s;
CREATE SEQUENCE s START WITH 1 START WITH 2;
-- msg: CREATE SEQUENCE 1
-- error 42P07: duplicate sequence: ":memory:".PUBLIC.S

-- # Only the sequence is optional: a later CREATE SEQUENCE still fails, and so
-- # does a schema that doesn't exist or the read-only INFORMATION_SCHEMA.
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

-- # Whether it exists is what this transaction can see: a sequence created or
-- # dropped earlier in the transaction counts, until ROLLBACK undoes it. One
-- # that another connection has committed exists too.
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

-- # IF isn't a reserved word, so it can still be a sequence name. START WITH 5
-- # is ignored because IF already exists; the next test is the same without IF
-- # NOT EXISTS.
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
