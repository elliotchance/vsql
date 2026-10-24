SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
-- msg: SET TRANSACTION
-- msg: SET TRANSACTION
-- msg: SET TRANSACTION
-- msg: SET TRANSACTION

START TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
COMMIT;
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
COMMIT;
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
COMMIT;
START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
COMMIT;
-- msg: START TRANSACTION
-- msg: COMMIT
-- msg: START TRANSACTION
-- msg: COMMIT
-- msg: START TRANSACTION
-- msg: COMMIT
-- msg: START TRANSACTION
-- msg: COMMIT

EXPLAIN SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
-- error 42601: syntax error: Cannot EXPLAIN SET TRANSACTION

EXPLAIN START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
-- error 42601: syntax error: Cannot EXPLAIN START TRANSACTION

SET TRANSACTION ISOLATION LEVEL;
-- error 42601: syntax error: unexpected $end, expecting READ or REPEATABLE or SERIALIZABLE

SET TRANSACTION ISOLATION LEVEL READ;
-- error 42601: syntax error: unexpected $end, expecting COMMITTED or UNCOMMITTED

SET TRANSACTION ISOLATION SERIALIZABLE;
-- error 42601: syntax error: unexpected SERIALIZABLE, expecting LEVEL

SET TRANSACTION SERIALIZABLE;
-- error 42601: syntax error: unexpected SERIALIZABLE, expecting ISOLATION or READ

SET TRANSACTION ISOLATION LEVEL REPEATABLE;
-- error 42601: syntax error: unexpected $end, expecting READ

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE READ ONLY;
-- error 42601: syntax error: unexpected READ

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE,;
-- error 42601: syntax error: unexpected $end, expecting ISOLATION or READ

START TRANSACTION ISOLATION LEVEL SNAPSHOT;
-- error 42601: syntax error: unexpected identifier, expecting READ or REPEATABLE or SERIALIZABLE

-- # Several modes are separated by commas, in any order.
CREATE TABLE t (x INT);
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE, READ ONLY;
INSERT INTO t (x) VALUES (1);
SET TRANSACTION READ ONLY, ISOLATION LEVEL REPEATABLE READ;
INSERT INTO t (x) VALUES (2);
START TRANSACTION ISOLATION LEVEL READ COMMITTED, READ ONLY;
INSERT INTO t (x) VALUES (3);
COMMIT;
START TRANSACTION READ WRITE, ISOLATION LEVEL SERIALIZABLE;
INSERT INTO t (x) VALUES (4);
COMMIT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: SET TRANSACTION
-- error 25006: read-only sql transaction: cannot execute INSERT
-- msg: SET TRANSACTION
-- error 25006: read-only sql transaction: cannot execute INSERT
-- msg: START TRANSACTION
-- error 25006: read-only sql transaction: cannot execute INSERT
-- msg: COMMIT
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: COMMIT
-- X: 4

-- # Each kind of mode can only be given once (17.3, Syntax Rule 2), even if
-- # it's the same.
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE, ISOLATION LEVEL READ COMMITTED;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE, ISOLATION LEVEL SERIALIZABLE;
SET TRANSACTION READ ONLY, ISOLATION LEVEL SERIALIZABLE, READ WRITE;
SET TRANSACTION READ ONLY, READ ONLY;
START TRANSACTION ISOLATION LEVEL READ COMMITTED, ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION READ WRITE, READ ONLY;
COMMIT;
-- error 42601: syntax error: isolation level is specified more than once
-- error 42601: syntax error: isolation level is specified more than once
-- error 42601: syntax error: transaction access mode is specified more than once
-- error 42601: syntax error: transaction access mode is specified more than once
-- error 42601: syntax error: isolation level is specified more than once
-- error 42601: syntax error: transaction access mode is specified more than once
-- error 2D000: invalid transaction termination

