-- # REPEATABLE READ and SERIALIZABLE transactions stop other connections from
-- # committing until they end, so a row that has been read can't change. A
-- # statement on its own is a SERIALIZABLE transaction too, so it waits for
-- # the transaction to end. The tests don't wait (the timeout is 0), so it fails
-- # straight away.
/* connection 1 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT * FROM t;
/* connection 2 */
UPDATE t SET x = 2;
DELETE FROM t;
SELECT * FROM t;
/* connection 1 */
SELECT * FROM t;
COMMIT;
/* connection 2 */
UPDATE t SET x = 2;
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: X: 1
-- 2: error 40001: serialization failure: another connection has a transaction that must finish first
-- 2: error 40001: serialization failure: another connection has a transaction that must finish first
-- 2: X: 1
-- 1: X: 1
-- 1: msg: COMMIT
-- 2: msg: UPDATE 1
-- 2: X: 2

/* connection 1 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT * FROM t;
/* connection 2 */
UPDATE t SET x = 2;
/* connection 1 */
SELECT * FROM t;
COMMIT;
/* connection 2 */
UPDATE t SET x = 2;
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: X: 1
-- 2: error 40001: serialization failure: another connection has a transaction that must finish first
-- 1: X: 1
-- 1: msg: COMMIT
-- 2: msg: UPDATE 1
-- 2: X: 2

-- # SERIALIZABLE is the default.
/* connection 1 */
CREATE TABLE t (x INT);
START TRANSACTION;
/* connection 2 */
INSERT INTO t (x) VALUES (1);
/* connection 1 */
COMMIT;
/* connection 2 */
INSERT INTO t (x) VALUES (1);
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 2: error 40001: serialization failure: another connection has a transaction that must finish first
-- 1: msg: COMMIT
-- 2: msg: INSERT 1

-- # Phantoms (new rows) can't appear either.
/* connection 1 */
CREATE TABLE t (x INT);
START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT COUNT(*) FROM t;
/* connection 2 */
INSERT INTO t (x) VALUES (1);
/* connection 1 */
SELECT COUNT(*) FROM t;
ROLLBACK;
/* connection 2 */
INSERT INTO t (x) VALUES (1);
SELECT COUNT(*) FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 1: COL1: 0
-- 2: error 40001: serialization failure: another connection has a transaction that must finish first
-- 1: COL1: 0
-- 1: msg: ROLLBACK
-- 2: msg: INSERT 1
-- 2: COL1: 1

-- # The lock is held from START TRANSACTION, before anything is read, and
-- # changes to the schema have to wait too.
/* connection 1 */
CREATE TABLE t (x INT);
CREATE SEQUENCE seq;
START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
/* connection 2 */
INSERT INTO t (x) VALUES (1);
CREATE TABLE t2 (x INT);
DROP TABLE t;
CREATE SCHEMA s;
CREATE SEQUENCE seq2;
ALTER SEQUENCE seq RESTART WITH 10;
DROP SEQUENCE seq;
/* connection 1 */
COMMIT;
/* connection 2 */
CREATE TABLE t2 (x INT);
-- 1: msg: CREATE TABLE 1
-- 1: msg: CREATE SEQUENCE 1
-- 1: msg: START TRANSACTION
-- 2: error 40001: serialization failure: another connection has a transaction that must finish first
-- 2: error 40001: serialization failure: another connection has a transaction that must finish first
-- 2: error 40001: serialization failure: another connection has a transaction that must finish first
-- 2: error 40001: serialization failure: another connection has a transaction that must finish first
-- 2: error 40001: serialization failure: another connection has a transaction that must finish first
-- 2: error 40001: serialization failure: another connection has a transaction that must finish first
-- 2: error 40001: serialization failure: another connection has a transaction that must finish first
-- 1: msg: COMMIT
-- 2: msg: CREATE TABLE 1

