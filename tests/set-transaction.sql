SET TRANSACTION READ ONLY;
-- msg: SET TRANSACTION

SET TRANSACTION READ WRITE;
-- msg: SET TRANSACTION

-- # SET TRANSACTION is for the next transaction, so it can't be used in one.
START TRANSACTION;
SET TRANSACTION READ ONLY;
-- msg: START TRANSACTION
-- error 25001: invalid transaction state: active sql transaction

EXPLAIN SET TRANSACTION READ ONLY;
-- error 42601: syntax error: Cannot EXPLAIN SET TRANSACTION

SET TRANSACTION READ ONLY, READ WRITE;
-- error 42601: syntax error: transaction access mode is specified more than once

SET TRANSACTION;
-- error 42601: syntax error: unexpected $end, expecting ISOLATION or READ

-- # A read-only transaction can read, but not change, the database.
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
CREATE SEQUENCE seq;
START TRANSACTION READ ONLY;
SELECT * FROM t;
VALUES NEXT VALUE FOR seq;
INSERT INTO t (x) VALUES (2);
UPDATE t SET x = 3;
DELETE FROM t;
CREATE TABLE t2 (x INT);
DROP TABLE t;
ALTER TABLE t ADD COLUMN y INT;
CREATE SCHEMA s;
DROP SCHEMA public CASCADE;
CREATE SEQUENCE seq2;
ALTER SEQUENCE seq RESTART;
DROP SEQUENCE seq;
SET SCHEMA 'PUBLIC';
SET CONSTRAINTS ALL DEFERRED;
COMMIT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: CREATE SEQUENCE 1
-- msg: START TRANSACTION
-- X: 1
-- COL1: 1
-- error 25006: read-only sql transaction: cannot execute INSERT
-- error 25006: read-only sql transaction: cannot execute UPDATE
-- error 25006: read-only sql transaction: cannot execute DELETE
-- error 25006: read-only sql transaction: cannot execute CREATE TABLE
-- error 25006: read-only sql transaction: cannot execute DROP TABLE
-- error 25006: read-only sql transaction: cannot execute ALTER TABLE
-- error 25006: read-only sql transaction: cannot execute CREATE SCHEMA
-- error 25006: read-only sql transaction: cannot execute DROP SCHEMA
-- error 25006: read-only sql transaction: cannot execute CREATE SEQUENCE
-- error 25006: read-only sql transaction: cannot execute ALTER SEQUENCE
-- error 25006: read-only sql transaction: cannot execute DROP SEQUENCE
-- msg: SET SCHEMA 1
-- msg: SET CONSTRAINTS
-- msg: COMMIT
-- X: 1

-- # The access mode only lasts for one transaction.
CREATE TABLE t (x INT);
START TRANSACTION READ ONLY;
ROLLBACK;
INSERT INTO t (x) VALUES (1);
START TRANSACTION;
INSERT INTO t (x) VALUES (2);
COMMIT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: ROLLBACK
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: COMMIT
-- X: 1
-- X: 2

START TRANSACTION READ WRITE;
CREATE TABLE t (x INT);
COMMIT;
-- msg: START TRANSACTION
-- msg: CREATE TABLE 1
-- msg: COMMIT

-- # SET TRANSACTION applies to the next START TRANSACTION.
CREATE TABLE t (x INT);
SET TRANSACTION READ ONLY;
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
ROLLBACK;
START TRANSACTION;
INSERT INTO t (x) VALUES (2);
COMMIT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: SET TRANSACTION
-- msg: START TRANSACTION
-- error 25006: read-only sql transaction: cannot execute INSERT
-- msg: ROLLBACK
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: COMMIT
-- X: 2

-- # START TRANSACTION can replace the access mode from SET TRANSACTION.
CREATE TABLE t (x INT);
SET TRANSACTION READ ONLY;
START TRANSACTION READ WRITE;
INSERT INTO t (x) VALUES (1);
COMMIT;
SET TRANSACTION READ WRITE;
START TRANSACTION READ ONLY;
INSERT INTO t (x) VALUES (2);
ROLLBACK;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: SET TRANSACTION
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: COMMIT
-- msg: SET TRANSACTION
-- msg: START TRANSACTION
-- error 25006: read-only sql transaction: cannot execute INSERT
-- msg: ROLLBACK
-- X: 1

-- # Without START TRANSACTION, SET TRANSACTION applies to the implicit
-- # transaction of the next statement that starts one. SET SCHEMA doesn't.
CREATE TABLE t (x INT);
SET TRANSACTION READ ONLY;
SET SCHEMA 'PUBLIC';
INSERT INTO t (x) VALUES (1);
INSERT INTO t (x) VALUES (2);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: SET TRANSACTION
-- msg: SET SCHEMA 1
-- error 25006: read-only sql transaction: cannot execute INSERT
-- msg: INSERT 1
-- X: 2

-- # A query uses up SET TRANSACTION too.
CREATE TABLE t (x INT);
SET TRANSACTION READ ONLY;
SELECT * FROM t;
INSERT INTO t (x) VALUES (1);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: SET TRANSACTION
-- msg: INSERT 1
-- X: 1

-- # The last SET TRANSACTION wins.
CREATE TABLE t (x INT);
SET TRANSACTION READ ONLY;
SET TRANSACTION READ WRITE;
INSERT INTO t (x) VALUES (1);
-- msg: CREATE TABLE 1
-- msg: SET TRANSACTION
-- msg: SET TRANSACTION
-- msg: INSERT 1

-- # EXPLAIN doesn't run the statement, so it doesn't start a transaction.
CREATE TABLE t (x INT);
SET TRANSACTION READ ONLY;
EXPLAIN SELECT * FROM t;
INSERT INTO t (x) VALUES (1);
-- msg: CREATE TABLE 1
-- msg: SET TRANSACTION
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (X INTEGER)
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.X INTEGER)
-- error 25006: read-only sql transaction: cannot execute INSERT
