-- # A REFERENCES on a column references the PRIMARY KEY of the other table. A
-- # row must reference a row that exists, unless the column is NULL.
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (id INT, parent_id INT REFERENCES parent);
INSERT INTO parent (id) VALUES (1), (2);
INSERT INTO child (id, parent_id) VALUES (1, 1);
INSERT INTO child (id, parent_id) VALUES (2, 3);
INSERT INTO child (id, parent_id) VALUES (3, NULL);
SELECT * FROM child;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: INSERT 1
-- error 23503: violates foreign key constraint: FOREIGN KEY (PARENT_ID) REFERENCES ":memory:".PUBLIC.PARENT (ID) on ":memory:".PUBLIC.CHILD
-- msg: INSERT 1
-- ID: 1 PARENT_ID: 1
-- ID: 3 PARENT_ID: NULL

-- # A FOREIGN KEY on the table can have more than one column, and reference a
-- # UNIQUE constraint. A row with a NULL in any of the columns doesn't need to
-- # reference a row (MATCH SIMPLE).
CREATE TABLE parent (a INT, b INT, UNIQUE (a, b));
CREATE TABLE child (x INT, y INT, FOREIGN KEY (x, y) REFERENCES parent (a, b));
INSERT INTO parent (a, b) VALUES (1, 1), (1, 2);
INSERT INTO child (x, y) VALUES (1, 2);
INSERT INTO child (x, y) VALUES (2, 1);
INSERT INTO child (x, y) VALUES (2, NULL);
INSERT INTO child (x, y) VALUES (NULL, 5);
SELECT * FROM child;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: INSERT 1
-- error 23503: violates foreign key constraint: FOREIGN KEY (X, Y) REFERENCES ":memory:".PUBLIC.PARENT (A, B) on ":memory:".PUBLIC.CHILD
-- msg: INSERT 1
-- msg: INSERT 1
-- X: 1 Y: 2
-- X: 2 Y: NULL
-- X: NULL Y: 5

-- # The referenced columns can be in any order, as long as they're the columns
-- # of a unique constraint. Each column corresponds to the referenced column in
-- # the same position.
CREATE TABLE parent (a INT, b INT, PRIMARY KEY (a, b));
CREATE TABLE child (x INT, y INT, FOREIGN KEY (y, x) REFERENCES parent (b, a));
CREATE TABLE child2 (x INT, y INT, FOREIGN KEY (x, y) REFERENCES parent (b, a));
INSERT INTO parent (a, b) VALUES (1, 2);
INSERT INTO child (x, y) VALUES (1, 2);
INSERT INTO child (x, y) VALUES (2, 1);
INSERT INTO child2 (x, y) VALUES (1, 2);
INSERT INTO child2 (x, y) VALUES (2, 1);
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- error 23503: violates foreign key constraint: FOREIGN KEY (Y, X) REFERENCES ":memory:".PUBLIC.PARENT (B, A) on ":memory:".PUBLIC.CHILD
-- error 23503: violates foreign key constraint: FOREIGN KEY (X, Y) REFERENCES ":memory:".PUBLIC.PARENT (B, A) on ":memory:".PUBLIC.CHILD2
-- msg: INSERT 1

