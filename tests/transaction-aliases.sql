-- # BEGIN, END and ABORT are vsql extensions (V013) for the transaction
-- # statements.

/* setup */
CREATE TABLE t (x INT);

-- # BEGIN is START TRANSACTION.
/* extensions V013-01 */
BEGIN;
INSERT INTO t (x) VALUES (1);
COMMIT;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: COMMIT
-- X: 1

/* extensions V013-01 */
BEGIN TRANSACTION;
INSERT INTO t (x) VALUES (1);
ROLLBACK;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: ROLLBACK

/* extensions V013-01 */
begin work;
INSERT INTO t (x) VALUES (1);
ROLLBACK WORK;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: ROLLBACK

-- # The characteristics are the same as START TRANSACTION.
/* extensions V013-01 */
BEGIN DIAGNOSTICS SIZE 5;
COMMIT;
-- msg: START TRANSACTION
-- msg: COMMIT

/* extensions V013-01 */
BEGIN TRANSACTION DIAGNOSTICS SIZE 5;
COMMIT;
-- msg: START TRANSACTION
-- msg: COMMIT

/* extensions V013-01 */
BEGIN WORK DIAGNOSTICS SIZE 5;
COMMIT;
-- msg: START TRANSACTION
-- msg: COMMIT

/* extensions V013-01 */
BEGIN;
BEGIN;
-- msg: START TRANSACTION
-- error 25001: invalid transaction state: active sql transaction

/* extensions V013-01 */
START TRANSACTION;
BEGIN WORK;
-- msg: START TRANSACTION
-- error 25001: invalid transaction state: active sql transaction

-- # COMMIT TRANSACTION and END are COMMIT.
/* extensions V013-02 */
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
COMMIT TRANSACTION;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: COMMIT
-- X: 1

/* extensions V013-03 */
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
END;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: COMMIT
-- X: 1

/* extensions V013-03 */
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
END TRANSACTION;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: COMMIT
-- X: 1

/* extensions V013-03 */
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
end work;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: COMMIT
-- X: 1

/* extensions V013-02 */
COMMIT TRANSACTION;
-- error 2D000: invalid transaction termination

/* extensions V013-03 */
END;
-- error 2D000: invalid transaction termination

-- # ROLLBACK TRANSACTION and ABORT are ROLLBACK.
/* extensions V013-04 */
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
ROLLBACK TRANSACTION;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: ROLLBACK

/* extensions V013-05 */
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
ABORT;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: ROLLBACK

/* extensions V013-05 */
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
ABORT TRANSACTION;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: ROLLBACK

/* extensions V013-05 */
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
abort work;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: ROLLBACK

/* extensions V013-04 */
ROLLBACK TRANSACTION;
-- error 2D000: invalid transaction termination

/* extensions V013-05 */
ABORT;
-- error 2D000: invalid transaction termination

-- # A whole transaction with only the aliases.
/* extensions V013-01 V013-03 V013-05 */
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
/* extensions V013-01 */
BEGIN;
-- flags: T241, V013-01
-- msg: START TRANSACTION

/* flags */
/* extensions V013-02 */
START TRANSACTION;
COMMIT TRANSACTION;
-- flags: T241
-- msg: START TRANSACTION
-- flags: V013-02
-- msg: COMMIT

/* flags */
/* extensions V013-03 */
START TRANSACTION;
END;
-- flags: T241
-- msg: START TRANSACTION
-- flags: V013-03
-- msg: COMMIT

/* flags */
/* extensions V013-04 */
START TRANSACTION;
ROLLBACK TRANSACTION;
-- flags: T241
-- msg: START TRANSACTION
-- flags: V013-04
-- msg: ROLLBACK

/* flags */
/* extensions V013-05 */
START TRANSACTION;
ABORT;
-- flags: T241
-- msg: START TRANSACTION
-- flags: V013-05
-- msg: ROLLBACK
