-- # SET DEFAULT is used by the rows that are inserted after it. The existing
-- # rows keep their values.
CREATE TABLE t (a INT, b INT);
INSERT INTO t (a) VALUES (1);
ALTER TABLE t ALTER COLUMN b SET DEFAULT 2;
INSERT INTO t (a) VALUES (3);
INSERT INTO t (a, b) VALUES (4, DEFAULT);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: ALTER TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- A: 1 B: NULL
-- A: 3 B: 2
-- A: 4 B: 2

-- # COLUMN is optional, and SET DEFAULT replaces the existing default.
CREATE TABLE t (a INT, b VARCHAR(10) DEFAULT 'x');
ALTER TABLE t ALTER b SET DEFAULT 'y';
INSERT INTO t (a) VALUES (1);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: ALTER TABLE 1
-- msg: INSERT 1
-- A: 1 B: y

-- # DROP DEFAULT makes the default NULL.
CREATE TABLE t (a INT, b INT DEFAULT 2);
ALTER TABLE t ALTER COLUMN b DROP DEFAULT;
INSERT INTO t (a) VALUES (1);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: ALTER TABLE 1
-- msg: INSERT 1
-- A: 1 B: NULL

-- # DROP DEFAULT needs a default, which can be NULL.
CREATE TABLE t (a INT, b INT DEFAULT NULL);
ALTER TABLE t ALTER COLUMN a DROP DEFAULT;
ALTER TABLE t ALTER COLUMN b DROP DEFAULT;
ALTER TABLE t ALTER COLUMN b DROP DEFAULT;
-- msg: CREATE TABLE 1
-- error 42601: syntax error: column A has no DEFAULT
-- msg: ALTER TABLE 1
-- error 42601: syntax error: column B has no DEFAULT

-- # A NOT NULL column without a default must be given a value.
CREATE TABLE t (a INT, b INT DEFAULT 2 NOT NULL);
ALTER TABLE t ALTER COLUMN b DROP DEFAULT;
INSERT INTO t (a) VALUES (1);
ALTER TABLE t ALTER COLUMN b SET DEFAULT NULL;
INSERT INTO t (a) VALUES (1);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: ALTER TABLE 1
-- error 23502: violates non-null constraint: column B
-- msg: ALTER TABLE 1
-- error 23502: violates non-null constraint: column B

-- # The default is checked like the default of a column of a CREATE TABLE.
CREATE TABLE t (a INT, b VARCHAR(2), c DATE, d SMALLINT);
ALTER TABLE t ALTER COLUMN a SET DEFAULT 'x';
ALTER TABLE t ALTER COLUMN a SET DEFAULT 1.5;
ALTER TABLE t ALTER COLUMN b SET DEFAULT 'abc';
ALTER TABLE t ALTER COLUMN c SET DEFAULT CURRENT_TIME;
ALTER TABLE t ALTER COLUMN d SET DEFAULT 100000;
ALTER TABLE t ALTER COLUMN b SET DEFAULT CURRENT_SCHEMA;
-- msg: CREATE TABLE 1
-- error 42601: syntax error: DEFAULT 'x' is not valid for column A INTEGER
-- error 42601: syntax error: DEFAULT 1.5 is not valid for column A INTEGER
-- error 42601: syntax error: DEFAULT 'abc' is not valid for column B CHARACTER VARYING(2)
-- error 42601: syntax error: DEFAULT CURRENT_TIME(0) is not valid for column C DATE
-- error 42601: syntax error: DEFAULT 100000 is not valid for column D SMALLINT
-- msg: ALTER TABLE 1

-- # A datetime default is evaluated when it's used.
CREATE TABLE t (a INT, b DATE);
ALTER TABLE t ALTER COLUMN b SET DEFAULT CURRENT_DATE;
INSERT INTO t (a) VALUES (1);
SELECT a FROM t WHERE b = CURRENT_DATE;
-- msg: CREATE TABLE 1
-- msg: ALTER TABLE 1
-- msg: INSERT 1
-- A: 1