-- # Values that are equal are the same, like a PRIMARY KEY, and the types only
-- # need to be comparable.
CREATE TABLE parent (i INT PRIMARY KEY, n NUMERIC(5, 2) UNIQUE, s VARCHAR(10) UNIQUE, ts TIMESTAMP(0) WITH TIME ZONE UNIQUE);
CREATE TABLE child (i BIGINT REFERENCES parent, n NUMERIC(10, 3) REFERENCES parent (n), s CHAR(5) REFERENCES parent (s), ts TIMESTAMP(3) WITH TIME ZONE REFERENCES parent (ts));
INSERT INTO parent (i, n, s, ts) VALUES (1, 1.5, 'a', TIMESTAMP '2020-01-01 12:00:00+05:00');
INSERT INTO child (i, n, s, ts) VALUES (1, 1.500, 'a', TIMESTAMP '2020-01-01 07:00:00+00:00');
INSERT INTO child (i) VALUES (2);
INSERT INTO child (n) VALUES (1.501);
INSERT INTO child (s) VALUES ('b');
INSERT INTO child (ts) VALUES (TIMESTAMP '2020-01-01 12:00:00+00:00');
CREATE TABLE parent2 (r REAL PRIMARY KEY);
CREATE TABLE child2 (d DOUBLE PRECISION REFERENCES parent2);
INSERT INTO parent2 (r) VALUES (1.5);
INSERT INTO child2 (d) VALUES (1.5);
INSERT INTO child2 (d) VALUES (2.5);
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- error 23503: violates foreign key constraint: FOREIGN KEY (I) REFERENCES ":memory:".PUBLIC.PARENT (I) on ":memory:".PUBLIC.CHILD
-- error 23503: violates foreign key constraint: FOREIGN KEY (N) REFERENCES ":memory:".PUBLIC.PARENT (N) on ":memory:".PUBLIC.CHILD
-- error 23503: violates foreign key constraint: FOREIGN KEY (S) REFERENCES ":memory:".PUBLIC.PARENT (S) on ":memory:".PUBLIC.CHILD
-- error 23503: violates foreign key constraint: FOREIGN KEY (TS) REFERENCES ":memory:".PUBLIC.PARENT (TS) on ":memory:".PUBLIC.CHILD
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- error 23503: violates foreign key constraint: FOREIGN KEY (D) REFERENCES ":memory:".PUBLIC.PARENT2 (R) on ":memory:".PUBLIC.CHILD2

-- # Any two numeric types are comparable (T201). An exact numeric is compared
-- # with an approximate numeric as a DOUBLE PRECISION.
CREATE TABLE parent (i INT PRIMARY KEY, n NUMERIC(5, 2) UNIQUE, r REAL UNIQUE);
CREATE TABLE child (n NUMERIC(10, 1) REFERENCES parent, d DOUBLE PRECISION REFERENCES parent (n), i BIGINT REFERENCES parent (r));
INSERT INTO parent (i, n, r) VALUES (1, 1.5, 2);
INSERT INTO child (n, d, i) VALUES (1.0, 1.5e0, 2);
INSERT INTO child (n) VALUES (1.5);
INSERT INTO child (d) VALUES (1.25e0);
INSERT INTO child (i) VALUES (3);
DELETE FROM parent;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- error 23503: violates foreign key constraint: FOREIGN KEY (N) REFERENCES ":memory:".PUBLIC.PARENT (I) on ":memory:".PUBLIC.CHILD
-- error 23503: violates foreign key constraint: FOREIGN KEY (D) REFERENCES ":memory:".PUBLIC.PARENT (N) on ":memory:".PUBLIC.CHILD
-- error 23503: violates foreign key constraint: FOREIGN KEY (I) REFERENCES ":memory:".PUBLIC.PARENT (R) on ":memory:".PUBLIC.CHILD
-- error 23503: violates foreign key constraint: FOREIGN KEY (N) REFERENCES ":memory:".PUBLIC.PARENT (I) on ":memory:".PUBLIC.CHILD

-- # A BIGINT that references an INTEGER is compared as a BIGINT.
CREATE TABLE parent (i INT PRIMARY KEY);
CREATE TABLE child (i BIGINT REFERENCES parent);
INSERT INTO parent (i) VALUES (1);
INSERT INTO child (i) VALUES (4294967297);
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 23503: violates foreign key constraint: FOREIGN KEY (I) REFERENCES ":memory:".PUBLIC.PARENT (I) on ":memory:".PUBLIC.CHILD

-- # A multi-row INSERT is checked once all of its rows have been written, so a
-- # row can reference another row of the same INSERT. If any row doesn't
-- # reference a row, none of them are inserted.
CREATE TABLE emp (id INT PRIMARY KEY, manager_id INT REFERENCES emp);
INSERT INTO emp (id, manager_id) VALUES (1, 1);
INSERT INTO emp (id, manager_id) VALUES (2, 3), (3, 1);
INSERT INTO emp (id, manager_id) VALUES (4, 5), (5, 6);
INSERT INTO emp (id, manager_id) VALUES (6, 7);
SELECT * FROM emp;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 2
-- error 23503: violates foreign key constraint: FOREIGN KEY (MANAGER_ID) REFERENCES ":memory:".PUBLIC.EMP (ID) on ":memory:".PUBLIC.EMP
-- error 23503: violates foreign key constraint: FOREIGN KEY (MANAGER_ID) REFERENCES ":memory:".PUBLIC.EMP (ID) on ":memory:".PUBLIC.EMP
-- ID: 1 MANAGER_ID: 1
-- ID: 2 MANAGER_ID: 3
-- ID: 3 MANAGER_ID: 1

