-- # COMMIT TRANSACTION (V115-01) and END (V115-02) are vsql extensions for
-- # COMMIT.

/* setup */
CREATE TABLE t (x INT);

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

-- # Like COMMIT, they do nothing when there's no transaction to end.
/* extensions V115-01 */
COMMIT TRANSACTION;
-- msg: COMMIT

/* extensions V115-02 */
END;
-- msg: COMMIT

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

-- # END is a reserved word, so it can't be a column name (5.2, Syntax
-- # Rules, 26). Only TRANSACTION or WORK can follow END, and ROW can't follow
-- # COMMIT.
SELECT end FROM t;
-- error 42601: syntax error: unexpected END at line 1, column 8 near "SELECT end FROM"; hint: END is a reserved word, so it must be quoted to be used as a name, such as "END" (see https://vsql.readthedocs.io/en/latest/keywords.html)

END ROW;
-- error 42601: syntax error: unexpected ROW at line 1, column 5 near "END ROW"

COMMIT ROW;
-- error 42601: syntax error: unexpected ROW at line 1, column 8 near "COMMIT ROW"

-- # The flagger: START TRANSACTION is T241, and the alias is flagged on the
-- # statement that uses it.
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
