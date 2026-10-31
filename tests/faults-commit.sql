-- # A COMMIT that fails with an I/O error (rather than a serialization failure
-- # or a constraint violation) leaves the SQL-transaction active, so it can be
-- # committed again. These tests only run on disk, see "Faults" in
-- # docs/testing.rst.
CREATE TABLE t (x INT);
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
/* fault lock */
COMMIT;
SELECT * FROM t;
COMMIT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- error 58030: lock failed (fault injected by test)
-- X: 1
-- msg: COMMIT
-- X: 1

CREATE TABLE t (x INT);
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
/* fault wal_write */
COMMIT;
SELECT * FROM t;
COMMIT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- error 58030: wal_write failed (fault injected by test)
-- X: 1
-- msg: COMMIT
-- X: 1

CREATE TABLE t (x INT);
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
/* fault read_page */
COMMIT;
SELECT * FROM t;
COMMIT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- error 58030: read_page failed (fault injected by test)
-- X: 1
-- msg: COMMIT
-- X: 1