-- # A row that's referenced can't be deleted (ON DELETE NO ACTION). It's
-- # checked once all of the rows have been deleted, so a DELETE can include the
-- # rows that reference it.
CREATE TABLE emp (id INT PRIMARY KEY, manager_id INT REFERENCES emp);
INSERT INTO emp (id, manager_id) VALUES (1, NULL), (2, 1), (3, 2), (4, NULL);
DELETE FROM emp WHERE id = 2;
DELETE FROM emp WHERE id >= 2;
DELETE FROM emp WHERE id = 1;
SELECT * FROM emp;
-- msg: CREATE TABLE 1
-- msg: INSERT 4
-- error 23503: violates foreign key constraint: FOREIGN KEY (MANAGER_ID) REFERENCES ":memory:".PUBLIC.EMP (ID) on ":memory:".PUBLIC.EMP
-- msg: DELETE 3
-- msg: DELETE 1

CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (parent_id INT REFERENCES parent);
INSERT INTO parent (id) VALUES (1), (2);
INSERT INTO child (parent_id) VALUES (1), (NULL);
DELETE FROM parent WHERE id = 1;
DELETE FROM parent WHERE id = 2;
DELETE FROM child WHERE parent_id = 1;
DELETE FROM parent;
SELECT * FROM parent;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: INSERT 2
-- error 23503: violates foreign key constraint: FOREIGN KEY (PARENT_ID) REFERENCES ":memory:".PUBLIC.PARENT (ID) on ":memory:".PUBLIC.CHILD
-- msg: DELETE 1
-- msg: DELETE 1
-- msg: DELETE 1

-- # The referenced columns of a row that's referenced can't change (ON UPDATE
-- # NO ACTION), unless another row gets the same values in the same UPDATE.
-- # Other columns can change.
CREATE TABLE parent (id INT PRIMARY KEY, code INT UNIQUE, name VARCHAR(10));
CREATE TABLE child (parent_id INT REFERENCES parent, parent_code INT REFERENCES parent (code));
INSERT INTO parent (id, code, name) VALUES (1, 10, 'a'), (2, 20, 'b');
INSERT INTO child (parent_id, parent_code) VALUES (1, 20);
UPDATE parent SET id = 3 WHERE id = 1;
UPDATE parent SET code = 30 WHERE code = 20;
UPDATE parent SET name = 'c';
UPDATE parent SET id = 3 - id;
UPDATE parent SET code = 30 - code;
UPDATE parent SET id = id + 1, code = code + 1;
SELECT * FROM parent;
SELECT * FROM child;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: INSERT 1
-- error 23503: violates foreign key constraint: FOREIGN KEY (PARENT_ID) REFERENCES ":memory:".PUBLIC.PARENT (ID) on ":memory:".PUBLIC.CHILD
-- error 23503: violates foreign key constraint: FOREIGN KEY (PARENT_CODE) REFERENCES ":memory:".PUBLIC.PARENT (CODE) on ":memory:".PUBLIC.CHILD
-- msg: UPDATE 2
-- msg: UPDATE 2
-- msg: UPDATE 2
-- error 23503: violates foreign key constraint: FOREIGN KEY (PARENT_ID) REFERENCES ":memory:".PUBLIC.PARENT (ID) on ":memory:".PUBLIC.CHILD
-- ID: 1 CODE: 10 NAME: c
-- ID: 2 CODE: 20 NAME: c
-- PARENT_ID: 1 PARENT_CODE: 20

