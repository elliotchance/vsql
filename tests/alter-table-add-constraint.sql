-- # A CHECK must be satisfied by every row, and is then checked like any other
-- # CHECK.
CREATE TABLE t (a INT);
INSERT INTO t (a) VALUES (1), (-1), (NULL);
ALTER TABLE t ADD CHECK (a > 0);
DELETE FROM t WHERE a = -1;
ALTER TABLE t ADD CHECK (a > 0);
INSERT INTO t (a) VALUES (-2);
ALTER TABLE t ADD CONSTRAINT positive CHECK (a > 0);
SELECT constraint_name, check_clause FROM information_schema.check_constraints;
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- error 23514: violates check constraint: CHECK (A > 0) on ":memory:".PUBLIC.T
-- msg: DELETE 1
-- msg: ALTER TABLE 1
-- error 23514: violates check constraint: CHECK (A > 0) on ":memory:".PUBLIC.T
-- msg: ALTER TABLE 1
-- CONSTRAINT_NAME: T_CHECK_1 CHECK_CLAUSE: A > 0
-- CONSTRAINT_NAME: POSITIVE CHECK_CLAUSE: A > 0

-- # A UNIQUE must be satisfied by every row (NULLs are never equal).
CREATE TABLE t (a INT, b INT);
INSERT INTO t (a, b) VALUES (1, 1), (2, 1), (NULL, 2), (NULL, 3);
ALTER TABLE t ADD UNIQUE (b);
ALTER TABLE t ADD CONSTRAINT a_unique UNIQUE (a);
INSERT INTO t (a, b) VALUES (1, 4);
INSERT INTO t (a, b) VALUES (NULL, 4);
ALTER TABLE t ADD UNIQUE (a);
SELECT constraint_name, constraint_type FROM information_schema.table_constraints;
-- msg: CREATE TABLE 1
-- msg: INSERT 4
-- error 23505: violates unique constraint: UNIQUE (B) on ":memory:".PUBLIC.T
-- msg: ALTER TABLE 1
-- error 23505: violates unique constraint: UNIQUE (A) on ":memory:".PUBLIC.T
-- msg: INSERT 1
-- error 42601: syntax error: UNIQUE (A) has the same columns as another unique constraint
-- CONSTRAINT_NAME: A_UNIQUE CONSTRAINT_TYPE: UNIQUE

-- # A PRIMARY KEY makes its columns NOT NULL, and the rows are then stored by
-- # the PRIMARY KEY. A table can only have one PRIMARY KEY.
CREATE TABLE t (a INT, b VARCHAR(10));
INSERT INTO t (a, b) VALUES (3, 'c'), (1, 'a'), (NULL, 'x');
ALTER TABLE t ADD PRIMARY KEY (a);
DELETE FROM t WHERE a IS NULL;
INSERT INTO t (a, b) VALUES (1, 'z');
ALTER TABLE t ADD PRIMARY KEY (a);
DELETE FROM t WHERE b = 'z';
ALTER TABLE t ADD PRIMARY KEY (a);
INSERT INTO t (a, b) VALUES (2, 'b');
INSERT INTO t (a, b) VALUES (2, 'b');
INSERT INTO t (a, b) VALUES (NULL, 'b');
ALTER TABLE t ADD CONSTRAINT pk2 PRIMARY KEY (b);
SELECT * FROM t;
SELECT constraint_name, constraint_type FROM information_schema.table_constraints;
SELECT column_name, is_nullable FROM information_schema.columns WHERE table_name = 'T';
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- error 23502: violates non-null constraint: column A
-- msg: DELETE 1
-- msg: INSERT 1
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T
-- msg: DELETE 1
-- msg: ALTER TABLE 1
-- msg: INSERT 1
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T
-- error 23502: violates non-null constraint: column A
-- error 42601: syntax error: only one PRIMARY KEY can be defined
-- A: 1 B: a
-- A: 2 B: b
-- A: 3 B: c
-- CONSTRAINT_NAME: T_PRIMARY_KEY CONSTRAINT_TYPE: PRIMARY KEY
-- CONSTRAINT_NAME: T_NOT_NULL_1 CONSTRAINT_TYPE: CHECK
-- COLUMN_NAME: A IS_NULLABLE: NO
-- COLUMN_NAME: B IS_NULLABLE: YES

