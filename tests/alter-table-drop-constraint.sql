-- # A CHECK, UNIQUE or FOREIGN KEY that's dropped is no longer checked, and the
-- # other constraints keep their names.
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE t (a INT CHECK (a > 0) CHECK (a < 10), b INT UNIQUE REFERENCES parent, c INT UNIQUE);
ALTER TABLE t DROP CONSTRAINT t_check_1;
ALTER TABLE t DROP CONSTRAINT t_unique_1;
ALTER TABLE t DROP CONSTRAINT t_foreign_key_1 RESTRICT;
INSERT INTO t (a, b, c) VALUES (-1, 1, 1), (-2, 1, 2);
INSERT INTO t (a) VALUES (10);
INSERT INTO t (c) VALUES (1);
SELECT constraint_name, constraint_type FROM information_schema.table_constraints WHERE table_name = 'T';
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: INSERT 2
-- error 23514: violates check constraint: CHECK (A < 10) on ":memory:".PUBLIC.T
-- error 23505: violates unique constraint: UNIQUE (C) on ":memory:".PUBLIC.T
-- CONSTRAINT_NAME: T_UNIQUE_2 CONSTRAINT_TYPE: UNIQUE
-- CONSTRAINT_NAME: T_CHECK_2 CONSTRAINT_TYPE: CHECK

-- # A NOT NULL can be dropped, unless the column is in the PRIMARY KEY. The
-- # existing rows are still read.
CREATE TABLE t (a INT PRIMARY KEY, b INT CONSTRAINT b_not_null NOT NULL, c VARCHAR(10));
INSERT INTO t (a, b, c) VALUES (2, 3, 'x');
ALTER TABLE t DROP CONSTRAINT b_not_null;
ALTER TABLE t DROP CONSTRAINT t_not_null_1;
INSERT INTO t (a, b) VALUES (1, NULL);
SELECT * FROM t;
SELECT column_name, is_nullable FROM information_schema.columns WHERE table_name = 'T';
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: ALTER TABLE 1
-- error 42601: syntax error: column A is in the PRIMARY KEY, so its NOT NULL cannot be dropped
-- msg: INSERT 1
-- A: 1 B: NULL C: NULL
-- A: 2 B: 3 C: x
-- COLUMN_NAME: A IS_NULLABLE: NO
-- COLUMN_NAME: B IS_NULLABLE: YES
-- COLUMN_NAME: C IS_NULLABLE: YES

-- # The rows of a table without a PRIMARY KEY keep their order.
CREATE TABLE t (a INT NOT NULL, b INT);
INSERT INTO t (a, b) VALUES (2, 1), (1, 2);
ALTER TABLE t DROP CONSTRAINT t_not_null_1;
INSERT INTO t (a, b) VALUES (NULL, 3);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: ALTER TABLE 1
-- msg: INSERT 1
-- A: 2 B: 1
-- A: 1 B: 2
-- A: NULL B: 3

-- # The rows of a table are stored by its PRIMARY KEY, so they're moved when
-- # it's dropped. The columns stay NOT NULL.
CREATE TABLE t (a INT PRIMARY KEY, b VARCHAR(10));
INSERT INTO t (a, b) VALUES (2, 'b'), (1, 'a');
ALTER TABLE t DROP CONSTRAINT t_primary_key;
INSERT INTO t (a, b) VALUES (1, 'c'), (3, 'd');
INSERT INTO t (a, b) VALUES (NULL, 'e');
UPDATE t SET b = 'x' WHERE a = 1;
DELETE FROM t WHERE b = 'd';
SELECT * FROM t;
SELECT constraint_name, constraint_type FROM information_schema.table_constraints;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: ALTER TABLE 1
-- msg: INSERT 2
-- error 23502: violates non-null constraint: column A
-- msg: UPDATE 2
-- msg: DELETE 1
-- A: 1 B: x
-- A: 2 B: b
-- A: 1 B: x
-- CONSTRAINT_NAME: T_NOT_NULL_1 CONSTRAINT_TYPE: CHECK