-- # An UPDATE of the referencing columns must still reference a row.
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (parent_id INT REFERENCES parent);
INSERT INTO parent (id) VALUES (1), (2);
INSERT INTO child (parent_id) VALUES (1);
UPDATE child SET parent_id = 2;
UPDATE child SET parent_id = 3;
UPDATE child SET parent_id = NULL;
SELECT * FROM child;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: INSERT 1
-- msg: UPDATE 1
-- error 23503: violates foreign key constraint: FOREIGN KEY (PARENT_ID) REFERENCES ":memory:".PUBLIC.PARENT (ID) on ":memory:".PUBLIC.CHILD
-- msg: UPDATE 1
-- PARENT_ID: NULL

-- # A row of a self-referencing table can change its key along with the rows
-- # that reference it.
CREATE TABLE emp (id INT PRIMARY KEY, manager_id INT REFERENCES emp);
INSERT INTO emp (id, manager_id) VALUES (1, NULL), (2, 1);
UPDATE emp SET id = id + 10;
UPDATE emp SET id = id + 10, manager_id = manager_id + 10;
SELECT * FROM emp;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- error 23503: violates foreign key constraint: FOREIGN KEY (MANAGER_ID) REFERENCES ":memory:".PUBLIC.EMP (ID) on ":memory:".PUBLIC.EMP
-- msg: UPDATE 2
-- ID: 11 MANAGER_ID: NULL
-- ID: 12 MANAGER_ID: 11

-- # A row that's deleted in a transaction can't be referenced by a later
-- # statement, and a row that's inserted can be.
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (parent_id INT REFERENCES parent);
INSERT INTO parent (id) VALUES (1);
START TRANSACTION;
DELETE FROM parent;
INSERT INTO child (parent_id) VALUES (1);
INSERT INTO parent (id) VALUES (2);
INSERT INTO child (parent_id) VALUES (2);
DELETE FROM parent;
COMMIT;
SELECT * FROM child;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: DELETE 1
-- error 23503: violates foreign key constraint: FOREIGN KEY (PARENT_ID) REFERENCES ":memory:".PUBLIC.PARENT (ID) on ":memory:".PUBLIC.CHILD
-- msg: INSERT 1
-- msg: INSERT 1
-- error 23503: violates foreign key constraint: FOREIGN KEY (PARENT_ID) REFERENCES ":memory:".PUBLIC.PARENT (ID) on ":memory:".PUBLIC.CHILD
-- msg: COMMIT
-- PARENT_ID: 2

-- # The referenced table and columns are checked when the table is created.
CREATE TABLE parent (id INT PRIMARY KEY, a INT, b INT, u INT UNIQUE, v VARCHAR(10) UNIQUE, d DATE UNIQUE, UNIQUE (a, b));
CREATE TABLE nokey (id INT);
CREATE TABLE child (x INT REFERENCES missing);
CREATE TABLE child (x INT REFERENCES nokey);
CREATE TABLE child (x INT REFERENCES parent (a));
CREATE TABLE child (x INT REFERENCES parent (z));
CREATE TABLE child (x INT REFERENCES parent (a, b));
CREATE TABLE child (x INT, y INT, FOREIGN KEY (x, y) REFERENCES parent);
CREATE TABLE child (x INT, y INT, FOREIGN KEY (x, y) REFERENCES parent (a, a));
CREATE TABLE child (x INT, FOREIGN KEY (x, x) REFERENCES parent (a, b));
CREATE TABLE child (x INT, FOREIGN KEY (z) REFERENCES parent);
CREATE TABLE child (x VARCHAR(10) REFERENCES parent);
CREATE TABLE child (x INT REFERENCES parent (v));
CREATE TABLE child (x TIMESTAMP REFERENCES parent (d));
CREATE TABLE child (x INT REFERENCES information_schema.tables);
CREATE TABLE child (x INT REFERENCES other.public.parent);
CREATE TABLE child (x INT REFERENCES missing.parent);
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- error 42P01: no such table: ":memory:".PUBLIC.MISSING
-- error 42830: invalid foreign key: ":memory:".PUBLIC.NOKEY has no PRIMARY KEY
-- error 42830: invalid foreign key: there is no PRIMARY KEY or UNIQUE (A) on ":memory:".PUBLIC.PARENT
-- error 42703: no such column: Z
-- error 42830: invalid foreign key: FOREIGN KEY has 1 column but REFERENCES ":memory:".PUBLIC.PARENT has 2
-- error 42830: invalid foreign key: FOREIGN KEY has 2 columns but REFERENCES ":memory:".PUBLIC.PARENT has 1
-- error 42601: syntax error: column A appears more than once in REFERENCES
-- error 42601: syntax error: column X appears more than once in FOREIGN KEY
-- error 42601: syntax error: unknown column Z in FOREIGN KEY
-- error 42804: data type mismatch in FOREIGN KEY: expected INTEGER but got CHARACTER VARYING(10)
-- error 42804: data type mismatch in FOREIGN KEY: expected CHARACTER VARYING(10) but got INTEGER
-- error 42804: data type mismatch in FOREIGN KEY: expected DATE but got TIMESTAMP(6) WITHOUT TIME ZONE
-- error 42501: insufficient privilege: INFORMATION_SCHEMA is read-only
-- error 0A000: FOREIGN KEY cannot reference a table in another catalog: OTHER.PUBLIC.PARENT
-- error 3F000: invalid schema name: MISSING