-- # A FOREIGN KEY must be satisfied by every row, including a row that
-- # references a row of the same table.
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (id INT PRIMARY KEY, parent_id INT, manager_id INT);
INSERT INTO parent (id) VALUES (1);
INSERT INTO child (id, parent_id, manager_id) VALUES (1, 1, 2), (2, 2, NULL), (3, NULL, 4);
ALTER TABLE child ADD FOREIGN KEY (parent_id) REFERENCES parent;
ALTER TABLE child ADD FOREIGN KEY (manager_id) REFERENCES child;
DELETE FROM child WHERE id = 2;
ALTER TABLE child ADD FOREIGN KEY (parent_id) REFERENCES parent;
UPDATE child SET manager_id = NULL;
INSERT INTO child (id, manager_id) VALUES (2, 3), (4, 2);
ALTER TABLE child ADD CONSTRAINT manager FOREIGN KEY (manager_id) REFERENCES child;
INSERT INTO child (id, parent_id) VALUES (5, 2);
INSERT INTO child (id, manager_id) VALUES (5, 6);
DELETE FROM parent;
DELETE FROM child WHERE id = 3;
SELECT constraint_name, unique_constraint_name FROM information_schema.referential_constraints;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 3
-- error 23503: violates foreign key constraint: FOREIGN KEY (PARENT_ID) REFERENCES ":memory:".PUBLIC.PARENT (ID) on ":memory:".PUBLIC.CHILD
-- error 23503: violates foreign key constraint: FOREIGN KEY (MANAGER_ID) REFERENCES ":memory:".PUBLIC.CHILD (ID) on ":memory:".PUBLIC.CHILD
-- msg: DELETE 1
-- msg: ALTER TABLE 1
-- msg: UPDATE 2
-- msg: INSERT 2
-- msg: ALTER TABLE 1
-- error 23503: violates foreign key constraint: FOREIGN KEY (PARENT_ID) REFERENCES ":memory:".PUBLIC.PARENT (ID) on ":memory:".PUBLIC.CHILD
-- error 23503: violates foreign key constraint: FOREIGN KEY (MANAGER_ID) REFERENCES ":memory:".PUBLIC.CHILD (ID) on ":memory:".PUBLIC.CHILD
-- error 23503: violates foreign key constraint: FOREIGN KEY (PARENT_ID) REFERENCES ":memory:".PUBLIC.PARENT (ID) on ":memory:".PUBLIC.CHILD
-- error 23503: violates foreign key constraint: FOREIGN KEY (MANAGER_ID) REFERENCES ":memory:".PUBLIC.CHILD (ID) on ":memory:".PUBLIC.CHILD
-- CONSTRAINT_NAME: CHILD_FOREIGN_KEY_1 UNIQUE_CONSTRAINT_NAME: PARENT_PRIMARY_KEY
-- CONSTRAINT_NAME: MANAGER UNIQUE_CONSTRAINT_NAME: CHILD_PRIMARY_KEY

-- # A FOREIGN KEY must reference a unique constraint, and a name must not
-- # already be used in the schema.
CREATE TABLE t (a INT CONSTRAINT a_check CHECK (a > 0), b INT);
CREATE TABLE u (c INT);
ALTER TABLE t ADD FOREIGN KEY (b) REFERENCES t (a);
ALTER TABLE t ADD FOREIGN KEY (b) REFERENCES missing;
ALTER TABLE t ADD CONSTRAINT a_check CHECK (b > 0);
ALTER TABLE u ADD CONSTRAINT a_check UNIQUE (c);
ALTER TABLE u ADD CONSTRAINT other.a_check UNIQUE (c);
ALTER TABLE information_schema.tables ADD CHECK (table_name <> '');
ALTER TABLE missing ADD CHECK (a > 0);
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- error 42830: invalid foreign key: there is no PRIMARY KEY or UNIQUE (A) on ":memory:".PUBLIC.T
-- error 42P01: no such table: ":memory:".PUBLIC.MISSING
-- error 42710: duplicate constraint: A_CHECK
-- error 42710: duplicate constraint: A_CHECK
-- error 42601: syntax error: constraint OTHER.A_CHECK must be in the same schema as table ":memory:".PUBLIC.U
-- error 42501: insufficient privilege: INFORMATION_SCHEMA is read-only
-- error 42P01: no such table: ":memory:".PUBLIC.MISSING

-- # A constraint without a name gets the first name that isn't used, counting
-- # from 1.
CREATE TABLE t (a INT CONSTRAINT t_check_2 CHECK (a > 0));
ALTER TABLE t ADD CHECK (a > 1);
ALTER TABLE t ADD CHECK (a > 2);
SELECT constraint_name, check_clause FROM information_schema.check_constraints;
-- msg: CREATE TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- CONSTRAINT_NAME: T_CHECK_2 CHECK_CLAUSE: A > 0
-- CONSTRAINT_NAME: T_CHECK_1 CHECK_CLAUSE: A > 1
-- CONSTRAINT_NAME: T_CHECK_3 CHECK_CLAUSE: A > 2

