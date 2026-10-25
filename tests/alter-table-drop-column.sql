-- # A column is dropped from the definition of the table and from every row,
-- # including rows that were written before a column was added. COLUMN is
-- # optional.
CREATE TABLE t (a INT NOT NULL, b VARCHAR(10), c BOOLEAN);
INSERT INTO t (a, b, c) VALUES (1, 'x', TRUE), (2, NULL, FALSE);
ALTER TABLE t ADD COLUMN d INT DEFAULT 5;
INSERT INTO t (a, b, c) VALUES (3, 'z', NULL);
ALTER TABLE t DROP COLUMN b;
SELECT * FROM t;
ALTER TABLE t DROP a RESTRICT;
ALTER TABLE t ADD COLUMN b VARCHAR(10);
INSERT INTO t (c, d, b) VALUES (TRUE, 6, 'y');
SELECT * FROM t;
SELECT column_name, ordinal_position FROM information_schema.columns WHERE table_name = 'T';
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: ALTER TABLE 1
-- msg: INSERT 1
-- msg: ALTER TABLE 1
-- A: 1 C: TRUE D: 5
-- A: 2 C: FALSE D: 5
-- A: 3 C: UNKNOWN D: 5
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: INSERT 1
-- C: TRUE D: 5 B: NULL
-- C: FALSE D: 5 B: NULL
-- C: UNKNOWN D: 5 B: NULL
-- C: TRUE D: 6 B: y
-- COLUMN_NAME: C ORDINAL_POSITION: 1
-- COLUMN_NAME: D ORDINAL_POSITION: 2
-- COLUMN_NAME: B ORDINAL_POSITION: 3

-- # The column must exist, and can't be the only column.
CREATE TABLE t (a INT);
ALTER TABLE t DROP COLUMN b;
ALTER TABLE t DROP COLUMN a CASCADE;
ALTER TABLE t DROP CONSTRAINT;
-- msg: CREATE TABLE 1
-- error 42703: no such column: B
-- error 42601: syntax error: cannot drop the only column of ":memory:".PUBLIC.T
-- error 42601: syntax error: unexpected $end

-- # The constraints that only use the column are dropped with it: its NOT NULL,
-- # a CHECK, and a PRIMARY KEY or UNIQUE of only that column. The rows move
-- # (into the order they're read) when the PRIMARY KEY is dropped.
CREATE TABLE t (a INT PRIMARY KEY CHECK (a > 0), b INT NOT NULL UNIQUE CHECK (b < 10), c INT CHECK (c <> 0));
INSERT INTO t (a, b, c) VALUES (2, 1, 1), (1, 2, 2);
ALTER TABLE t DROP COLUMN a;
ALTER TABLE t DROP COLUMN b;
SELECT constraint_name, constraint_type FROM information_schema.table_constraints;
INSERT INTO t (c) VALUES (1);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- CONSTRAINT_NAME: T_CHECK_3 CONSTRAINT_TYPE: CHECK
-- msg: INSERT 1
-- C: 2
-- C: 1
-- C: 1

-- # A constraint that uses the column and other columns needs CASCADE, which
-- # drops it. The NOT NULL of the other columns of a PRIMARY KEY isn't dropped.
CREATE TABLE t (a INT, b INT, c INT, PRIMARY KEY (a, b), UNIQUE (b, c), CHECK (a < c));
ALTER TABLE t DROP COLUMN a;
ALTER TABLE t DROP COLUMN c;
ALTER TABLE t DROP COLUMN c CASCADE;
INSERT INTO t (a, b) VALUES (1, 1), (1, 1);
SELECT constraint_name, constraint_type FROM information_schema.table_constraints;
ALTER TABLE t DROP COLUMN b CASCADE;
SELECT constraint_name, constraint_type FROM information_schema.table_constraints;
-- msg: CREATE TABLE 1
-- error 2BP01: dependent objects still exist on constraint T_PRIMARY_KEY on ":memory:".PUBLIC.T
-- error 2BP01: dependent objects still exist on constraint T_UNIQUE_1 on ":memory:".PUBLIC.T
-- msg: ALTER TABLE 1
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T
-- CONSTRAINT_NAME: T_PRIMARY_KEY CONSTRAINT_TYPE: PRIMARY KEY
-- CONSTRAINT_NAME: T_NOT_NULL_1 CONSTRAINT_TYPE: CHECK
-- CONSTRAINT_NAME: T_NOT_NULL_2 CONSTRAINT_TYPE: CHECK
-- msg: ALTER TABLE 1
-- CONSTRAINT_NAME: T_NOT_NULL_1 CONSTRAINT_TYPE: CHECK

-- # A FOREIGN KEY uses the columns of both tables, so it needs CASCADE when
-- # either side is dropped, unless it only references the same column of the
-- # same table.
CREATE TABLE parent (id INT PRIMARY KEY, code INT UNIQUE, x INT);
CREATE TABLE child (parent_id INT REFERENCES parent, code INT REFERENCES parent (code), y INT);
CREATE TABLE self (a INT UNIQUE REFERENCES self (a), b INT);
ALTER TABLE parent DROP COLUMN id;
ALTER TABLE child DROP COLUMN code;
ALTER TABLE parent DROP COLUMN x;
ALTER TABLE parent DROP COLUMN id CASCADE;
ALTER TABLE child DROP COLUMN code CASCADE;
ALTER TABLE self DROP COLUMN a;
SELECT constraint_name, table_name, constraint_type FROM information_schema.table_constraints;
INSERT INTO child (parent_id, y) VALUES (123, 1);
SELECT * FROM child;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- error 2BP01: dependent objects still exist on constraint CHILD_FOREIGN_KEY_1 on ":memory:".PUBLIC.CHILD
-- error 2BP01: dependent objects still exist on constraint CHILD_FOREIGN_KEY_2 on ":memory:".PUBLIC.CHILD
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- CONSTRAINT_NAME: PARENT_UNIQUE_1 TABLE_NAME: PARENT CONSTRAINT_TYPE: UNIQUE
-- msg: INSERT 1
-- PARENT_ID: 123 Y: 1

-- # A column can be dropped in a transaction that's rolled back.
CREATE TABLE t (a INT, b INT);
INSERT INTO t (a, b) VALUES (1, 2);
START TRANSACTION;
ALTER TABLE t DROP COLUMN a;
SELECT * FROM t;
ROLLBACK;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: ALTER TABLE 1
-- B: 2
-- msg: ROLLBACK
-- A: 1 B: 2
