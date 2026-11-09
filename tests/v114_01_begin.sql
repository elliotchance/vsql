-- # BEGIN is a vsql extension (V114-01) for START TRANSACTION.

/* setup */
CREATE TABLE t (x INT);

-- # BEGIN is START TRANSACTION.
/* extensions V114-01 */
BEGIN;
INSERT INTO t (x) VALUES (1);
COMMIT;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: COMMIT
-- X: 1

/* extensions V114-01 */
BEGIN TRANSACTION;
INSERT INTO t (x) VALUES (1);
ROLLBACK;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: ROLLBACK

/* extensions V114-01 */
begin work;
INSERT INTO t (x) VALUES (1);
ROLLBACK WORK;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: ROLLBACK

-- # The characteristics are the same as START TRANSACTION.
/* extensions V114-01 */
BEGIN DIAGNOSTICS SIZE 5;
COMMIT;
-- msg: START TRANSACTION
-- msg: COMMIT

/* extensions V114-01 */
BEGIN TRANSACTION DIAGNOSTICS SIZE 5;
COMMIT;
-- msg: START TRANSACTION
-- msg: COMMIT

/* extensions V114-01 */
BEGIN WORK DIAGNOSTICS SIZE 5;
COMMIT;
-- msg: START TRANSACTION
-- msg: COMMIT

-- # Like START TRANSACTION, it can't start a transaction while one is active
-- # (17.1, General Rules, 1).
/* extensions V114-01 */
BEGIN;
BEGIN;
-- msg: START TRANSACTION
-- error 25001: invalid transaction state: active sql transaction

/* extensions V114-01 */
START TRANSACTION;
BEGIN WORK;
-- msg: START TRANSACTION
-- error 25001: invalid transaction state: active sql transaction

-- # A whole transaction with only the aliases.
/* extensions V114-01 V115-02 V116-02 */
BEGIN;
INSERT INTO t (x) VALUES (1);
END;
BEGIN;
INSERT INTO t (x) VALUES (2);
ABORT;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: COMMIT
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: ROLLBACK
-- X: 1

-- # BEGIN is a reserved word, so it can't be a column name (5.2, Syntax
-- # Rules, 26). Only TRANSACTION or WORK can follow it.
SELECT begin FROM t;
-- error 42601: syntax error: unexpected BEGIN at line 1, column 8 near "SELECT begin FROM"; hint: BEGIN is a reserved word, so it must be quoted to be used as a name, such as "BEGIN" (see https://vsql.readthedocs.io/en/latest/keywords.html)

BEGIN ROW;
-- error 42601: syntax error: unexpected ROW at line 1, column 7 near "BEGIN ROW"

-- # The flagger: what the standard form needs, and which alias was used.
/* flags */
/* extensions V114-01 */
BEGIN;
-- flags: T241, V114-01
-- msg: START TRANSACTION