-- # A PRIMARY KEY or UNIQUE that's referenced by a FOREIGN KEY can only be
-- # dropped with CASCADE, which also drops the FOREIGN KEY (of any table,
-- # including itself).
CREATE TABLE parent (id INT PRIMARY KEY, code INT UNIQUE, parent_id INT REFERENCES parent, parent_code INT REFERENCES parent (code));
CREATE TABLE child (parent_id INT REFERENCES parent, parent_code INT REFERENCES parent (code));
ALTER TABLE parent DROP CONSTRAINT parent_primary_key;
ALTER TABLE parent DROP CONSTRAINT parent_primary_key RESTRICT;
ALTER TABLE parent DROP CONSTRAINT parent_unique_1 RESTRICT;
ALTER TABLE parent DROP CONSTRAINT parent_primary_key CASCADE;
SELECT constraint_name, table_name, constraint_type FROM information_schema.table_constraints;
ALTER TABLE child DROP CONSTRAINT child_foreign_key_2;
ALTER TABLE parent DROP CONSTRAINT parent_unique_1;
ALTER TABLE parent DROP CONSTRAINT parent_foreign_key_2;
ALTER TABLE parent DROP CONSTRAINT parent_unique_1;
INSERT INTO child (parent_id, parent_code) VALUES (1, 1);
SELECT constraint_name, table_name, constraint_type FROM information_schema.table_constraints;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- error 2BP01: dependent objects still exist on constraint PARENT_PRIMARY_KEY on ":memory:".PUBLIC.PARENT
-- error 2BP01: dependent objects still exist on constraint PARENT_PRIMARY_KEY on ":memory:".PUBLIC.PARENT
-- error 2BP01: dependent objects still exist on constraint PARENT_UNIQUE_1 on ":memory:".PUBLIC.PARENT
-- msg: ALTER TABLE 1
-- CONSTRAINT_NAME: CHILD_FOREIGN_KEY_2 TABLE_NAME: CHILD CONSTRAINT_TYPE: FOREIGN KEY
-- CONSTRAINT_NAME: PARENT_UNIQUE_1 TABLE_NAME: PARENT CONSTRAINT_TYPE: UNIQUE
-- CONSTRAINT_NAME: PARENT_FOREIGN_KEY_2 TABLE_NAME: PARENT CONSTRAINT_TYPE: FOREIGN KEY
-- CONSTRAINT_NAME: PARENT_NOT_NULL_1 TABLE_NAME: PARENT CONSTRAINT_TYPE: CHECK
-- msg: ALTER TABLE 1
-- error 2BP01: dependent objects still exist on constraint PARENT_UNIQUE_1 on ":memory:".PUBLIC.PARENT
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: INSERT 1
-- CONSTRAINT_NAME: PARENT_NOT_NULL_1 TABLE_NAME: PARENT CONSTRAINT_TYPE: CHECK

-- # The constraint must be a constraint of the table, and can be qualified by
-- # its schema.
CREATE SCHEMA s;
CREATE TABLE s.t (a INT CONSTRAINT c1 CHECK (a > 0));
CREATE TABLE s.u (a INT CONSTRAINT c2 CHECK (a > 0));
CREATE TABLE public.t (a INT CONSTRAINT c3 CHECK (a > 0));
ALTER TABLE s.t DROP CONSTRAINT missing;
ALTER TABLE s.t DROP CONSTRAINT c2;
ALTER TABLE s.t DROP CONSTRAINT public.c1;
ALTER TABLE s.t DROP CONSTRAINT other.s.c1;
ALTER TABLE public.t DROP CONSTRAINT c1;
ALTER TABLE s.t DROP CONSTRAINT s.c1;
ALTER TABLE information_schema.tables DROP CONSTRAINT c1;
SELECT constraint_schema, constraint_name FROM information_schema.table_constraints;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- error 42704: no such constraint: MISSING on ":memory:".S.T
-- error 42704: no such constraint: C2 on ":memory:".S.T
-- error 42704: no such constraint: PUBLIC.C1 on ":memory:".S.T
-- error 42704: no such constraint: OTHER.S.C1 on ":memory:".S.T
-- error 42704: no such constraint: C1 on ":memory:".PUBLIC.T
-- msg: ALTER TABLE 1
-- error 42501: insufficient privilege: INFORMATION_SCHEMA is read-only
-- CONSTRAINT_SCHEMA: PUBLIC CONSTRAINT_NAME: C3
-- CONSTRAINT_SCHEMA: S CONSTRAINT_NAME: C2