-- # The column and table must exist.
CREATE TABLE t (a INT);
ALTER TABLE t ALTER COLUMN b SET DEFAULT 1;
ALTER TABLE t ALTER COLUMN "a" SET DEFAULT 1;
ALTER TABLE foo ALTER COLUMN a SET DEFAULT 1;
ALTER TABLE information_schema.tables ALTER COLUMN table_name DROP DEFAULT;
-- msg: CREATE TABLE 1
-- error 42703: no such column: B
-- error 42703: no such column: a
-- error 42P01: no such table: ":memory:".PUBLIC.FOO
-- error 42501: insufficient privilege: INFORMATION_SCHEMA is read-only

-- # The constraints of the table are kept.
CREATE TABLE t (a INT PRIMARY KEY, b INT UNIQUE CHECK (b > 0));
ALTER TABLE t ALTER COLUMN b SET DEFAULT 0;
INSERT INTO t (a) VALUES (1);
ALTER TABLE t ALTER COLUMN b SET DEFAULT 1;
INSERT INTO t (a) VALUES (1);
INSERT INTO t (a, b) VALUES (1, 2);
INSERT INTO t (a) VALUES (2);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: ALTER TABLE 1
-- error 23514: violates check constraint: CHECK (B > 0) on ":memory:".PUBLIC.T
-- msg: ALTER TABLE 1
-- msg: INSERT 1
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T
-- error 23505: violates unique constraint: UNIQUE (B) on ":memory:".PUBLIC.T
-- A: 1 B: 1

-- # A ROLLBACK restores the default.
CREATE TABLE t (a INT, b INT DEFAULT 2);
START TRANSACTION;
ALTER TABLE t ALTER COLUMN b SET DEFAULT 3;
INSERT INTO t (a) VALUES (1);
ROLLBACK;
INSERT INTO t (a) VALUES (2);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: ALTER TABLE 1
-- msg: INSERT 1
-- msg: ROLLBACK
-- msg: INSERT 1
-- A: 2 B: 2

-- # The default is in the INFORMATION_SCHEMA.
CREATE TABLE t (a INT DEFAULT 1, b INT);
ALTER TABLE t ALTER COLUMN a DROP DEFAULT;
ALTER TABLE t ALTER COLUMN b SET DEFAULT -3;
SELECT column_name, column_default FROM information_schema.columns WHERE table_name = 'T';
-- msg: CREATE TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- COLUMN_NAME: A COLUMN_DEFAULT: NULL
-- COLUMN_NAME: B COLUMN_DEFAULT: -3

-- # The new default is read back from the file.
/* connection 1 */
CREATE TABLE t (a INT, b VARCHAR(10) DEFAULT 'x');
ALTER TABLE t ALTER COLUMN b SET DEFAULT 'it''s';
/* connection 2 */
INSERT INTO t (a) VALUES (1);
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: ALTER TABLE 1
-- 2: msg: INSERT 1
-- 2: A: 1 B: it's

-- # A dump has the new defaults, and the existing rows keep their values.
CREATE TABLE t (a INT DEFAULT 1 NOT NULL, b VARCHAR(10), c DATE DEFAULT CURRENT_DATE);
INSERT INTO t (b) VALUES ('x');
ALTER TABLE t ALTER COLUMN a SET DEFAULT 2;
ALTER TABLE t ALTER COLUMN b SET DEFAULT 'it''s';
ALTER TABLE t ALTER COLUMN c DROP DEFAULT;
UPDATE t SET c = DATE '2020-01-02';
/* out */
/* in */
INSERT INTO t (c) VALUES (NULL);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: UPDATE 1
-- out: CREATE TABLE "PUBLIC"."T" (
-- out:   "A" INTEGER DEFAULT 2 NOT NULL,
-- out:   "B" CHARACTER VARYING(10) DEFAULT 'it''s',
-- out:   "C" DATE
-- out: );
-- out: INSERT INTO "PUBLIC"."T" ("A", "B", "C") VALUES (1, 'x', DATE '2020-01-02');
-- msg: INSERT 1
-- A: 1 B: x C: 2020-01-02
-- A: 2 B: it's C: NULL
