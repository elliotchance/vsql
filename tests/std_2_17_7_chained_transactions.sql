-- # AND CHAIN starts another transaction. AND NO CHAIN is the default.
CREATE TABLE t (x INT);
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
COMMIT AND CHAIN;
INSERT INTO t (x) VALUES (2);
ROLLBACK AND CHAIN;
INSERT INTO t (x) VALUES (3);
COMMIT WORK AND CHAIN;
INSERT INTO t (x) VALUES (4);
ROLLBACK WORK AND CHAIN;
INSERT INTO t (x) VALUES (5);
COMMIT AND NO CHAIN;
START TRANSACTION;
INSERT INTO t (x) VALUES (6);
ROLLBACK AND NO CHAIN;
START TRANSACTION;
INSERT INTO t (x) VALUES (7);
COMMIT WORK AND NO CHAIN;
START TRANSACTION;
INSERT INTO t (x) VALUES (8);
ROLLBACK WORK AND NO CHAIN;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: COMMIT
-- msg: INSERT 1
-- msg: ROLLBACK
-- msg: INSERT 1
-- msg: COMMIT
-- msg: INSERT 1
-- msg: ROLLBACK
-- msg: INSERT 1
-- msg: COMMIT
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: ROLLBACK
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: COMMIT
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: ROLLBACK
-- X: 1
-- X: 3
-- X: 5
-- X: 7

-- # A transaction is active after it, so it can't be started again.
START TRANSACTION;
COMMIT AND CHAIN;
START TRANSACTION;
ROLLBACK AND CHAIN;
SET TRANSACTION READ ONLY;
ROLLBACK;
-- msg: START TRANSACTION
-- msg: COMMIT
-- error 25001: invalid transaction state: active sql transaction
-- msg: ROLLBACK
-- error 25001: invalid transaction state: active sql transaction
-- msg: ROLLBACK

-- # Without a transaction, it does nothing and doesn't start one.
COMMIT AND CHAIN;
ROLLBACK AND CHAIN;
START TRANSACTION;
ROLLBACK;
-- msg: COMMIT
-- msg: ROLLBACK
-- msg: START TRANSACTION
-- msg: ROLLBACK

-- # The access mode is the same (17.7, General Rule 10.a), until it's not chained.
CREATE TABLE t (x INT);
START TRANSACTION READ ONLY;
COMMIT AND CHAIN;
INSERT INTO t (x) VALUES (1);
ROLLBACK AND CHAIN;
INSERT INTO t (x) VALUES (2);
COMMIT;
INSERT INTO t (x) VALUES (3);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: COMMIT
-- error 25006: read-only sql transaction: cannot execute INSERT
-- msg: ROLLBACK
-- error 25006: read-only sql transaction: cannot execute INSERT
-- msg: COMMIT
-- msg: INSERT 1
-- X: 3

-- # So is the condition area limit.
START TRANSACTION DIAGNOSTICS SIZE 1;
COMMIT AND CHAIN;
VALUES CAST('abcde' AS CHARACTER(3)) || CAST('abcde' AS CHARACTER(3));
ROLLBACK AND CHAIN;
VALUES CAST('abcde' AS CHARACTER(3)) || CAST('abcde' AS CHARACTER(3));
COMMIT;
VALUES CAST('abcde' AS CHARACTER(3)) || CAST('abcde' AS CHARACTER(3));
-- msg: START TRANSACTION
-- msg: COMMIT
-- warning 01004: string data, right truncation
-- COL1: abcabc
-- msg: ROLLBACK
-- warning 01004: string data, right truncation
-- COL1: abcabc
-- msg: COMMIT
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- COL1: abcabc

-- # A COMMIT sets every constraint to immediate first (17.7, General Rule 5), and
-- # only the end of a transaction that isn't chained resets them (10.b.ii). So a
-- # chained one has them as immediate, even if they're initially deferred.
CREATE TABLE t (x INT, CONSTRAINT c UNIQUE (x) INITIALLY DEFERRED);
START TRANSACTION;
COMMIT AND CHAIN;
INSERT INTO t (x) VALUES (1);
INSERT INTO t (x) VALUES (1);
SET CONSTRAINTS c DEFERRED;
INSERT INTO t (x) VALUES (1);
ROLLBACK AND CHAIN;
INSERT INTO t (x) VALUES (2);
INSERT INTO t (x) VALUES (2);
ROLLBACK;
START TRANSACTION;
INSERT INTO t (x) VALUES (3);
INSERT INTO t (x) VALUES (3);
ROLLBACK;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: COMMIT
-- msg: INSERT 1
-- error 23505: violates unique constraint: UNIQUE (X) on ":memory:".PUBLIC.T
-- msg: SET CONSTRAINTS
-- msg: INSERT 1
-- msg: ROLLBACK
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: ROLLBACK
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: ROLLBACK

