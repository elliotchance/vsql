-- # A COMMIT that fails cancels the changes of the SQL-transaction in every
-- # catalog (General Rules, 6.b), not just the catalog that couldn't be
-- # written. The catalog from create_catalog is in memory, so it's only
-- # committed once the file is. These tests only run on disk, see "Faults" in
-- # docs/testing.rst.
/* create_catalog FOO */
CREATE TABLE foo.public.bar (baz INTEGER);
SET CATALOG ':memory:';
CREATE TABLE t (x INT);
START TRANSACTION;
INSERT INTO foo.public.bar (baz) VALUES (1);
INSERT INTO t (x) VALUES (1);
/* fault wal_write */
COMMIT;
SELECT * FROM foo.public.bar;
SELECT * FROM t;
COMMIT;
-- msg: CREATE TABLE 1
-- msg: SET CATALOG 1
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: INSERT 1
-- error 40V01: transaction rollback: wal_write failed (fault injected by test)
-- error 2D000: invalid transaction termination

-- # The same when the file can't be committed after its pages are written.
/* create_catalog FOO */
CREATE TABLE foo.public.bar (baz INTEGER);
SET CATALOG ':memory:';
CREATE TABLE t (x INT);
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
INSERT INTO foo.public.bar (baz) VALUES (1);
/* fault wal_torn_frame */
COMMIT;
SELECT * FROM foo.public.bar;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: SET CATALOG 1
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: INSERT 1
-- error 40V01: transaction rollback: wal_torn_frame failed (fault injected by test)

-- # The current catalog doesn't matter, and the transaction can be repeated
-- # after it's rolled back.
/* create_catalog FOO */
CREATE TABLE foo.public.bar (baz INTEGER);
CREATE TABLE ":memory:".public.t (x INT);
SET CATALOG 'FOO';
START TRANSACTION;
INSERT INTO bar (baz) VALUES (1);
INSERT INTO ":memory:".public.t (x) VALUES (1);
/* fault wal_write */
COMMIT;
START TRANSACTION;
INSERT INTO bar (baz) VALUES (2);
INSERT INTO ":memory:".public.t (x) VALUES (2);
COMMIT;
SELECT * FROM bar;
SELECT * FROM ":memory:".public.t;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: SET CATALOG 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: INSERT 1
-- error 40V01: transaction rollback: wal_write failed (fault injected by test)
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: COMMIT
-- BAZ: 2
-- X: 2
