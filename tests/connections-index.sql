-- # CREATE INDEX waits for other transactions with changes to the table to
-- # finish, because the index would be missing the rows that it can't see. The
-- # tests run their connections one statement at a time, so it can't wait for
-- # them (see sql_test_options).

/* extensions V002-01 */
/* connection 1 */
CREATE TABLE t (a INT);
INSERT INTO t (a) VALUES (1);
/* connection 2 */
START TRANSACTION;
INSERT INTO t (a) VALUES (2);
/* connection 1 */
CREATE INDEX t_a ON t (a);
/* connection 2 */
COMMIT;
/* connection 1 */
CREATE INDEX t_a ON t (a);
INSERT INTO t (a) VALUES (3);
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 2: msg: START TRANSACTION
-- 2: msg: INSERT 1
-- 1: error 55P03: cannot create index T_A while another transaction has changes to T
-- 2: msg: COMMIT
-- 1: msg: CREATE INDEX 1
-- 1: msg: INSERT 1
-- 1: A: 1
-- 1: A: 2
-- 1: A: 3

-- # Including a row that's deleted, or a change to the definition.
/* extensions V002-01 */
/* connection 1 */
CREATE TABLE t (a INT);
INSERT INTO t (a) VALUES (1);
/* connection 2 */
START TRANSACTION;
DELETE FROM t;
/* connection 1 */
CREATE INDEX t_a ON t (a);
/* connection 2 */
ROLLBACK;
START TRANSACTION;
ALTER TABLE t ADD COLUMN b INT;
/* connection 1 */
CREATE INDEX t_a ON t (a);
/* connection 2 */
COMMIT;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 2: msg: START TRANSACTION
-- 2: msg: DELETE 1
-- 1: error 55P03: cannot create index T_A while another transaction has changes to T
-- 2: msg: ROLLBACK
-- 2: msg: START TRANSACTION
-- 2: msg: ALTER TABLE 1
-- 1: error 55P03: cannot create index T_A while another transaction has changes to T
-- 2: msg: COMMIT

-- # Changes to another table don't matter.
/* extensions V002-01 */
/* connection 1 */
CREATE TABLE t (a INT);
CREATE TABLE t2 (a INT);
/* connection 2 */
START TRANSACTION;
INSERT INTO t2 (a) VALUES (2);
/* connection 1 */
CREATE INDEX t_a ON t (a);
/* connection 2 */
INSERT INTO t (a) VALUES (2);
COMMIT;
-- 1: msg: CREATE TABLE 1
-- 1: msg: CREATE TABLE 1
-- 2: msg: START TRANSACTION
-- 2: msg: INSERT 1
-- 1: msg: CREATE INDEX 1
-- 2: msg: INSERT 1
-- 2: msg: COMMIT

-- # Another transaction can't change the table while an index that it can't see
-- # is being created or dropped.
/* extensions V002-01 */
/* connection 1 */
CREATE TABLE t (a INT);
START TRANSACTION;
CREATE INDEX t_a ON t (a);
/* connection 2 */
INSERT INTO t (a) VALUES (1);
/* connection 1 */
COMMIT;
/* connection 2 */
INSERT INTO t (a) VALUES (1);
UPDATE t SET a = 2;
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE INDEX 1
-- 2: error 40001: serialization failure: avoiding concurrent write on table definition
-- 1: msg: COMMIT
-- 2: msg: INSERT 1
-- 2: msg: UPDATE 1

/* extensions V002-01 V003-01 */
/* connection 1 */
CREATE TABLE t (a INT);
INSERT INTO t (a) VALUES (1);
CREATE INDEX t_a ON t (a);
START TRANSACTION;
DROP INDEX t_a;
/* connection 2 */
UPDATE t SET a = 2;
DELETE FROM t;
/* connection 1 */
ROLLBACK;
/* connection 2 */
UPDATE t SET a = 2;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: CREATE INDEX 1
-- 1: msg: START TRANSACTION
-- 1: msg: DROP INDEX 1
-- 2: error 40001: serialization failure: avoiding concurrent write on table definition
-- 2: error 40001: serialization failure: avoiding concurrent write on table definition
-- 1: msg: ROLLBACK
-- 2: msg: UPDATE 1

-- # An index that's created by another connection is kept up to date.
/* extensions V002-01 V003-01 */
/* connection 1 */
CREATE TABLE t (a INT);
/* connection 2 */
INSERT INTO t (a) VALUES (1);
/* connection 1 */
CREATE INDEX t_a ON t (a DESC);
/* connection 2 */
INSERT INTO t (a) VALUES (2);
UPDATE t SET a = a + 10;
/* connection 1 */
DROP INDEX t_a;
/* connection 2 */
DELETE FROM t WHERE a = 11;
CREATE INDEX t_a ON t (a);
-- 1: msg: CREATE TABLE 1
-- 2: msg: INSERT 1
-- 1: msg: CREATE INDEX 1
-- 2: msg: INSERT 1
-- 2: msg: UPDATE 2
-- 1: msg: DROP INDEX 1
-- 2: msg: DELETE 1
-- 2: msg: CREATE INDEX 1