-- # A table can reference itself, including a UNIQUE that's defined after the
-- # FOREIGN KEY.
CREATE TABLE t (a INT REFERENCES t (b), b INT UNIQUE, c INT REFERENCES t);
CREATE TABLE t (a INT REFERENCES t (b), b INT UNIQUE);
INSERT INTO t (a, b) VALUES (1, 1);
INSERT INTO t (a, b) VALUES (1, 2);
INSERT INTO t (a, b) VALUES (3, 4);
SELECT * FROM t;
-- error 42830: invalid foreign key: ":memory:".PUBLIC.T has no PRIMARY KEY
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- error 23503: violates foreign key constraint: FOREIGN KEY (A) REFERENCES ":memory:".PUBLIC.T (B) on ":memory:".PUBLIC.T
-- A: 1 B: 1
-- A: 1 B: 2

-- # A table that's referenced by another table can't be dropped, but a table
-- # that only references itself can be.
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (parent_id INT REFERENCES parent);
CREATE TABLE emp (id INT PRIMARY KEY, manager_id INT REFERENCES emp);
DROP TABLE parent;
DROP TABLE emp;
DROP TABLE child;
DROP TABLE parent;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- error 2BP01: dependent objects still exist on ":memory:".PUBLIC.PARENT
-- msg: DROP TABLE 1
-- msg: DROP TABLE 1
-- msg: DROP TABLE 1

-- # DROP TABLE CASCADE drops the FOREIGN KEYs of the other tables that
-- # reference it.
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (parent_id INT REFERENCES parent, id INT PRIMARY KEY, p INT REFERENCES child);
INSERT INTO parent (id) VALUES (1);
INSERT INTO child (parent_id, id) VALUES (1, 1);
DROP TABLE parent RESTRICT;
DROP TABLE parent CASCADE;
INSERT INTO child (parent_id, id) VALUES (2, 2);
INSERT INTO child (parent_id, id, p) VALUES (3, 3, 4);
SELECT * FROM child;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- error 2BP01: dependent objects still exist on ":memory:".PUBLIC.PARENT
-- msg: DROP TABLE 1
-- msg: INSERT 1
-- error 23503: violates foreign key constraint: FOREIGN KEY (P) REFERENCES ":memory:".PUBLIC.CHILD (ID) on ":memory:".PUBLIC.CHILD
-- PARENT_ID: 1 ID: 1 P: NULL
-- PARENT_ID: 2 ID: 2 P: NULL

-- # DROP SCHEMA CASCADE drops the FOREIGN KEYs of the tables in other schemas
-- # that reference its tables.
CREATE SCHEMA s;
CREATE TABLE s.parent (id INT PRIMARY KEY);
CREATE TABLE s.child (parent_id INT REFERENCES s.parent);
CREATE TABLE child (parent_id INT REFERENCES s.parent, id INT PRIMARY KEY, p INT REFERENCES child);
INSERT INTO s.parent (id) VALUES (1);
INSERT INTO child (parent_id, id) VALUES (1, 1);
DROP SCHEMA s CASCADE;
INSERT INTO child (parent_id, id) VALUES (2, 2);
INSERT INTO child (parent_id, id, p) VALUES (3, 3, 4);
SELECT * FROM child;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: DROP SCHEMA 1
-- msg: INSERT 1
-- error 23503: violates foreign key constraint: FOREIGN KEY (P) REFERENCES ":memory:".PUBLIC.CHILD (ID) on ":memory:".PUBLIC.CHILD
-- PARENT_ID: 1 ID: 1 P: NULL
-- PARENT_ID: 2 ID: 2 P: NULL

