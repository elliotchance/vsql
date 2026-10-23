-- # A fault directive makes an operation fail the next time it's reached, so
-- # that errors such as a failed write can be tested. These tests only run on
-- # disk. See "Faults" in docs/testing.rst.
-- #
-- # A statement that fails before it's committed to the write-ahead log has no
-- # effect, and the next statement still works.
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
/* fault wal_write */
INSERT INTO t (x) VALUES (2);
SELECT * FROM t;
INSERT INTO t (x) VALUES (3);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 58030: wal_write failed (fault injected by test)
-- X: 1
-- msg: INSERT 1
-- X: 1
-- X: 3

-- # A statement that is committed to the write-ahead log is copied into the
-- # file by the next statement if it couldn't be copied before. It doesn't fail,
-- # since it was committed.
CREATE TABLE t (x INT);
/* fault checkpoint */
INSERT INTO t (x) VALUES (1);
SELECT * FROM t;
INSERT INTO t (x) VALUES (2);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- X: 1
-- msg: INSERT 1
-- X: 1
-- X: 2

-- # A statement that can't lock the file has no effect.
CREATE TABLE t (x INT);
/* fault lock */
INSERT INTO t (x) VALUES (1);
SELECT * FROM t;
INSERT INTO t (x) VALUES (2);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- error 58030: lock failed (fault injected by test)
-- msg: INSERT 1
-- X: 2

-- # If a transaction can't be started, the statements after it are not in a
-- # transaction.
/* fault lock */
START TRANSACTION;
CREATE TABLE t (x INT);
COMMIT;
-- error 58030: lock failed (fault injected by test)
-- msg: CREATE TABLE 1
-- error 2D000: invalid transaction termination

-- # Opening, locking or reading the file can fail for reads and writes. The
-- # next statement opens the file again.
CREATE TABLE t (x INT);
/* fault open */
SELECT * FROM t;
/* fault open */
INSERT INTO t (x) VALUES (1);
/* fault lock_shared */
SELECT * FROM t;
/* fault read_header */
SELECT * FROM t;
/* fault read_header */
INSERT INTO t (x) VALUES (2);
INSERT INTO t (x) VALUES (3);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- error 58030: open failed (fault injected by test)
-- error 58030: open failed (fault injected by test)
-- error 58030: lock_shared failed (fault injected by test)
-- error 58030: read_header failed (fault injected by test)
-- error 58030: read_header failed (fault injected by test)
-- msg: INSERT 1
-- X: 3

-- # A statement left in the write-ahead log is copied into the file before it's
-- # read. If that fails, the next statement tries again. A fault with a number
-- # fails the nth time it's reached, so "lock_shared 2" is the shared lock after
-- # recovering.
CREATE TABLE t (x INT);
/* fault checkpoint */
INSERT INTO t (x) VALUES (1);
/* fault recover */
SELECT * FROM t;
/* fault lock */
SELECT * FROM t;
/* fault lock_shared 2 */
SELECT * FROM t;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 58030: recover failed (fault injected by test)
-- error 58030: lock failed (fault injected by test)
-- error 58030: lock_shared failed (fault injected by test)
-- X: 1

-- # The same for a statement that writes.
CREATE TABLE t (x INT);
/* fault checkpoint */
INSERT INTO t (x) VALUES (1);
/* fault recover */
INSERT INTO t (x) VALUES (2);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 58030: recover failed (fault injected by test)
-- X: 1

-- # A file that needs a newer version of vsql to be changed can only be read.
CREATE TABLE t (x INT);
/* fault write_version */
INSERT INTO t (x) VALUES (1);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- error 25006: read-only sql transaction: database needs file format 1 to be changed, but this version of vsql only supports up to 1

-- # A commit frame that wasn't completely written, or is corrupt, isn't
-- # recovered, so the statement has no effect.
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
/* fault wal_torn_frame */
INSERT INTO t (x) VALUES (2);
SELECT * FROM t;
/* fault wal_corrupt_frame */
INSERT INTO t (x) VALUES (3);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 58030: wal_torn_frame failed (fault injected by test)
-- X: 1
-- error 58030: wal_corrupt_frame failed (fault injected by test)
-- X: 1

-- # A write-ahead log that is corrupt is ignored when it's recovered, so the
-- # statement has no effect.
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
/* fault wal_bad_magic */
INSERT INTO t (x) VALUES (2);
SELECT * FROM t;
/* fault wal_bad_header */
INSERT INTO t (x) VALUES (3);
SELECT * FROM t;
/* fault wal_unknown_frame */
INSERT INTO t (x) VALUES (4);
SELECT * FROM t;
INSERT INTO t (x) VALUES (5);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 58030: wal_bad_magic failed (fault injected by test)
-- X: 1
-- error 58030: wal_bad_header failed (fault injected by test)
-- X: 1
-- error 58030: wal_unknown_frame failed (fault injected by test)
-- X: 1
-- msg: INSERT 1
-- X: 1
-- X: 5

-- # A serialization failure rolls back the transaction. If the rollback fails
-- # (the second lock is for the rollback), the transaction stays open, so the
-- # error says so instead of being a 40001, and a COMMIT commits its INSERT.
/* connection 1 */
CREATE TABLE foo (bar INT);
INSERT INTO foo (bar) VALUES (123);
START TRANSACTION;
UPDATE foo SET bar = 456;
/* connection 2 */
START TRANSACTION;
INSERT INTO foo (bar) VALUES (999);
/* fault lock 2 */
UPDATE foo SET bar = 789;
COMMIT;
SELECT * FROM foo;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: msg: UPDATE 1
-- 2: msg: START TRANSACTION
-- 2: msg: INSERT 1
-- 2: error 58030: serialization failure: avoiding concurrent write on individual row, but the transaction is still active because it could not be rolled back: lock failed (fault injected by test)
-- 2: msg: COMMIT
-- 2: BAR: 123
-- 2: BAR: 999