-- # A ROLLBACK removes the constraint, and puts the rows back.
CREATE TABLE t (a INT);
INSERT INTO t (a) VALUES (2), (1);
START TRANSACTION;
ALTER TABLE t ADD PRIMARY KEY (a);
ALTER TABLE t ADD CHECK (a > 0);
ROLLBACK;
INSERT INTO t (a) VALUES (1), (-1);
SELECT * FROM t;
SELECT constraint_name FROM information_schema.table_constraints;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: START TRANSACTION
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: ROLLBACK
-- msg: INSERT 2
-- A: 2
-- A: 1
-- A: 1
-- A: -1

-- # The new constraints are read back from the file.
/* connection 1 */
CREATE TABLE t (a INT, b INT);
INSERT INTO t (a, b) VALUES (1, 1);
ALTER TABLE t ADD CONSTRAINT pk PRIMARY KEY (a);
ALTER TABLE t ADD CONSTRAINT fk FOREIGN KEY (b) REFERENCES t;
/* connection 2 */
SELECT constraint_name, constraint_type FROM information_schema.table_constraints;
INSERT INTO t (a, b) VALUES (1, 1);
INSERT INTO t (a, b) VALUES (2, 3);
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: ALTER TABLE 1
-- 1: msg: ALTER TABLE 1
-- 2: CONSTRAINT_NAME: PK CONSTRAINT_TYPE: PRIMARY KEY
-- 2: CONSTRAINT_NAME: FK CONSTRAINT_TYPE: FOREIGN KEY
-- 2: CONSTRAINT_NAME: T_NOT_NULL_1 CONSTRAINT_TYPE: CHECK
-- 2: error 23505: violates unique constraint: PRIMARY KEY on "test".PUBLIC.T
-- 2: error 23503: violates foreign key constraint: FOREIGN KEY (B) REFERENCES "test".PUBLIC.T (A) on "test".PUBLIC.T
-- 2: A: 1 B: 1

-- # A dump can be loaded when a table references a table that comes after it,
-- # a row references a row that comes after it, or tables reference each other.
CREATE TABLE a (id INT PRIMARY KEY, b_id INT);
CREATE TABLE b (id INT PRIMARY KEY, a_id INT REFERENCES a, manager_id INT REFERENCES b);
ALTER TABLE a ADD FOREIGN KEY (b_id) REFERENCES b;
INSERT INTO b (id, manager_id) VALUES (2, NULL);
INSERT INTO a (id, b_id) VALUES (1, 2);
INSERT INTO b (id, a_id, manager_id) VALUES (1, 1, 2);
UPDATE b SET manager_id = 1 WHERE id = 2;
/* out */
/* in */
SELECT * FROM b;
INSERT INTO a (id, b_id) VALUES (2, 3);
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: ALTER TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: UPDATE 1
-- out: CREATE TABLE "PUBLIC"."A" (
-- out:   "ID" INTEGER NOT NULL,
-- out:   "B_ID" INTEGER,
-- out:   PRIMARY KEY ("ID")
-- out: );
-- out: INSERT INTO "PUBLIC"."A" ("ID", "B_ID") VALUES (1, 2);
-- out: CREATE TABLE "PUBLIC"."B" (
-- out:   "ID" INTEGER NOT NULL,
-- out:   "A_ID" INTEGER,
-- out:   "MANAGER_ID" INTEGER,
-- out:   PRIMARY KEY ("ID")
-- out: );
-- out: INSERT INTO "PUBLIC"."B" ("ID", "A_ID", "MANAGER_ID") VALUES (1, 1, 2);
-- out: INSERT INTO "PUBLIC"."B" ("ID", "A_ID", "MANAGER_ID") VALUES (2, NULL, 1);
-- out: ALTER TABLE "PUBLIC"."A" ADD CONSTRAINT "A_FOREIGN_KEY_1" FOREIGN KEY ("B_ID") REFERENCES "PUBLIC"."B" ("ID");
-- out: ALTER TABLE "PUBLIC"."B" ADD CONSTRAINT "B_FOREIGN_KEY_1" FOREIGN KEY ("A_ID") REFERENCES "PUBLIC"."A" ("ID");
-- out: ALTER TABLE "PUBLIC"."B" ADD CONSTRAINT "B_FOREIGN_KEY_2" FOREIGN KEY ("MANAGER_ID") REFERENCES "PUBLIC"."B" ("ID");
-- ID: 1 A_ID: 1 MANAGER_ID: 2
-- ID: 2 A_ID: NULL MANAGER_ID: 1
-- error 23503: violates foreign key constraint: FOREIGN KEY (B_ID) REFERENCES ":memory:".PUBLIC.B (ID) on ":memory:".PUBLIC.A