/* connection 1 */
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (parent_id INT REFERENCES parent);
INSERT INTO parent (id) VALUES (1), (2), (4);
INSERT INTO child (parent_id) VALUES (2);
START TRANSACTION;
INSERT INTO parent (id) VALUES (3);
DELETE FROM parent WHERE id = 1;
INSERT INTO child (parent_id) VALUES (2);
INSERT INTO child (parent_id) VALUES (4);
/* connection 2 */
INSERT INTO child (parent_id) VALUES (3);
INSERT INTO child (parent_id) VALUES (1);
DELETE FROM parent WHERE id = 2;
DELETE FROM parent WHERE id = 4;
/* connection 1 */
COMMIT;
/* connection 2 */
INSERT INTO child (parent_id) VALUES (3);
INSERT INTO child (parent_id) VALUES (1);
SELECT * FROM child;
-- 1: msg: CREATE TABLE 1
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 3
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: msg: INSERT 1
-- 1: msg: DELETE 1
-- 1: msg: INSERT 1
-- 1: msg: INSERT 1
-- 2: error 40001: serialization failure: avoiding concurrent write on individual row
-- 2: error 40001: serialization failure: avoiding concurrent write on individual row
-- 2: error 23503: violates foreign key constraint: FOREIGN KEY (PARENT_ID) REFERENCES "test".PUBLIC.PARENT (ID) on "test".PUBLIC.CHILD
-- 2: error 40001: serialization failure: avoiding concurrent write on individual row
-- 1: msg: COMMIT
-- 2: msg: INSERT 1
-- 2: error 23503: violates foreign key constraint: FOREIGN KEY (PARENT_ID) REFERENCES "test".PUBLIC.PARENT (ID) on "test".PUBLIC.CHILD
-- 2: PARENT_ID: 2
-- 2: PARENT_ID: 2
-- 2: PARENT_ID: 4
-- 2: PARENT_ID: 3

-- # The constraints are part of the table definition in the file, so they must
-- # be read back the same.
/* connection 1 */
CREATE SCHEMA "my schema";
CREATE TABLE "my schema"."my parent" ("a b" INT, c INT, UNIQUE (c, "a b"));
CREATE TABLE "my child" (x INT, y INT, FOREIGN KEY (y, x) REFERENCES "my schema"."my parent" ("a b", c));
/* connection 2 */
INSERT INTO "my schema"."my parent" ("a b", c) VALUES (1, 2);
INSERT INTO "my child" (x, y) VALUES (2, 1);
INSERT INTO "my child" (x, y) VALUES (1, 2);
DELETE FROM "my schema"."my parent";
-- 1: msg: CREATE SCHEMA 1
-- 1: msg: CREATE TABLE 1
-- 1: msg: CREATE TABLE 1
-- 2: msg: INSERT 1
-- 2: msg: INSERT 1
-- 2: error 23503: violates foreign key constraint: FOREIGN KEY (Y, X) REFERENCES "test"."my schema"."my parent" ("a b", C) on "test".PUBLIC."my child"
-- 2: error 23503: violates foreign key constraint: FOREIGN KEY (Y, X) REFERENCES "test"."my schema"."my parent" ("a b", C) on "test".PUBLIC."my child"

