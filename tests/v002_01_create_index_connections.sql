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
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
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

-- # The same test with the default isolation level (SERIALIZABLE).
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
-- 1: error 40001: serialization failure: cannot commit while another connection has a SERIALIZABLE transaction
-- 2: msg: INSERT 1
-- 2: msg: COMMIT

-- # Another transaction can't change the table while an index that it can't see
-- # is being created or dropped.
/* extensions V002-01 */
/* connection 1 */
CREATE TABLE t (a INT);
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
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

-- # The same test with the default isolation level (SERIALIZABLE).
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
-- 2: error 40001: serialization failure: another connection has a transaction that must finish first
-- 1: msg: COMMIT
-- 2: msg: INSERT 1
-- 2: msg: UPDATE 1

/* extensions V002-01 V003-01 */
/* connection 1 */
CREATE TABLE t (a INT);
INSERT INTO t (a) VALUES (1);
CREATE INDEX t_a ON t (a);
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
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

-- # The same test with the default isolation level (SERIALIZABLE).
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
-- 2: error 40001: serialization failure: another connection has a transaction that must finish first
-- 2: error 40001: serialization failure: another connection has a transaction that must finish first
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

-- # An index only finds the versions of the rows that are visible. Another
-- # transaction's uncommitted changes (and its uncommitted index) aren't.
/* extensions V002-01 */
/* connection 1 */
CREATE TABLE t (id INT PRIMARY KEY, a INT);
INSERT INTO t (id, a) VALUES (1, 10), (2, 20), (3, 30);
CREATE INDEX t_a ON t (a);
/* connection 2 */
START TRANSACTION;
UPDATE t SET a = 25 WHERE a = 10;
DELETE FROM t WHERE a = 30;
INSERT INTO t (id, a) VALUES (4, 5);
SELECT * FROM t WHERE a < 100;
/* connection 1 */
SELECT * FROM t WHERE a < 100;
SELECT * FROM t WHERE a = 25;
/* connection 2 */
COMMIT;
/* connection 1 */
SELECT * FROM t WHERE a < 100;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 3
-- 1: msg: CREATE INDEX 1
-- 2: msg: START TRANSACTION
-- 2: msg: UPDATE 1
-- 2: msg: DELETE 1
-- 2: msg: INSERT 1
-- 2: ID: 4 A: 5
-- 2: ID: 2 A: 20
-- 2: ID: 1 A: 25
-- 1: ID: 1 A: 10
-- 1: ID: 2 A: 20
-- 1: ID: 3 A: 30
-- 2: msg: COMMIT
-- 1: ID: 4 A: 5
-- 1: ID: 2 A: 20
-- 1: ID: 1 A: 25

/* extensions V001-01 V002-01 */
/* connection 1 */
CREATE TABLE t (id INT PRIMARY KEY, a INT);
INSERT INTO t (id, a) VALUES (1, 10);
/* connection 2 */
START TRANSACTION;
CREATE INDEX t_a ON t (a);
EXPLAIN SELECT id FROM t WHERE a = 10;
/* connection 1 */
EXPLAIN SELECT id FROM t WHERE a = 10;
SELECT * FROM t WHERE a = 10;
/* connection 2 */
COMMIT;
/* connection 1 */
EXPLAIN SELECT id FROM t WHERE a = 10;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 2: msg: START TRANSACTION
-- 2: msg: CREATE INDEX 1
-- 2: EXPLAIN: INDEX "test".PUBLIC.T_A ON "test".PUBLIC.T (ID INTEGER NOT NULL, A INTEGER) RANGE A = 10
-- 2: EXPLAIN: EXPR (ID INTEGER NOT NULL)
-- 1: EXPLAIN: TABLE "test".PUBLIC.T (ID INTEGER NOT NULL, A INTEGER)
-- 1: EXPLAIN: WHERE A = 10
-- 1: EXPLAIN: EXPR (ID INTEGER NOT NULL)
-- 1: ID: 1 A: 10
-- 2: msg: COMMIT
-- 1: EXPLAIN: INDEX "test".PUBLIC.T_A ON "test".PUBLIC.T (ID INTEGER NOT NULL, A INTEGER) RANGE A = 10
-- 1: EXPLAIN: EXPR (ID INTEGER NOT NULL)

