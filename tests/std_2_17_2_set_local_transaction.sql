-- # SET LOCAL TRANSACTION is for a branch of an SQL-transaction that's active
-- # on another SQL-connection (T262), so on its own it's 25005 (17.2, General
-- # Rule 1.b.ii). See vsql/api_test.v for transactions on more than one
-- # SQL-connection.
SET LOCAL TRANSACTION;
SET LOCAL TRANSACTION READ ONLY;
SET LOCAL TRANSACTION ISOLATION LEVEL READ COMMITTED, READ WRITE;
-- error 25005: invalid transaction state: no active sql transaction for branch transaction
-- error 25005: invalid transaction state: no active sql transaction for branch transaction
-- error 25005: invalid transaction state: no active sql transaction for branch transaction

-- # In an SQL-transaction, the branch has already started, so it's 25002 (17.2,
-- # General Rule 1.b.iii), which doesn't change it.
CREATE TABLE t (x INT);
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
SET LOCAL TRANSACTION READ ONLY;
INSERT INTO t (x) VALUES (2);
COMMIT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- error 25002: invalid transaction state: branch transaction already active
-- msg: INSERT 1
-- msg: COMMIT
-- X: 1
-- X: 2

-- # It doesn't apply to the next transaction.
CREATE TABLE t (x INT);
SET LOCAL TRANSACTION READ ONLY;
INSERT INTO t (x) VALUES (1);
-- msg: CREATE TABLE 1
-- error 25005: invalid transaction state: no active sql transaction for branch transaction
-- msg: INSERT 1

-- # The Syntax Rules are checked first (17.2, Syntax Rule 1 and 17.3, Syntax
-- # Rule 2).
SET LOCAL TRANSACTION DIAGNOSTICS SIZE 1;
SET LOCAL TRANSACTION READ ONLY, READ WRITE;
SET LOCAL TRANSACTION ISOLATION LEVEL READ UNCOMMITTED, READ WRITE;
-- error 42601: syntax error: DIAGNOSTICS SIZE cannot be used with LOCAL
-- error 42601: syntax error: transaction access mode is specified more than once
-- error 42601: syntax error: READ WRITE cannot be used with READ UNCOMMITTED

EXPLAIN SET LOCAL TRANSACTION READ ONLY;
-- error 42601: syntax error: Cannot EXPLAIN SET TRANSACTION

/* flags */
SET LOCAL TRANSACTION READ ONLY;
-- flags: T251
-- error 25005: invalid transaction state: no active sql transaction for branch transaction

/* flags */
SET TRANSACTION READ ONLY;
-- flags:
-- msg: SET TRANSACTION
