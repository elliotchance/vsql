-- # A deferred PRIMARY KEY can have duplicates until the transaction is
-- # committed (General Rules, 3), and the COMMIT fails if they're still there.
CREATE TABLE t (x INT PRIMARY KEY DEFERRABLE INITIALLY DEFERRED, y INT);
INSERT INTO t (x, y) VALUES (1, 10);
START TRANSACTION;
INSERT INTO t (x, y) VALUES (1, 20);
SELECT * FROM t;
UPDATE t SET x = 2 WHERE y = 20;
COMMIT;
START TRANSACTION;
INSERT INTO t (x, y) VALUES (2, 30);
COMMIT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- X: 1 Y: 10
-- X: 1 Y: 20
-- msg: UPDATE 1
-- msg: COMMIT
-- msg: START TRANSACTION
-- msg: INSERT 1
-- error 40002: integrity constraint violation: violates unique constraint: PRIMARY KEY (X) on ":memory:".PUBLIC.T
-- X: 1 Y: 10
-- X: 2 Y: 20

-- # An immediate PRIMARY KEY is checked at the end of each statement, until
-- # SET CONSTRAINTS defers it. The rows are stored by row ID, so they're in the
-- # order they were inserted rather than in the order of the key.
CREATE TABLE t (x INT CONSTRAINT pk PRIMARY KEY DEFERRABLE);
INSERT INTO t (x) VALUES (3), (1), (2);
INSERT INTO t (x) VALUES (1);
UPDATE t SET x = 4 - x;
START TRANSACTION;
SET CONSTRAINTS pk DEFERRED;
INSERT INTO t (x) VALUES (1);
SET CONSTRAINTS pk IMMEDIATE;
DELETE FROM t WHERE x = 1;
SET CONSTRAINTS pk IMMEDIATE;
COMMIT;
SELECT * FROM t;
SELECT * FROM t WHERE x = 3;
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- error 23505: violates unique constraint: PRIMARY KEY (X) on ":memory:".PUBLIC.T
-- msg: UPDATE 3
-- msg: START TRANSACTION
-- msg: SET CONSTRAINTS
-- msg: INSERT 1
-- error 23505: violates unique constraint: PRIMARY KEY (X) on ":memory:".PUBLIC.T
-- msg: DELETE 2
-- msg: SET CONSTRAINTS
-- msg: COMMIT
-- X: 3
-- X: 2
-- X: 3

-- # SET CONSTRAINTS ALL includes a DEFERRABLE PRIMARY KEY.
CREATE TABLE t (x INT PRIMARY KEY DEFERRABLE);
START TRANSACTION;
SET CONSTRAINTS ALL DEFERRED;
INSERT INTO t (x) VALUES (1), (1);
COMMIT;
SELECT COUNT(*) FROM t;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: SET CONSTRAINTS
-- msg: INSERT 2
-- error 40002: integrity constraint violation: violates unique constraint: PRIMARY KEY (X) on ":memory:".PUBLIC.T
-- COL1: 0

-- # The columns of a DEFERRABLE PRIMARY KEY are still NOT NULL, and checked
-- # straight away (Syntax Rules, 8).
CREATE TABLE t (x INT, y INT, PRIMARY KEY (x, y) DEFERRABLE INITIALLY DEFERRED);
START TRANSACTION;
INSERT INTO t (x, y) VALUES (1, NULL);
ROLLBACK;
SELECT column_name, is_nullable FROM information_schema.columns WHERE table_name = 'T';
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- error 23502: violates non-null constraint: column Y
-- msg: ROLLBACK
-- COLUMN_NAME: X IS_NULLABLE: NO
-- COLUMN_NAME: Y IS_NULLABLE: NO

-- # The characteristics are kept with the definition of the table, even when
-- # it's altered, and are in TABLE_CONSTRAINTS.
CREATE TABLE t (x INT PRIMARY KEY DEFERRABLE INITIALLY DEFERRED);
ALTER TABLE t ADD COLUMN y INT UNIQUE;
SELECT constraint_name, constraint_type, is_deferrable, initially_deferred FROM information_schema.table_constraints;
-- msg: CREATE TABLE 1
-- msg: ALTER TABLE 1
-- CONSTRAINT_NAME: T_PRIMARY_KEY CONSTRAINT_TYPE: PRIMARY KEY IS_DEFERRABLE: YES INITIALLY_DEFERRED: YES
-- CONSTRAINT_NAME: T_UNIQUE_1 CONSTRAINT_TYPE: UNIQUE IS_DEFERRABLE: NO INITIALLY_DEFERRED: NO
-- CONSTRAINT_NAME: T_NOT_NULL_1 CONSTRAINT_TYPE: CHECK IS_DEFERRABLE: NO INITIALLY_DEFERRED: NO

-- # A DEFERRABLE PRIMARY KEY can be added to a table, which is an error if
-- # it already has duplicates, and dropped. Dropping one of its columns drops
-- # it too.
CREATE TABLE t (x INT NOT NULL, y INT);
INSERT INTO t (x, y) VALUES (1, 1), (1, 2);
ALTER TABLE t ADD CONSTRAINT pk PRIMARY KEY (x) DEFERRABLE;
ALTER TABLE t ADD CONSTRAINT pk PRIMARY KEY (y) DEFERRABLE;
INSERT INTO t (x, y) VALUES (2, 2);
/* extensions V105-02 */
ALTER TABLE t DROP CONSTRAINT pk;
INSERT INTO t (x, y) VALUES (2, 2), (2, 2);
ALTER TABLE t ADD CONSTRAINT pk2 PRIMARY KEY (x, y) DEFERRABLE;
DELETE FROM t WHERE x = 2;
ALTER TABLE t ADD CONSTRAINT pk2 PRIMARY KEY (x, y) DEFERRABLE;
ALTER TABLE t DROP COLUMN y CASCADE;
INSERT INTO t (x) VALUES (1);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- error 23505: violates unique constraint: PRIMARY KEY (X) on ":memory:".PUBLIC.T
-- msg: ALTER TABLE 1
-- error 23505: violates unique constraint: PRIMARY KEY (Y) on ":memory:".PUBLIC.T
-- msg: ALTER TABLE 1
-- msg: INSERT 2
-- error 23505: violates unique constraint: PRIMARY KEY (X, Y) on ":memory:".PUBLIC.T
-- msg: DELETE 2
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: INSERT 1
-- X: 1
-- X: 1
-- X: 1

-- # A FOREIGN KEY can't reference a DEFERRABLE PRIMARY KEY (11.8, Syntax
-- # Rules, 5).
CREATE TABLE p (id INT PRIMARY KEY DEFERRABLE);
CREATE TABLE c (id INT REFERENCES p);
-- msg: CREATE TABLE 1
-- error 42830: invalid foreign key: FOREIGN KEY cannot reference a DEFERRABLE constraint: P_PRIMARY_KEY

-- # A DEFERRABLE PRIMARY KEY needs F721.
/* flags */
CREATE TABLE t (x INT PRIMARY KEY DEFERRABLE);
-- flags: F721
-- msg: CREATE TABLE 1