-- # A constraint that's added after another has been dropped can get the name
-- # of the dropped constraint, because it's the first name that isn't used.
CREATE TABLE t (a INT CHECK (a > 0) CHECK (a > 1));
ALTER TABLE t DROP CONSTRAINT t_check_1;
ALTER TABLE t ADD CHECK (a > 2);
ALTER TABLE t ADD CHECK (a > 3);
ALTER TABLE t DROP CONSTRAINT t_check_2;
ALTER TABLE t ADD CONSTRAINT t_check_2 CHECK (a > 4);
SELECT constraint_name, check_clause FROM information_schema.check_constraints;
-- msg: CREATE TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- CONSTRAINT_NAME: T_CHECK_1 CHECK_CLAUSE: A > 2
-- CONSTRAINT_NAME: T_CHECK_3 CHECK_CLAUSE: A > 3
-- CONSTRAINT_NAME: T_CHECK_2 CHECK_CLAUSE: A > 4

-- # A ROLLBACK puts the constraint back.
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (parent_id INT REFERENCES parent);
INSERT INTO parent (id) VALUES (1);
START TRANSACTION;
ALTER TABLE parent DROP CONSTRAINT parent_primary_key CASCADE;
INSERT INTO parent (id) VALUES (1);
ROLLBACK;
INSERT INTO parent (id) VALUES (1);
INSERT INTO child (parent_id) VALUES (2);
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: ALTER TABLE 1
-- msg: INSERT 1
-- msg: ROLLBACK
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.PARENT
-- error 23503: violates foreign key constraint: FOREIGN KEY (PARENT_ID) REFERENCES ":memory:".PUBLIC.PARENT (ID) on ":memory:".PUBLIC.CHILD

-- # The names of the other constraints are read back from the file.
/* connection 1 */
CREATE TABLE t (a INT NOT NULL CHECK (a > 0), b INT NOT NULL UNIQUE CHECK (b > 0), c INT PRIMARY KEY);
ALTER TABLE t DROP CONSTRAINT t_not_null_1;
ALTER TABLE t DROP CONSTRAINT t_check_1;
ALTER TABLE t DROP CONSTRAINT t_primary_key;
/* connection 2 */
SELECT constraint_name, constraint_type FROM information_schema.table_constraints;
INSERT INTO t (a, b, c) VALUES (NULL, 1, 1), (-1, 2, 1);
INSERT INTO t (a, b, c) VALUES (NULL, 1, 2);
INSERT INTO t (a, b, c) VALUES (NULL, 3, NULL);
-- 1: msg: CREATE TABLE 1
-- 1: msg: ALTER TABLE 1
-- 1: msg: ALTER TABLE 1
-- 1: msg: ALTER TABLE 1
-- 2: CONSTRAINT_NAME: T_UNIQUE_1 CONSTRAINT_TYPE: UNIQUE
-- 2: CONSTRAINT_NAME: T_NOT_NULL_2 CONSTRAINT_TYPE: CHECK
-- 2: CONSTRAINT_NAME: T_NOT_NULL_3 CONSTRAINT_TYPE: CHECK
-- 2: CONSTRAINT_NAME: T_CHECK_2 CONSTRAINT_TYPE: CHECK
-- 2: msg: INSERT 2
-- 2: error 23505: violates unique constraint: UNIQUE (B) on "test".PUBLIC.T
-- 2: error 23502: violates non-null constraint: column C

