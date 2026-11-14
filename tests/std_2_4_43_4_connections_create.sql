-- # A table that another transaction is creating isn't visible yet, but it may
-- # exist once that transaction commits, so creating a table with the same
-- # name is a serialization failure (40001) rather than a duplicate table. It
-- # can only happen with READ COMMITTED, since only one SERIALIZABLE
-- # transaction can change the database at a time. The failure rolls back
-- # the transaction.
/* connection 1 */
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
CREATE TABLE t (x INT);
/* connection 2 */
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
CREATE TABLE t (y INT);
COMMIT;
/* connection 1 */
COMMIT;
/* connection 2 */
CREATE TABLE t (y INT);
SELECT table_name, column_name FROM information_schema.columns WHERE table_name = 'T';
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE TABLE 1
-- 2: msg: START TRANSACTION
-- 2: error 40001: serialization failure: avoiding concurrent write on table "test".PUBLIC.T
-- 2: msg: COMMIT
-- 1: msg: COMMIT
-- 2: error 42P07: duplicate table: "test".PUBLIC.T
-- 2: TABLE_NAME: T COLUMN_NAME: X

-- # The same for a statement on its own, or a SERIALIZABLE transaction that
-- # starts while the READ COMMITTED transaction is active, which would
-- # otherwise be able to commit first.
/* connection 1 */
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
CREATE TABLE t (x INT);
/* connection 2 */
CREATE TABLE t (y INT);
START TRANSACTION;
CREATE TABLE t (y INT);
/* connection 1 */
COMMIT;
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE TABLE 1
-- 2: error 40001: serialization failure: avoiding concurrent write on table "test".PUBLIC.T
-- 2: msg: START TRANSACTION
-- 2: error 40001: serialization failure: avoiding concurrent write on table "test".PUBLIC.T
-- 1: msg: COMMIT

-- # CREATE TABLE IF NOT EXISTS can't tell whether the table will exist either.
/* extensions V103-01 */
/* connection 1 */
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
CREATE TABLE t (x INT);
/* connection 2 */
CREATE TABLE IF NOT EXISTS t (y INT);
/* connection 1 */
COMMIT;
/* connection 2 */
CREATE TABLE IF NOT EXISTS t (y INT);
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE TABLE 1
-- 2: error 40001: serialization failure: avoiding concurrent write on table "test".PUBLIC.T
-- 1: msg: COMMIT
-- 2: msg: CREATE TABLE 0

-- # A table in another schema, or with another name, can be created.
/* connection 1 */
CREATE SCHEMA s;
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
CREATE TABLE t (x INT);
/* connection 2 */
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
CREATE TABLE s.t (y INT);
CREATE TABLE t2 (y INT);
COMMIT;
/* connection 1 */
COMMIT;
-- 1: msg: CREATE SCHEMA 1
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE TABLE 1
-- 2: msg: START TRANSACTION
-- 2: msg: CREATE TABLE 1
-- 2: msg: CREATE TABLE 1
-- 2: msg: COMMIT
-- 1: msg: COMMIT

-- # A table that another transaction is dropping is still visible, so it's a
-- # duplicate table. Once the drop is committed, the name can be used again.
/* connection 1 */
CREATE TABLE t (x INT);
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
DROP TABLE t RESTRICT;
/* connection 2 */
CREATE TABLE t (y INT);
/* connection 1 */
COMMIT;
/* connection 2 */
CREATE TABLE t (y INT);
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 1: msg: DROP TABLE 1
-- 2: error 42P07: duplicate table: "test".PUBLIC.T
-- 1: msg: COMMIT
-- 2: msg: CREATE TABLE 1

-- # The same for an index, including the index of a constraint.
/* extensions V002-01 */
/* connection 1 */
CREATE TABLE t1 (x INT);
CREATE TABLE t2 (x INT);
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
CREATE INDEX i ON t1 (x);
/* connection 2 */
CREATE INDEX i ON t2 (x);
CREATE INDEX i2 ON t2 (x);
CREATE TABLE t3 (x INT CONSTRAINT i UNIQUE);
/* connection 1 */
COMMIT;
-- 1: msg: CREATE TABLE 1
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE INDEX 1
-- 2: error 40001: serialization failure: avoiding concurrent write on index "test".PUBLIC.I
-- 2: msg: CREATE INDEX 1
-- 2: error 40001: serialization failure: avoiding concurrent write on index "test".PUBLIC.I
-- 1: msg: COMMIT

-- # The same for a schema.
/* connection 1 */
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
CREATE SCHEMA s;
/* connection 2 */
CREATE SCHEMA s;
/* connection 1 */
COMMIT;
/* connection 2 */
CREATE SCHEMA s;
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE SCHEMA 1
-- 2: error 40001: serialization failure: avoiding concurrent write on schema S
-- 1: msg: COMMIT
-- 2: error 42P06: duplicate schema: S

-- # The same for a sequence.
/* connection 1 */
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
CREATE SEQUENCE seq;
/* connection 2 */
CREATE SEQUENCE seq;
/* connection 1 */
COMMIT;
/* connection 2 */
CREATE SEQUENCE seq;
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE SEQUENCE 1
-- 2: error 40001: serialization failure: avoiding concurrent write on sequence "test".PUBLIC.SEQ
-- 1: msg: COMMIT
-- 2: error 42P07: duplicate sequence: "test".PUBLIC.SEQ