-- # The constraints are dumped with the referenced columns, once all of the
-- # tables and rows have been dumped, so that they can be loaded in any order.
CREATE TABLE a (id INT PRIMARY KEY);
CREATE TABLE b (a_id INT REFERENCES a, id INT UNIQUE, CHECK (id > 0));
INSERT INTO a (id) VALUES (1);
INSERT INTO b (a_id, id) VALUES (1, 1);
/* out */
/* in */
/* out */
INSERT INTO b (a_id, id) VALUES (2, 2);
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- out: CREATE TABLE "PUBLIC"."A" (
-- out:   "ID" INTEGER NOT NULL,
-- out:   PRIMARY KEY ("ID")
-- out: );
-- out: INSERT INTO "PUBLIC"."A" ("ID") VALUES (1);
-- out: CREATE TABLE "PUBLIC"."B" (
-- out:   "A_ID" INTEGER,
-- out:   "ID" INTEGER,
-- out:   UNIQUE ("ID"),
-- out:   CHECK (ID > 0)
-- out: );
-- out: INSERT INTO "PUBLIC"."B" ("A_ID", "ID") VALUES (1, 1);
-- out: ALTER TABLE "PUBLIC"."B" ADD CONSTRAINT "B_FOREIGN_KEY_1" FOREIGN KEY ("A_ID") REFERENCES "PUBLIC"."A" ("ID");
-- out: CREATE TABLE "PUBLIC"."A" (
-- out:   "ID" INTEGER NOT NULL,
-- out:   PRIMARY KEY ("ID")
-- out: );
-- out: INSERT INTO "PUBLIC"."A" ("ID") VALUES (1);
-- out: CREATE TABLE "PUBLIC"."B" (
-- out:   "A_ID" INTEGER,
-- out:   "ID" INTEGER,
-- out:   UNIQUE ("ID"),
-- out:   CHECK (ID > 0)
-- out: );
-- out: INSERT INTO "PUBLIC"."B" ("A_ID", "ID") VALUES (1, 1);
-- out: ALTER TABLE "PUBLIC"."B" ADD CONSTRAINT "B_FOREIGN_KEY_1" FOREIGN KEY ("A_ID") REFERENCES "PUBLIC"."A" ("ID");
-- error 23503: violates foreign key constraint: FOREIGN KEY (A_ID) REFERENCES ":memory:".PUBLIC.A (ID) on ":memory:".PUBLIC.B

-- # ALTER TABLE ADD COLUMN keeps the FOREIGN KEYs of the table, and every row
-- # must reference a row with the default of a new REFERENCES column.
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (id INT PRIMARY KEY, parent_id INT REFERENCES parent);
INSERT INTO parent (id) VALUES (1);
INSERT INTO child (id, parent_id) VALUES (1, 1), (2, NULL);
ALTER TABLE child ADD COLUMN p2 INT DEFAULT 2 REFERENCES parent;
ALTER TABLE child ADD COLUMN p2 INT DEFAULT 1 REFERENCES parent;
ALTER TABLE child ADD COLUMN p3 INT REFERENCES child;
ALTER TABLE parent ADD COLUMN name VARCHAR(10);
INSERT INTO child (id, parent_id) VALUES (3, 2);
INSERT INTO child (id, p2) VALUES (3, 2);
INSERT INTO child (id, p3) VALUES (3, 4);
INSERT INTO child (id, p3) VALUES (3, 3);
DELETE FROM parent;
SELECT * FROM child;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 2
-- error 23503: violates foreign key constraint: FOREIGN KEY (P2) REFERENCES ":memory:".PUBLIC.PARENT (ID) on ":memory:".PUBLIC.CHILD
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- error 23503: violates foreign key constraint: FOREIGN KEY (PARENT_ID) REFERENCES ":memory:".PUBLIC.PARENT (ID) on ":memory:".PUBLIC.CHILD
-- error 23503: violates foreign key constraint: FOREIGN KEY (P2) REFERENCES ":memory:".PUBLIC.PARENT (ID) on ":memory:".PUBLIC.CHILD
-- error 23503: violates foreign key constraint: FOREIGN KEY (P3) REFERENCES ":memory:".PUBLIC.CHILD (ID) on ":memory:".PUBLIC.CHILD
-- msg: INSERT 1
-- error 23503: violates foreign key constraint: FOREIGN KEY (PARENT_ID) REFERENCES ":memory:".PUBLIC.PARENT (ID) on ":memory:".PUBLIC.CHILD
-- ID: 1 PARENT_ID: 1 P2: 1 P3: NULL
-- ID: 2 PARENT_ID: NULL P2: 1 P3: NULL
-- ID: 3 PARENT_ID: NULL P2: 1 P3: 3