-- # A dump doesn't have the dropped constraints, and the other constraints keep
-- # their names when it's loaded.
CREATE TABLE parent (id INT PRIMARY KEY, code INT UNIQUE);
CREATE TABLE t (a INT PRIMARY KEY CHECK (a > 0) CHECK (a < 10), b INT NOT NULL UNIQUE REFERENCES parent, c INT UNIQUE REFERENCES parent (code), d INT NOT NULL);
INSERT INTO parent (id, code) VALUES (1, 1);
INSERT INTO t (a, b, c, d) VALUES (1, 1, 1, 1);
ALTER TABLE parent DROP CONSTRAINT parent_unique_1 CASCADE;
ALTER TABLE t DROP CONSTRAINT t_primary_key;
ALTER TABLE t DROP CONSTRAINT t_check_1;
ALTER TABLE t DROP CONSTRAINT t_unique_1;
ALTER TABLE t DROP CONSTRAINT t_not_null_2;
/* out */
/* in */
SELECT constraint_name, table_name, constraint_type FROM information_schema.table_constraints;
INSERT INTO t (a, b, c, d) VALUES (1, NULL, 2, 1);
INSERT INTO t (a, b, c, d) VALUES (-1, 1, 3, 1);
INSERT INTO t (a, b, c, d) VALUES (10, 1, 4, 1);
INSERT INTO t (a, b, c, d) VALUES (1, 1, 1, 1);
INSERT INTO t (a, b, c, d) VALUES (1, 2, 5, 1);
INSERT INTO t (a, b, c, d) VALUES (NULL, 1, 6, 1);
INSERT INTO t (a, b, c, d) VALUES (1, 1, 7, NULL);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- out: CREATE TABLE "PUBLIC"."PARENT" (
-- out:   "ID" INTEGER NOT NULL,
-- out:   "CODE" INTEGER,
-- out:   PRIMARY KEY ("ID")
-- out: );
-- out: INSERT INTO "PUBLIC"."PARENT" ("ID", "CODE") VALUES (1, 1);
-- out: CREATE TABLE "PUBLIC"."T" (
-- out:   "A" INTEGER NOT NULL,
-- out:   "B" INTEGER,
-- out:   "C" INTEGER,
-- out:   "D" INTEGER NOT NULL,
-- out:   CONSTRAINT "T_UNIQUE_2" UNIQUE ("C"),
-- out:   CONSTRAINT "T_CHECK_2" CHECK (A < 10)
-- out: );
-- out: INSERT INTO "PUBLIC"."T" ("A", "B", "C", "D") VALUES (1, 1, 1, 1);
-- out: ALTER TABLE "PUBLIC"."T" ADD CONSTRAINT "T_FOREIGN_KEY_1" FOREIGN KEY ("B") REFERENCES "PUBLIC"."PARENT" ("ID");
-- CONSTRAINT_NAME: PARENT_PRIMARY_KEY TABLE_NAME: PARENT CONSTRAINT_TYPE: PRIMARY KEY
-- CONSTRAINT_NAME: PARENT_NOT_NULL_1 TABLE_NAME: PARENT CONSTRAINT_TYPE: CHECK
-- CONSTRAINT_NAME: T_UNIQUE_2 TABLE_NAME: T CONSTRAINT_TYPE: UNIQUE
-- CONSTRAINT_NAME: T_FOREIGN_KEY_1 TABLE_NAME: T CONSTRAINT_TYPE: FOREIGN KEY
-- CONSTRAINT_NAME: T_NOT_NULL_1 TABLE_NAME: T CONSTRAINT_TYPE: CHECK
-- CONSTRAINT_NAME: T_NOT_NULL_4 TABLE_NAME: T CONSTRAINT_TYPE: CHECK
-- CONSTRAINT_NAME: T_CHECK_2 TABLE_NAME: T CONSTRAINT_TYPE: CHECK
-- msg: INSERT 1
-- msg: INSERT 1
-- error 23514: violates check constraint: CHECK (A < 10) on ":memory:".PUBLIC.T
-- error 23505: violates unique constraint: UNIQUE (C) on ":memory:".PUBLIC.T
-- error 23503: violates foreign key constraint: FOREIGN KEY (B) REFERENCES ":memory:".PUBLIC.PARENT (ID) on ":memory:".PUBLIC.T
-- error 23502: violates non-null constraint: column A
-- error 23502: violates non-null constraint: column D
-- A: 1 B: 1 C: 1 D: 1
-- A: 1 B: NULL C: 2 D: 1
-- A: -1 B: 1 C: 3 D: 1
