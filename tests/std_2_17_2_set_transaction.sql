-- # SET TRANSACTION doesn't need any characteristics. DIAGNOSTICS SIZE is
-- # flagged as F124 (17.3, Conformance Rules, 5), and START TRANSACTION as T241
-- # (17.1, Conformance Rules, 1).
SET TRANSACTION;
-- msg: SET TRANSACTION

/* flags */
SET TRANSACTION DIAGNOSTICS SIZE 1;
-- flags: F124
-- msg: SET TRANSACTION

/* flags */
START TRANSACTION DIAGNOSTICS SIZE 1;
-- flags: F124, T241
-- msg: START TRANSACTION

-- # DIAGNOSTICS SIZE is the most conditions kept for a statement, so only one
-- # of the two truncation warnings is shown. SET TRANSACTION is only for the
-- # next transaction (here the first VALUES, which is a transaction of its
-- # own), and then the default of 100 is used again (17.7, General Rules,
-- # 10.b.i). START TRANSACTION can set it for its own transaction, but without
-- # characteristics it uses the default rather than a SET TRANSACTION before it
-- # (17.1, General Rules, 2.a).
SET TRANSACTION DIAGNOSTICS SIZE 1;
VALUES CAST('abcde' AS CHARACTER(3)) || CAST('abcde' AS CHARACTER(3));
VALUES CAST('abcde' AS CHARACTER(3)) || CAST('abcde' AS CHARACTER(3));
-- msg: SET TRANSACTION
-- warning 01004: string data, right truncation
-- COL1: abcabc
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- COL1: abcabc

START TRANSACTION DIAGNOSTICS SIZE 1;
VALUES CAST('abcde' AS CHARACTER(3)) || CAST('abcde' AS CHARACTER(3));
COMMIT;
-- msg: START TRANSACTION
-- warning 01004: string data, right truncation
-- COL1: abcabc
-- msg: COMMIT

SET TRANSACTION DIAGNOSTICS SIZE 1;
START TRANSACTION;
VALUES CAST('abcde' AS CHARACTER(3)) || CAST('abcde' AS CHARACTER(3));
COMMIT;
-- msg: SET TRANSACTION
-- msg: START TRANSACTION
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- COL1: abcabc
-- msg: COMMIT

-- # Less than 1 is 35000 (General Rules, 2 and 17.1, General Rules, 3). The
-- # size must be exact numeric with scale 0, so even 1.0 is 42804 (17.3, Syntax
-- # Rules, 6), and it can only be given once (17.3, Syntax Rules, 2). More than
-- # 100, the most that vsql allows, is a warning 01012 and 100 is used (General
-- # Rules, 3). SET TRANSACTION can't be explained.
SET TRANSACTION DIAGNOSTICS SIZE 0;
SET TRANSACTION DIAGNOSTICS SIZE -1;
START TRANSACTION DIAGNOSTICS SIZE 0;
SET TRANSACTION DIAGNOSTICS SIZE 1.5;
SET TRANSACTION DIAGNOSTICS SIZE 'a';
SET TRANSACTION DIAGNOSTICS SIZE 1, DIAGNOSTICS SIZE 2;
SET TRANSACTION DIAGNOSTICS SIZE 101;
SET TRANSACTION DIAGNOSTICS SIZE 1.0;
EXPLAIN SET TRANSACTION;
-- error 35000: invalid condition number
-- error 35000: invalid condition number
-- error 35000: invalid condition number
-- error 42804: data type mismatch for DIAGNOSTICS SIZE: expected exact numeric with scale 0 but got NUMERIC(2, 1)
-- error 42804: data type mismatch for DIAGNOSTICS SIZE: expected exact numeric with scale 0 but got CHARACTER(1)
-- error 42601: syntax error: DIAGNOSTICS SIZE can only be used once
-- warning 01012: invalid number of conditions
-- msg: SET TRANSACTION
-- error 42804: data type mismatch for DIAGNOSTICS SIZE: expected exact numeric with scale 0 but got NUMERIC(2, 1)
-- error 42601: syntax error: Cannot EXPLAIN SET TRANSACTION

-- # SET TRANSACTION isn't allowed in an active transaction (General Rules,
-- # 1.a.i).
START TRANSACTION;
SET TRANSACTION DIAGNOSTICS SIZE 1;
-- msg: START TRANSACTION
-- error 25001: invalid transaction state: active sql transaction

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

-- # A read-only transaction can read, but not change, the database.
/* extensions V104-01 V107-01 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
CREATE SEQUENCE seq;
START TRANSACTION READ ONLY;
SELECT * FROM t;
SELECT NEXT VALUE FOR seq FROM t;
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

-- # A START TRANSACTION doesn't use the characteristics of a SET TRANSACTION
-- # (17.1 NOTE 710), but it does use them up.
CREATE TABLE t (x INT);
SET TRANSACTION READ ONLY;
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
COMMIT;
INSERT INTO t (x) VALUES (2);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: SET TRANSACTION
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: COMMIT
-- msg: INSERT 1
-- X: 1
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
/* extensions V001-01 */
CREATE TABLE t (x INT);
SET TRANSACTION READ ONLY;
EXPLAIN SELECT * FROM t;
INSERT INTO t (x) VALUES (1);
-- msg: CREATE TABLE 1
-- msg: SET TRANSACTION
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (X INTEGER)
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.X INTEGER)
-- error 25006: read-only sql transaction: cannot execute INSERT

-- # A positioned UPDATE and DELETE are changes too.
/* extensions V108-01 V109-01 V110-01 V112-01 V113-01 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
START TRANSACTION READ ONLY;
DECLARE c CURSOR FOR SELECT * FROM t FOR UPDATE;
OPEN c;
FETCH NEXT FROM c;
UPDATE t SET x = 2 WHERE CURRENT OF c;
DELETE FROM t WHERE CURRENT OF c;
COMMIT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1
-- error 25006: read-only sql transaction: cannot execute UPDATE
-- error 25006: read-only sql transaction: cannot execute DELETE
-- msg: COMMIT
-- X: 1

-- # EXPLAIN doesn't run the statement, so it's allowed.
/* extensions V001-02 */
CREATE TABLE t (x INT);
START TRANSACTION READ ONLY;
EXPLAIN DELETE FROM t;
ROLLBACK;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (X INTEGER)
-- msg: ROLLBACK