-- # READ UNCOMMITTED is READ ONLY, unless it says otherwise (17.3, Syntax Rule
-- # 5a). READ WRITE isn't allowed with it (Syntax Rule 4).
CREATE TABLE t (x INT);
START TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT * FROM t;
INSERT INTO t (x) VALUES (1);
COMMIT;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
INSERT INTO t (x) VALUES (2);
START TRANSACTION ISOLATION LEVEL READ UNCOMMITTED, READ ONLY;
INSERT INTO t (x) VALUES (3);
COMMIT;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED, READ WRITE;
SET TRANSACTION READ WRITE, ISOLATION LEVEL READ UNCOMMITTED;
START TRANSACTION ISOLATION LEVEL READ UNCOMMITTED, READ WRITE;
INSERT INTO t (x) VALUES (4);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- error 25006: read-only sql transaction: cannot execute INSERT
-- msg: COMMIT
-- msg: SET TRANSACTION
-- error 25006: read-only sql transaction: cannot execute INSERT
-- msg: START TRANSACTION
-- error 25006: read-only sql transaction: cannot execute INSERT
-- msg: COMMIT
-- error 42601: syntax error: READ WRITE cannot be used with READ UNCOMMITTED
-- error 42601: syntax error: READ WRITE cannot be used with READ UNCOMMITTED
-- error 42601: syntax error: READ WRITE cannot be used with READ UNCOMMITTED
-- msg: INSERT 1
-- X: 4

-- # The other isolation levels are READ WRITE by default.
CREATE TABLE t (x INT);
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
INSERT INTO t (x) VALUES (1);
COMMIT;
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
INSERT INTO t (x) VALUES (2);
COMMIT;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
INSERT INTO t (x) VALUES (3);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: COMMIT
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: COMMIT
-- msg: SET TRANSACTION
-- msg: INSERT 1
-- X: 1
-- X: 2
-- X: 3

-- # The modes are checked before whether a transaction is active.
START TRANSACTION;
SET TRANSACTION READ ONLY, READ WRITE;
START TRANSACTION ISOLATION LEVEL READ UNCOMMITTED, READ WRITE;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
COMMIT;
-- msg: START TRANSACTION
-- error 42601: syntax error: transaction access mode is specified more than once
-- error 42601: syntax error: READ WRITE cannot be used with READ UNCOMMITTED
-- error 25001: invalid transaction state: active sql transaction
-- error 25001: invalid transaction state: active sql transaction
-- msg: COMMIT

-- # A SET TRANSACTION that fails doesn't replace the previous one.
CREATE TABLE t (x INT);
SET TRANSACTION READ ONLY;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE, ISOLATION LEVEL READ COMMITTED;
INSERT INTO t (x) VALUES (1);
INSERT INTO t (x) VALUES (2);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: SET TRANSACTION
-- error 42601: syntax error: isolation level is specified more than once
-- error 25006: read-only sql transaction: cannot execute INSERT
-- msg: INSERT 1
-- X: 2

-- # START TRANSACTION with characteristics replaces all of the ones from SET
-- # TRANSACTION, and the ones it doesn't give have their defaults.
CREATE TABLE t (x INT);
SET TRANSACTION READ ONLY;
START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
INSERT INTO t (x) VALUES (1);
COMMIT;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
INSERT INTO t (x) VALUES (2);
COMMIT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: SET TRANSACTION
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: COMMIT
-- msg: SET TRANSACTION
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: COMMIT
-- X: 1
-- X: 2

-- # START TRANSACTION without characteristics uses the ones from SET
-- # TRANSACTION.
CREATE TABLE t (x INT);
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
COMMIT;
-- msg: CREATE TABLE 1
-- msg: SET TRANSACTION
-- msg: START TRANSACTION
-- error 25006: read-only sql transaction: cannot execute INSERT
-- msg: COMMIT

-- # The keywords are not reserved, so they can still be used as names.
CREATE TABLE isolation (level INT, serializable INT, repeatable INT, committed INT, uncommitted INT);
INSERT INTO isolation (level, serializable, repeatable, committed, uncommitted) VALUES (1, 2, 3, 4, 5);
SELECT * FROM isolation;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- LEVEL: 1 SERIALIZABLE: 2 REPEATABLE: 3 COMMITTED: 4 UNCOMMITTED: 5