-- # The values given by a sequence are kept when a statement fails. If that
-- # can't be written either, the original error is returned and the value is
-- # given out again, since nothing used it.
CREATE TABLE t (x INT, y INT NOT NULL);
CREATE SEQUENCE s;
/* fault wal_write */
INSERT INTO t (x, y) VALUES (NEXT VALUE FOR s, NULL);
VALUES NEXT VALUE FOR s;
-- msg: CREATE TABLE 1
-- msg: CREATE SEQUENCE 1
-- error 23502: violates non-null constraint: column Y
-- COL1: 1

-- # A transaction left by a connection that stopped (without a ROLLBACK) is
-- # rolled back by the next connection that writes. Its rows can't be seen
-- # before then.
/* connection 1 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
INSERT INTO t (x) VALUES (2);
START TRANSACTION;
UPDATE t SET x = 10 WHERE x = 1;
DELETE FROM t WHERE x = 2;
INSERT INTO t (x) VALUES (3);
/* disconnect 1 */
/* connection 2 */
SELECT * FROM t;
INSERT INTO t (x) VALUES (4);
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: msg: UPDATE 1
-- 1: msg: DELETE 1
-- 1: msg: INSERT 1
-- 2: X: 1
-- 2: X: 2
-- 2: msg: INSERT 1
-- 2: X: 1
-- 2: X: 2
-- 2: X: 4

-- # A statement that recovers the transactions of a connection that stopped
-- # fails if the session lock can't be changed back to shared afterwards. The
-- # next statement works.
/* connection 1 */
CREATE TABLE t (x INT);
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
/* disconnect 1 */
/* fault session_shared */
/* connection 2 */
INSERT INTO t (x) VALUES (2);
INSERT INTO t (x) VALUES (3);
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 1: msg: INSERT 1
-- 2: error 58030: session_shared failed (fault injected by test)
-- 2: msg: INSERT 1
-- 2: X: 3

-- # A new file that fails while it's being created (before it has the PUBLIC
-- # schema) can still be opened, but it doesn't have any objects yet.
/* fault wal_write */
/* connection 1 */
/* connection 2 */
VALUES NEXT VALUE FOR s;
CREATE TABLE t (x INT);
CREATE SCHEMA public;
CREATE TABLE t (x INT);
SELECT * FROM t;
-- 1: error 58030: wal_write failed (fault injected by test)
-- 2: error 42P01: no such sequence: "test".PUBLIC.S
-- 2: error 3F000: invalid schema name: PUBLIC
-- 2: msg: CREATE SCHEMA 1
-- 2: msg: CREATE TABLE 1

-- # A page that can't be read fails the statement, rather than ending the scan
-- # early.
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1), (2), (3), (4), (5), (6), (7), (8), (9), (10), (11), (12), (13), (14), (15), (16), (17), (18), (19), (20), (21), (22), (23), (24), (25), (26), (27), (28), (29), (30), (31), (32), (33), (34), (35), (36), (37), (38), (39), (40);
/* fault read_page 5 */
SELECT COUNT(*) AS c FROM t;
SELECT COUNT(*) AS c FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 40
-- error 58030: read_page failed (fault injected by test)
-- C: 40

-- # The same for a page of a value that's stored across several pages.
CREATE TABLE t (x VARCHAR(1000));
INSERT INTO t (x) VALUES ('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
/* fault read_page 5 */
SELECT CHARACTER_LENGTH(x) AS len FROM t;
SELECT CHARACTER_LENGTH(x) AS len FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 58030: read_page failed (fault injected by test)
-- LEN: 600

-- # A statement fails if its isolation block can't be started.
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
/* fault isolation_start */
INSERT INTO t (x) VALUES (2);
INSERT INTO t (x) VALUES (3);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 58030: isolation_start failed (fault injected by test)
-- msg: INSERT 1
-- X: 1
-- X: 3

-- # A statement that fails at the end of its isolation block has no effect,
-- # rather than stopping the process (#485).
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
/* fault isolation_end */
INSERT INTO t (x) VALUES (2), (3);
SELECT * FROM t;
INSERT INTO t (x) VALUES (4);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 58030: isolation_end failed (fault injected by test)
-- X: 1
-- msg: INSERT 1
-- X: 1
-- X: 4

-- # The same for the second row of an INSERT.
CREATE TABLE t (x INT);
/* fault isolation_end 2 */
INSERT INTO t (x) VALUES (1), (2);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- error 58030: isolation_end failed (fault injected by test)

-- # Reading is in an isolation block too.
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
/* fault isolation_end */
SELECT * FROM t;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 58030: isolation_end failed (fault injected by test)
-- X: 1

-- # A CREATE TABLE that fails at the end of its isolation block doesn't create
-- # the table.
/* fault isolation_end */
CREATE TABLE t (x INT);
CREATE TABLE t (x INT);
SELECT * FROM t;
-- error 58030: isolation_end failed (fault injected by test)
-- msg: CREATE TABLE 1

-- # In a transaction, only the statement fails and the transaction continues.
CREATE TABLE t (x INT);
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
/* fault isolation_end */
INSERT INTO t (x) VALUES (2);
INSERT INTO t (x) VALUES (3);
COMMIT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- error 58030: isolation_end failed (fault injected by test)
-- msg: INSERT 1
-- msg: COMMIT
-- X: 1
-- X: 3