-- # A row with the same values as another transaction's new (or deleted) row in
-- # a UNIQUE index might be a duplicate once that transaction finishes.
/* extensions V002-01 V002-02 */
/* connection 1 */
CREATE TABLE t (a INT);
INSERT INTO t (a) VALUES (1);
CREATE UNIQUE INDEX t_a ON t (a);
/* connection 2 */
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
INSERT INTO t (a) VALUES (2);
DELETE FROM t WHERE a = 1;
/* connection 1 */
INSERT INTO t (a) VALUES (2);
INSERT INTO t (a) VALUES (1);
INSERT INTO t (a) VALUES (3);
/* connection 2 */
ROLLBACK;
/* connection 1 */
INSERT INTO t (a) VALUES (2);
INSERT INTO t (a) VALUES (1);
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: CREATE INDEX 1
-- 2: msg: START TRANSACTION
-- 2: msg: INSERT 1
-- 2: msg: DELETE 1
-- 1: error 40001: serialization failure: avoiding concurrent write on individual row
-- 1: error 40001: serialization failure: avoiding concurrent write on individual row
-- 1: msg: INSERT 1
-- 2: msg: ROLLBACK
-- 1: msg: INSERT 1
-- 1: error 23505: violates unique constraint: UNIQUE INDEX T_A on "test".PUBLIC.T
-- 1: A: 1
-- 1: A: 3
-- 1: A: 2

-- # The same test with the default isolation level (SERIALIZABLE).
/* extensions V002-01 V002-02 */
/* connection 1 */
CREATE TABLE t (a INT);
INSERT INTO t (a) VALUES (1);
CREATE UNIQUE INDEX t_a ON t (a);
/* connection 2 */
START TRANSACTION;
INSERT INTO t (a) VALUES (2);
DELETE FROM t WHERE a = 1;
/* connection 1 */
INSERT INTO t (a) VALUES (2);
INSERT INTO t (a) VALUES (1);
INSERT INTO t (a) VALUES (3);
/* connection 2 */
ROLLBACK;
/* connection 1 */
INSERT INTO t (a) VALUES (2);
INSERT INTO t (a) VALUES (1);
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: CREATE INDEX 1
-- 2: msg: START TRANSACTION
-- 2: msg: INSERT 1
-- 2: msg: DELETE 1
-- 1: error 40001: serialization failure: another connection has a transaction that must finish first
-- 1: error 40001: serialization failure: another connection has a transaction that must finish first
-- 1: error 40001: serialization failure: another connection has a transaction that must finish first
-- 2: msg: ROLLBACK
-- 1: msg: INSERT 1
-- 1: error 23505: violates unique constraint: UNIQUE INDEX T_A on "test".PUBLIC.T
-- 1: A: 1
-- 1: A: 2

-- # IF NOT EXISTS still waits, unless the index already exists (then nothing
-- # changes, so it doesn't matter what the table has).
/* extensions V002-01 V002-03 */
/* connection 1 */
CREATE TABLE t (a INT);
/* connection 2 */
START TRANSACTION;
INSERT INTO t (a) VALUES (1);
/* connection 1 */
CREATE INDEX IF NOT EXISTS t_a ON t (a);
/* connection 2 */
COMMIT;
/* connection 1 */
CREATE INDEX IF NOT EXISTS t_a ON t (a);
/* connection 2 */
START TRANSACTION;
INSERT INTO t (a) VALUES (2);
/* connection 1 */
CREATE INDEX IF NOT EXISTS t_a ON t (a);
/* connection 2 */
COMMIT;
-- 1: msg: CREATE TABLE 1
-- 2: msg: START TRANSACTION
-- 2: msg: INSERT 1
-- 1: error 55P03: cannot create index T_A while another transaction has changes to T
-- 2: msg: COMMIT
-- 1: msg: CREATE INDEX 1
-- 2: msg: START TRANSACTION
-- 2: msg: INSERT 1
-- 1: msg: CREATE INDEX 0
-- 2: msg: COMMIT
