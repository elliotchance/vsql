-- # A COMMIT that fails with an I/O error (rather than a serialization failure
-- # or a constraint violation) rolls back the SQL-transaction (General Rules,
-- # 6.b), so there's nothing left to commit. These tests only run on disk, see
-- # "Faults" in docs/testing.rst.
CREATE TABLE t (x INT);
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
/* fault lock */
COMMIT;
SELECT * FROM t;
COMMIT;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- error 40V01: transaction rollback: lock failed (fault injected by test)
-- msg: COMMIT

CREATE TABLE t (x INT);
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
/* fault wal_write */
COMMIT;
SELECT * FROM t;
COMMIT;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- error 40V01: transaction rollback: wal_write failed (fault injected by test)
-- msg: COMMIT

CREATE TABLE t (x INT);
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
/* fault read_page */
COMMIT;
SELECT * FROM t;
COMMIT;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- error 40V01: transaction rollback: read_page failed (fault injected by test)
-- msg: COMMIT

CREATE TABLE t (x INT);
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
/* fault isolation_end */
COMMIT;
SELECT * FROM t;
COMMIT;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- error 40V01: transaction rollback: isolation_end failed (fault injected by test)
-- msg: COMMIT

-- # Changes to the schema are canceled too, and the connection can carry on.
START TRANSACTION;
CREATE TABLE t (x INT);
/* fault wal_write */
COMMIT;
SELECT * FROM t;
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (2);
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: CREATE TABLE 1
-- error 40V01: transaction rollback: wal_write failed (fault injected by test)
-- error 42P01: no such table: ":memory:".PUBLIC.T
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- X: 2

-- # If the rollback can't be done either, the SQL-transaction is still active
-- # and the error isn't a transaction rollback. So it can be committed again.
CREATE TABLE t (x INT);
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
/* fault read_page */
/* fault wal_write */
COMMIT;
SELECT * FROM t;
COMMIT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- error 58030: transaction rollback: read_page failed (fault injected by test), but the transaction is still active because it could not be rolled back: wal_write failed (fault injected by test)
-- X: 1
-- msg: COMMIT
-- X: 1

CREATE TABLE t (x INT);
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
/* fault read_page */
/* fault lock 2 */
COMMIT;
SELECT * FROM t;
COMMIT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- error 58030: transaction rollback: read_page failed (fault injected by test), but the transaction is still active because it could not be rolled back: lock failed (fault injected by test)
-- X: 1
-- msg: COMMIT
-- X: 1

-- # A COMMIT that is only explained doesn't end the SQL-transaction.
CREATE TABLE t (x INT);
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
EXPLAIN COMMIT;
SELECT * FROM t;
COMMIT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- error 42601: syntax error: Cannot EXPLAIN COMMIT
-- X: 1
-- msg: COMMIT
-- X: 1
