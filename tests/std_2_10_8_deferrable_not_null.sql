-- # A deferred NOT NULL allows a NULL until the transaction is committed, and
-- # the COMMIT fails if it's still there.
CREATE TABLE t (x INT, y INT NOT NULL DEFERRABLE INITIALLY DEFERRED);
START TRANSACTION;
INSERT INTO t (x, y) VALUES (1, NULL);
SELECT * FROM t;
UPDATE t SET y = 10;
COMMIT;
START TRANSACTION;
UPDATE t SET y = NULL;
COMMIT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- X: 1 Y: NULL
-- msg: UPDATE 1
-- msg: COMMIT
-- msg: START TRANSACTION
-- msg: UPDATE 1
-- error 40002: integrity constraint violation: violates non-null constraint: column Y
-- X: 1 Y: 10

-- # An immediate NOT NULL is checked straight away, until SET CONSTRAINTS
-- # defers it. A NOT NULL that isn't DEFERRABLE can't be deferred.
CREATE TABLE t (x INT CONSTRAINT nn NOT NULL DEFERRABLE, y INT CONSTRAINT nn2 NOT NULL);
INSERT INTO t (x, y) VALUES (NULL, 1);
UPDATE t SET x = NULL;
START TRANSACTION;
SET CONSTRAINTS nn2 DEFERRED;
SET CONSTRAINTS nn DEFERRED;
INSERT INTO t (x, y) VALUES (NULL, 1);
SET CONSTRAINTS nn IMMEDIATE;
UPDATE t SET x = 2;
SET CONSTRAINTS ALL IMMEDIATE;
COMMIT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- error 23502: violates non-null constraint: column X
-- warning 02000: no data
-- msg: UPDATE 0
-- msg: START TRANSACTION
-- error 42601: syntax error: constraint NN2 is not DEFERRABLE
-- msg: SET CONSTRAINTS
-- msg: INSERT 1
-- error 23502: violates non-null constraint: column X
-- msg: UPDATE 1
-- msg: SET CONSTRAINTS
-- msg: COMMIT
-- X: 2 Y: 1

-- # The column is nullable, but the NOT NULL is still in the information
-- # schema, with its characteristics, and is kept when the table is altered.
CREATE TABLE t (x INT NOT NULL DEFERRABLE INITIALLY DEFERRED, y INT NOT NULL);
ALTER TABLE t ADD COLUMN z INT;
SELECT column_name, is_nullable FROM information_schema.columns WHERE table_name = 'T';
SELECT constraint_name, is_deferrable, initially_deferred FROM information_schema.table_constraints;
SELECT * FROM information_schema.check_constraints;
-- msg: CREATE TABLE 1
-- msg: ALTER TABLE 1
-- COLUMN_NAME: X IS_NULLABLE: YES
-- COLUMN_NAME: Y IS_NULLABLE: NO
-- COLUMN_NAME: Z IS_NULLABLE: YES
-- CONSTRAINT_NAME: T_NOT_NULL_1 IS_DEFERRABLE: YES INITIALLY_DEFERRED: YES
-- CONSTRAINT_NAME: T_NOT_NULL_2 IS_DEFERRABLE: NO INITIALLY_DEFERRED: NO
-- CONSTRAINT_CATALOG: :memory: CONSTRAINT_SCHEMA: PUBLIC CONSTRAINT_NAME: T_NOT_NULL_1 CHECK_CLAUSE: X IS NOT NULL
-- CONSTRAINT_CATALOG: :memory: CONSTRAINT_SCHEMA: PUBLIC CONSTRAINT_NAME: T_NOT_NULL_2 CHECK_CLAUSE: Y IS NOT NULL

-- # A new column with a DEFERRABLE NOT NULL is checked against every row,
-- # unless it's deferred.
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
ALTER TABLE t ADD COLUMN y INT NOT NULL DEFERRABLE;
START TRANSACTION;
ALTER TABLE t ADD COLUMN y INT NOT NULL DEFERRABLE INITIALLY DEFERRED;
UPDATE t SET y = 2;
COMMIT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 23502: violates non-null constraint: column Y
-- msg: START TRANSACTION
-- msg: ALTER TABLE 1
-- msg: UPDATE 1
-- msg: COMMIT
-- X: 1 Y: 2

-- # ON DELETE SET NULL can set a column with a deferred NOT NULL to NULL.
CREATE TABLE p (id INT PRIMARY KEY);
CREATE TABLE c (p_id INT NOT NULL DEFERRABLE INITIALLY DEFERRED REFERENCES p ON DELETE SET NULL);
INSERT INTO p (id) VALUES (1), (2);
INSERT INTO c (p_id) VALUES (1);
START TRANSACTION;
DELETE FROM p WHERE id = 1;
SELECT * FROM c;
UPDATE c SET p_id = 2;
COMMIT;
SELECT * FROM c;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: DELETE 1
-- P_ID: NULL
-- msg: UPDATE 1
-- msg: COMMIT
-- P_ID: 2

-- # A DEFERRABLE NOT NULL can be dropped, or dropped with its column. A
-- # column of the PRIMARY KEY is NOT NULL anyway.
CREATE TABLE t (x INT NOT NULL DEFERRABLE PRIMARY KEY, y INT CONSTRAINT nn NOT NULL DEFERRABLE, z INT NOT NULL DEFERRABLE);
INSERT INTO t (x, y, z) VALUES (NULL, 1, 1);
/* extensions V105-02 */
ALTER TABLE t DROP CONSTRAINT nn;
ALTER TABLE t DROP COLUMN z CASCADE;
INSERT INTO t (x, y) VALUES (1, NULL);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- error 23502: violates non-null constraint: column X
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: INSERT 1
-- X: 1 Y: NULL

-- # A DEFERRABLE NOT NULL needs F721.
/* flags */
CREATE TABLE t (x INT NOT NULL DEFERRABLE);
-- flags: F721
-- msg: CREATE TABLE 1
