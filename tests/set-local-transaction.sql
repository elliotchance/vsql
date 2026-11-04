-- # vsql doesn't have transactions on more than one SQL-server, so it's always
-- # 0A001 (17.2, General Rule 1.b.i).
SET LOCAL TRANSACTION;
SET LOCAL TRANSACTION READ ONLY;
SET LOCAL TRANSACTION ISOLATION LEVEL READ COMMITTED, READ WRITE;
-- error 0A001: feature not supported: multiple server transactions
-- error 0A001: feature not supported: multiple server transactions
-- error 0A001: feature not supported: multiple server transactions

-- # It's the same in an SQL-transaction, which it doesn't change.
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
-- error 0A001: feature not supported: multiple server transactions
-- msg: INSERT 1
-- msg: COMMIT
-- X: 1
-- X: 2

-- # It doesn't apply to the next transaction.
CREATE TABLE t (x INT);
SET LOCAL TRANSACTION READ ONLY;
INSERT INTO t (x) VALUES (1);
-- msg: CREATE TABLE 1
-- error 0A001: feature not supported: multiple server transactions
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
-- error 0A001: feature not supported: multiple server transactions

/* flags */
SET TRANSACTION READ ONLY;
-- flags:
-- msg: SET TRANSACTION