-- # Other connections can still read. NEXT VALUE FOR isn't part of a
-- # transaction, so it doesn't wait. A READ COMMITTED statement that doesn't
-- # change anything doesn't need to commit, but a SERIALIZABLE one waits before
-- # it knows that.
/* connection 1 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
CREATE SEQUENCE seq;
START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
/* connection 2 */
SELECT * FROM t;
VALUES NEXT VALUE FOR seq;
UPDATE t SET x = 2 WHERE x = 3;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
UPDATE t SET x = 2 WHERE x = 3;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
DELETE FROM t WHERE x = 3;
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT * FROM t;
COMMIT;
/* connection 1 */
VALUES NEXT VALUE FOR seq;
COMMIT;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: CREATE SEQUENCE 1
-- 1: msg: START TRANSACTION
-- 2: X: 1
-- 2: COL1: 1
-- 2: error 40001: serialization failure: another connection has a transaction that must finish first
-- 2: msg: SET TRANSACTION
-- warning 02000: no data
-- 2: msg: UPDATE 0
-- 2: msg: SET TRANSACTION
-- warning 02000: no data
-- 2: msg: DELETE 0
-- 2: msg: START TRANSACTION
-- 2: X: 1
-- 2: msg: COMMIT
-- 1: COL1: 2
-- 1: msg: COMMIT

-- # A READ COMMITTED transaction doesn't wait. It can change the database, but
-- # it can't commit, which rolls it back. The same goes for a READ COMMITTED
-- # statement on its own.
/* connection 1 */
CREATE TABLE t (x INT);
START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
/* connection 2 */
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
INSERT INTO t (x) VALUES (1);
SELECT * FROM t;
COMMIT;
COMMIT;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
INSERT INTO t (x) VALUES (2);
SELECT * FROM t;
/* connection 1 */
SELECT * FROM t;
COMMIT;
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 2: msg: START TRANSACTION
-- 2: msg: INSERT 1
-- 2: X: 1
-- 2: error 40001: serialization failure: cannot commit while another connection has a REPEATABLE READ or SERIALIZABLE transaction
-- 2: error 2D000: invalid transaction termination
-- 2: msg: SET TRANSACTION
-- 2: error 40001: serialization failure: cannot commit while another connection has a REPEATABLE READ or SERIALIZABLE transaction
-- 1: msg: COMMIT

-- # A READ COMMITTED transaction that started first, and changed a row, can't
-- # commit until the SERIALIZABLE transaction ends. The SERIALIZABLE transaction
-- # doesn't see the change, and can't change the same row.
/* connection 1 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
UPDATE t SET x = 2;
/* connection 2 */
START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT * FROM t;
/* connection 1 */
COMMIT;
/* connection 2 */
UPDATE t SET x = 3;
COMMIT;
/* connection 1 */
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
UPDATE t SET x = 2;
COMMIT;
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: msg: UPDATE 1
-- 2: msg: START TRANSACTION
-- 2: X: 1
-- 1: error 40001: serialization failure: cannot commit while another connection has a REPEATABLE READ or SERIALIZABLE transaction
-- 2: msg: UPDATE 1
-- 2: msg: COMMIT
-- 1: msg: START TRANSACTION
-- 1: msg: UPDATE 1
-- 1: msg: COMMIT
-- 1: X: 2

/* connection 1 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
UPDATE t SET x = 2;
/* connection 2 */
START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
UPDATE t SET x = 3;
SELECT * FROM t;
/* connection 1 */
COMMIT;
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: msg: UPDATE 1
-- 2: msg: START TRANSACTION
-- 2: error 40001: serialization failure: avoiding concurrent write on individual row
-- 2: X: 1
-- 1: msg: COMMIT
-- 1: X: 2

