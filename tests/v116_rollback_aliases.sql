-- # ROLLBACK TRANSACTION (V116-01) and ABORT (V116-02) are vsql extensions
-- # for ROLLBACK.

/* setup */
CREATE TABLE t (x INT);

-- # ROLLBACK TRANSACTION and ABORT are ROLLBACK.
/* extensions V116-01 */
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
ROLLBACK TRANSACTION;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: ROLLBACK

/* extensions V116-02 */
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
ABORT;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: ROLLBACK

/* extensions V116-02 */
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
ABORT TRANSACTION;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: ROLLBACK

/* extensions V116-02 */
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
abort work;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: ROLLBACK

-- # Like ROLLBACK, they fail when there's no transaction to end.
/* extensions V116-01 */
ROLLBACK TRANSACTION;
-- error 2D000: invalid transaction termination

/* extensions V116-02 */
ABORT;
-- error 2D000: invalid transaction termination

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

-- # Only TRANSACTION or WORK can follow ABORT.
ABORT ROW;
-- error 42601: syntax error: unexpected ROW

-- # The flagger: START TRANSACTION is T241, and the alias is flagged on the
-- # statement that uses it.
/* flags */
/* extensions V116-01 */
START TRANSACTION;
ROLLBACK TRANSACTION;
-- flags: T241
-- msg: START TRANSACTION
-- flags: V116-01
-- msg: ROLLBACK

/* flags */
/* extensions V116-02 */
START TRANSACTION;
ABORT;
-- flags: T241
-- msg: START TRANSACTION
-- flags: V116-02
-- msg: ROLLBACK

-- # ABORT isn't reserved, BEGIN and END already were.
CREATE TABLE abort (abort INT);
INSERT INTO abort (abort) VALUES (1);
SELECT abort FROM abort;
SELECT abort.abort abort FROM abort AS abort;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- ABORT: 1
-- ABORT: 1
