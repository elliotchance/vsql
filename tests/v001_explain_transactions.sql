-- # A statement that isn't in an SQL-transaction starts one of its own, with
-- # the characteristics of the last SET TRANSACTION (Part 2, 17.2, General
-- # Rules, 7). EXPLAIN doesn't run the statement, so it doesn't use up the SET
-- # TRANSACTION, which is still used by the next statement.
/* extensions V001-01 */
CREATE TABLE ex (a INT);
SET TRANSACTION READ ONLY;
SELECT * FROM ex;
INSERT INTO ex VALUES (1);
SET TRANSACTION READ ONLY;
EXPLAIN SELECT * FROM ex;
INSERT INTO ex VALUES (2);
-- msg: CREATE TABLE 1
-- msg: SET TRANSACTION
-- msg: INSERT 1
-- msg: SET TRANSACTION
-- EXPLAIN: TABLE ":memory:".PUBLIC.EX (A INTEGER)
-- EXPLAIN: EXPR (":memory:".PUBLIC.EX.A INTEGER)
-- error 25006: read-only sql transaction: cannot execute INSERT