-- # A SERIALIZABLE transaction can commit its own changes.
/* connection 1 */
CREATE TABLE t (x INT);
START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
INSERT INTO t (x) VALUES (1);
/* connection 2 */
SELECT * FROM t;
INSERT INTO t (x) VALUES (2);
/* connection 1 */
INSERT INTO t (x) VALUES (3);
UPDATE t SET x = x * 10;
COMMIT;
/* connection 2 */
SELECT * FROM t;
INSERT INTO t (x) VALUES (2);
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 1: msg: INSERT 1
-- 2: error 40001: serialization failure: another connection has a transaction that must finish first
-- 1: msg: INSERT 1
-- 1: msg: UPDATE 2
-- 1: msg: COMMIT
-- 2: X: 10
-- 2: X: 30
-- 2: msg: INSERT 1
-- 2: X: 10
-- 2: X: 30
-- 2: X: 2

-- # A statement that fails in the transaction doesn't release the lock.
/* connection 1 */
CREATE TABLE t (x INT);
START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT * FROM missing;
INSERT INTO missing (x) VALUES (1);
INSERT INTO t (x) VALUES ('a');
/* connection 2 */
INSERT INTO t (x) VALUES (1);
/* connection 1 */
ROLLBACK;
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 1: error 42P01: no such table: "test".PUBLIC.MISSING
-- 1: error 42P01: no such table: "test".PUBLIC.MISSING
-- 1: error 42846: cannot coerce CHARACTER(1) to INTEGER
-- 2: error 40001: serialization failure: another connection has a transaction that must finish first
-- 1: msg: ROLLBACK

-- # Only one REPEATABLE READ or SERIALIZABLE transaction can be active at a
-- # time.
/* connection 1 */
CREATE TABLE t (x INT);
START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
INSERT INTO t (x) VALUES (1);
/* connection 2 */
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
COMMIT;
/* connection 1 */
COMMIT;
/* connection 2 */
START TRANSACTION;
INSERT INTO t (x) VALUES (2);
COMMIT;
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 1: msg: INSERT 1
-- 2: error 40001: serialization failure: another connection has a transaction that must finish first
-- 2: error 2D000: invalid transaction termination
-- 1: msg: COMMIT
-- 2: msg: START TRANSACTION
-- 2: msg: INSERT 1
-- 2: msg: COMMIT
-- 2: X: 1
-- 2: X: 2

-- # A write skew: each transaction reads the row that the other one changes.
-- # The second one can only start after the first one ends, so the result is
-- # the same as running them one after the other.
/* connection 1 */
CREATE TABLE doctors (name VARCHAR(10), on_call BOOLEAN);
INSERT INTO doctors (name, on_call) VALUES ('alice', TRUE);
INSERT INTO doctors (name, on_call) VALUES ('bob', TRUE);
START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT COUNT(*) FROM doctors WHERE on_call;
/* connection 2 */
START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
/* connection 1 */
UPDATE doctors SET on_call = FALSE WHERE name = 'alice';
COMMIT;
/* connection 2 */
START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT COUNT(*) FROM doctors WHERE on_call;
COMMIT;
SELECT * FROM doctors;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: COL1: 2
-- 2: error 40001: serialization failure: another connection has a transaction that must finish first
-- 1: msg: UPDATE 1
-- 1: msg: COMMIT
-- 2: msg: START TRANSACTION
-- 2: COL1: 1
-- 2: msg: COMMIT
-- 2: NAME: alice ON_CALL: FALSE
-- 2: NAME: bob ON_CALL: TRUE

-- # The lock is released by ROLLBACK, and when the connection is closed
-- # without ending the transaction (like a process that stopped).
/* connection 1 */
CREATE TABLE t (x INT);
START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
/* connection 2 */
INSERT INTO t (x) VALUES (1);
/* connection 1 */
ROLLBACK;
/* connection 2 */
INSERT INTO t (x) VALUES (1);
/* connection 1 */
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
/* connection 2 */
INSERT INTO t (x) VALUES (2);
/* disconnect 1 */
/* connection 2 */
INSERT INTO t (x) VALUES (2);
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 2: error 40001: serialization failure: another connection has a transaction that must finish first
-- 1: msg: ROLLBACK
-- 2: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 2: error 40001: serialization failure: another connection has a transaction that must finish first
-- 2: msg: INSERT 1
-- 2: X: 1
-- 2: X: 2