-- # A failed COMMIT rolls back, and doesn't chain.
CREATE TABLE t (x INT, CONSTRAINT c UNIQUE (x) INITIALLY DEFERRED);
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
INSERT INTO t (x) VALUES (1);
COMMIT AND CHAIN;
START TRANSACTION;
ROLLBACK;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: INSERT 1
-- error 40002: integrity constraint violation: violates unique constraint: UNIQUE (X) on ":memory:".PUBLIC.T
-- msg: START TRANSACTION
-- msg: ROLLBACK

-- # A non-holdable cursor is closed, and a holdable one stays open with COMMIT.
/* extensions V108-01 V109-01 V110-01 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
INSERT INTO t (x) VALUES (2);
START TRANSACTION;
DECLARE a CURSOR FOR SELECT * FROM t;
DECLARE b CURSOR WITH HOLD FOR SELECT * FROM t;
OPEN a;
OPEN b;
COMMIT AND CHAIN;
FETCH NEXT FROM b;
FETCH NEXT FROM a;
ROLLBACK AND CHAIN;
FETCH NEXT FROM b;
ROLLBACK;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: DECLARE CURSOR
-- msg: OPEN
-- msg: OPEN
-- msg: COMMIT
-- X: 1
-- error 24000: invalid cursor state: cursor A is not open
-- msg: ROLLBACK
-- error 24000: invalid cursor state: cursor B is not open
-- msg: ROLLBACK

-- # Every catalog is in the next transaction.
/* create_catalog FOO */
CREATE TABLE foo.public.bar (baz INTEGER);
START TRANSACTION;
INSERT INTO foo.public.bar (baz) VALUES (1);
COMMIT AND CHAIN;
INSERT INTO foo.public.bar (baz) VALUES (2);
ROLLBACK AND CHAIN;
INSERT INTO foo.public.bar (baz) VALUES (3);
COMMIT;
SELECT * FROM foo.public.bar;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: COMMIT
-- msg: INSERT 1
-- msg: ROLLBACK
-- msg: INSERT 1
-- msg: COMMIT
-- BAZ: 1
-- BAZ: 3

-- # SERIALIZABLE keeps the isolation lock, with nothing committing in between.
/* connection 1 */
CREATE TABLE t (x INT);
START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
INSERT INTO t (x) VALUES (1);
COMMIT AND CHAIN;
/* connection 2 */
INSERT INTO t (x) VALUES (2);
/* connection 1 */
ROLLBACK AND CHAIN;
/* connection 2 */
INSERT INTO t (x) VALUES (3);
/* connection 1 */
COMMIT;
/* connection 2 */
INSERT INTO t (x) VALUES (4);
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 1: msg: INSERT 1
-- 1: msg: COMMIT
-- 2: error 40001: serialization failure: another connection has a transaction that must finish first
-- 1: msg: ROLLBACK
-- 2: error 40001: serialization failure: another connection has a transaction that must finish first
-- 1: msg: COMMIT
-- 2: msg: INSERT 1
-- 2: X: 1
-- 2: X: 4

-- # READ COMMITTED gives up the lock that committing took, so another connection
-- # can still commit during the next transaction.
/* connection 1 */
CREATE TABLE t (x INT);
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
INSERT INTO t (x) VALUES (1);
COMMIT AND CHAIN;
/* connection 2 */
INSERT INTO t (x) VALUES (2);
/* connection 1 */
SELECT * FROM t;
ROLLBACK AND CHAIN;
/* connection 2 */
INSERT INTO t (x) VALUES (3);
/* connection 1 */
SELECT * FROM t;
COMMIT;
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 1: msg: INSERT 1
-- 1: msg: COMMIT
-- 2: msg: INSERT 1
-- 1: X: 1
-- 1: X: 2
-- 1: msg: ROLLBACK
-- 2: msg: INSERT 1
-- 1: X: 1
-- 1: X: 2
-- 1: X: 3
-- 1: msg: COMMIT

-- # CHAIN isn't reserved.
CREATE TABLE chain (chain INT);
INSERT INTO chain (chain) VALUES (1);
SELECT chain FROM chain;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- CHAIN: 1

COMMIT AND;
ROLLBACK AND NO;
-- error 42601: syntax error: unexpected $end at line 1, column 11 near "COMMIT AND", expecting CHAIN or NO
-- error 42601: syntax error: unexpected $end at line 1, column 16 near "ROLLBACK AND NO", expecting CHAIN

/* flags */
COMMIT AND CHAIN;
-- flags: T261
-- msg: COMMIT

/* flags */
ROLLBACK AND NO CHAIN;
-- flags: T261
-- msg: ROLLBACK

/* flags */
COMMIT WORK;
-- flags:
-- msg: COMMIT
