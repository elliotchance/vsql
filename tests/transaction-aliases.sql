-- # BEGIN, END and ABORT are vsql extensions (V114) for the transaction
-- # statements.

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

-- # COMMIT TRANSACTION and END are COMMIT.
/* extensions V115-01 */
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
COMMIT TRANSACTION;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: COMMIT
-- X: 1

/* extensions V115-02 */
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
END;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: COMMIT
-- X: 1

/* extensions V115-02 */
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
END TRANSACTION;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: COMMIT
-- X: 1

/* extensions V115-02 */
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
end work;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: COMMIT
-- X: 1

/* extensions V115-01 */
COMMIT TRANSACTION;
-- error 2D000: invalid transaction termination

/* extensions V115-02 */
END;
-- error 2D000: invalid transaction termination

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

-- # ABORT isn't reserved, BEGIN and END already were.
CREATE TABLE abort (abort INT);
INSERT INTO abort (abort) VALUES (1);
SELECT abort FROM abort;
SELECT abort.abort abort FROM abort AS abort;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- ABORT: 1
-- ABORT: 1

SELECT begin FROM t;
-- error 42601: syntax error: unexpected BEGIN

SELECT end FROM t;
-- error 42601: syntax error: unexpected END

ABORT ROW;
-- error 42601: syntax error: unexpected ROW

BEGIN ROW;
-- error 42601: syntax error: unexpected ROW

END ROW;
-- error 42601: syntax error: unexpected ROW

COMMIT ROW;
-- error 42601: syntax error: unexpected ROW

-- # The flagger: what the standard form needs, and which alias was used.
/* flags */
/* extensions V114-01 */
BEGIN;
-- flags: T241, V114-01
-- msg: START TRANSACTION

/* flags */
/* extensions V115-01 */
START TRANSACTION;
COMMIT TRANSACTION;
-- flags: T241
-- msg: START TRANSACTION
-- flags: V115-01
-- msg: COMMIT

/* flags */
/* extensions V115-02 */
START TRANSACTION;
END;
-- flags: T241
-- msg: START TRANSACTION
-- flags: V115-02
-- msg: COMMIT

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