-- # READ COMMITTED and READ UNCOMMITTED don't stop other connections from
-- # committing, so a row can change between reads. But a change that hasn't
-- # been committed is never visible (a dirty read), since READ UNCOMMITTED runs
-- # as READ COMMITTED.
/* connection 1 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT * FROM t;
/* connection 2 */
UPDATE t SET x = 2;
/* connection 1 */
SELECT * FROM t;
COMMIT;
START TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT * FROM t;
/* connection 2 */
UPDATE t SET x = 3;
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
UPDATE t SET x = 4;
/* connection 1 */
SELECT * FROM t;
COMMIT;
/* connection 2 */
COMMIT;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: X: 1
-- 2: msg: UPDATE 1
-- 1: X: 2
-- 1: msg: COMMIT
-- 1: msg: START TRANSACTION
-- 1: X: 2
-- 2: msg: UPDATE 1
-- 2: msg: START TRANSACTION
-- 2: msg: UPDATE 1
-- 1: X: 3
-- 1: msg: COMMIT
-- 2: msg: COMMIT

-- # SET TRANSACTION ISOLATION LEVEL SERIALIZABLE for a statement on its own
-- # doesn't stop other connections from committing afterwards.
/* connection 1 */
CREATE TABLE t (x INT);
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
INSERT INTO t (x) VALUES (1);
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT * FROM t;
/* connection 2 */
INSERT INTO t (x) VALUES (2);
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: SET TRANSACTION
-- 1: msg: INSERT 1
-- 1: msg: SET TRANSACTION
-- 1: X: 1
-- 2: msg: INSERT 1
-- 2: X: 1
-- 2: X: 2

-- # SET TRANSACTION applies to START TRANSACTION.
/* connection 1 */
CREATE TABLE t (x INT);
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION;
/* connection 2 */
INSERT INTO t (x) VALUES (1);
/* connection 1 */
COMMIT;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;
/* connection 2 */
INSERT INTO t (x) VALUES (1);
/* connection 1 */
COMMIT;
-- 1: msg: CREATE TABLE 1
-- 1: msg: SET TRANSACTION
-- 1: msg: START TRANSACTION
-- 2: error 40001: serialization failure: another connection has a transaction that must finish first
-- 1: msg: COMMIT
-- 1: msg: SET TRANSACTION
-- 1: msg: START TRANSACTION
-- 2: msg: INSERT 1
-- 1: msg: COMMIT

-- # A COMMIT that fails for another reason doesn't end the transaction, so it
-- # keeps the lock.
/* connection 1 */
CREATE TABLE t (x INT);
START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
INSERT INTO t (x) VALUES (1);
/* fault wal_write */
COMMIT;
/* connection 2 */
INSERT INTO t (x) VALUES (2);
/* connection 1 */
COMMIT;
/* connection 2 */
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 1: msg: INSERT 1
-- 1: error 58030: wal_write failed (fault injected by test)
-- 2: error 40001: serialization failure: another connection has a transaction that must finish first
-- 1: msg: COMMIT
-- 2: X: 1

-- # The isolation file can't be locked.
/* connection 1 */
CREATE TABLE t (x INT);
/* fault isolation_lock */
START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
/* fault isolation_lock */
INSERT INTO t (x) VALUES (1);
INSERT INTO t (x) VALUES (2);
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
INSERT INTO t (x) VALUES (3);
/* fault isolation_lock */
COMMIT;
COMMIT;
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: error 58030: isolation_lock failed (fault injected by test)
-- 1: error 58030: isolation_lock failed (fault injected by test)
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: msg: INSERT 1
-- 1: error 58030: isolation_lock failed (fault injected by test)
-- 1: msg: COMMIT
-- 1: X: 2
-- 1: X: 3
