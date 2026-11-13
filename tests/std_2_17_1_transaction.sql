-- # A transaction ends with COMMIT or ROLLBACK. START TRANSACTION while one is
-- # active is 25001 (General Rules, 1). COMMIT or ROLLBACK without an active
-- # transaction does nothing, because a statement outside of START TRANSACTION
-- # is committed on its own, so there's nothing left to end.
START TRANSACTION;
COMMIT;
-- msg: START TRANSACTION
-- msg: COMMIT

START TRANSACTION;
ROLLBACK;
-- msg: START TRANSACTION
-- msg: ROLLBACK

START TRANSACTION;
START TRANSACTION;
-- msg: START TRANSACTION
-- error 25001: invalid transaction state: active sql transaction

START TRANSACTION;
COMMIT;
COMMIT;
-- msg: START TRANSACTION
-- msg: COMMIT
-- msg: COMMIT

-- # Outside of a transaction, COMMIT and ROLLBACK succeed and do nothing. The
-- # standard only uses 2D000 (invalid transaction termination) for transactions
-- # managed outside of the database.
COMMIT;
-- msg: COMMIT

START TRANSACTION;
COMMIT;
ROLLBACK;
-- msg: START TRANSACTION
-- msg: COMMIT
-- msg: ROLLBACK

ROLLBACK;
-- msg: ROLLBACK

-- # Changes made in a transaction are kept by COMMIT, with or without a primary
-- # key, including a row that was inserted and then updated by the same
-- # transaction. ROLLBACK cancels all of them (17.8, General Rules, 2.b).
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
START TRANSACTION;
UPDATE t SET x = 2;
COMMIT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: UPDATE 1
-- msg: COMMIT
-- X: 2

CREATE TABLE t (id INT, x INT, PRIMARY KEY (id));
INSERT INTO t (id, x) VALUES (1, 1);
START TRANSACTION;
UPDATE t SET x = 2;
COMMIT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: UPDATE 1
-- msg: COMMIT
-- ID: 1 X: 2

CREATE TABLE t (x INT);
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
UPDATE t SET x = 2;
COMMIT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: UPDATE 1
-- msg: COMMIT
-- X: 2

CREATE TABLE t (id INT, x INT, PRIMARY KEY (id));
START TRANSACTION;
INSERT INTO t (id, x) VALUES (1, 1);
UPDATE t SET x = 2;
COMMIT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: UPDATE 1
-- msg: COMMIT
-- ID: 1 X: 2

CREATE TABLE t (x INT);
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
UPDATE t SET x = 2;
ROLLBACK;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: UPDATE 1
-- msg: ROLLBACK

-- # Each connection has its own transaction. A table created by another
-- # connection is only seen once it's committed, and not at all if it's rolled
-- # back. A table dropped by a transaction is only gone for that transaction
-- # until it's committed.
/* connection 1 */
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
/* connection 2 */
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
-- 1: msg: START TRANSACTION
-- 2: msg: START TRANSACTION

-- # The same test with the default isolation level (SERIALIZABLE).
/* connection 1 */
START TRANSACTION;
/* connection 2 */
START TRANSACTION;
-- 1: msg: START TRANSACTION
-- 2: error 40001: serialization failure: another connection has a transaction that must finish first

/* connection 1 */
START TRANSACTION;
CREATE TABLE foo (bar INT);
INSERT INTO foo (bar) VALUES (123);
COMMIT;
/* connection 2 */
START TRANSACTION;
SELECT * FROM foo;
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: COMMIT
-- 2: msg: START TRANSACTION
-- 2: BAR: 123

/* connection 1 */
START TRANSACTION;
CREATE TABLE foo (bar INT);
/* connection 2 */
SELECT * FROM foo;
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE TABLE 1
-- 2: error 42P01: no such table: "test".PUBLIC.FOO

/* connection 1 */
START TRANSACTION;
CREATE TABLE foo (bar INT);
ROLLBACK;
/* connection 2 */
SELECT * FROM foo;
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE TABLE 1
-- 1: msg: ROLLBACK
-- 2: error 42P01: no such table: "test".PUBLIC.FOO

/* connection 1 */
CREATE TABLE foo (bar INT);
/* connection 2 */
START TRANSACTION;
DROP TABLE foo RESTRICT;
SELECT * FROM foo;
/* connection 1 */
SELECT * FROM foo;
-- 1: msg: CREATE TABLE 1
-- 2: msg: START TRANSACTION
-- 2: msg: DROP TABLE 1
-- 2: error 42P01: no such table: "test".PUBLIC.FOO

-- # A statement that fails only cancels its own changes (13.4, General Rules,
-- # 18.b.i), so a failed UPDATE leaves every row as it was, even the ones it
-- # got to before the error. The transaction stays active and can still be
-- # committed or rolled back with the changes of the statements that succeeded.
CREATE TABLE foo (b BOOLEAN);
INSERT INTO foo (b) VALUES (123, 456);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- error 42601: syntax error: INSERT has more values than columns

START TRANSACTION;
CREATE TABLE foo (b BOOLEAN);
INSERT INTO foo (b) VALUES (123, 456);
SELECT * FROM foo;
-- msg: START TRANSACTION
-- msg: CREATE TABLE 1
-- error 42601: syntax error: INSERT has more values than columns

CREATE TABLE t (x INT, y INT);
START TRANSACTION;
INSERT INTO t (x, y) VALUES (10, 2);
INSERT INTO t (x, y) VALUES (20, 0);
UPDATE t SET x = x / y;
INSERT INTO t (x, y) VALUES (30, 3);
COMMIT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: INSERT 1
-- error 22012: division by zero
-- msg: INSERT 1
-- msg: COMMIT
-- X: 10 Y: 2
-- X: 20 Y: 0
-- X: 30 Y: 3

CREATE TABLE t (x INT, y INT);
INSERT INTO t (x, y) VALUES (10, 2);
INSERT INTO t (x, y) VALUES (20, 0);
START TRANSACTION;
INSERT INTO t (x, y) VALUES (40, 4);
UPDATE t SET x = x / y;
ROLLBACK;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- error 22012: division by zero
-- msg: ROLLBACK
-- X: 10 Y: 2
-- X: 20 Y: 0

START TRANSACTION;
VALUES 1 / 0;
VALUES 1;
COMMIT;
-- msg: START TRANSACTION
-- error 22012: division by zero
-- COL1: 1
-- msg: COMMIT

CREATE TABLE t (x INT, y INT);
START TRANSACTION;
INSERT INTO t (x, y) VALUES (10, 2);
INSERT INTO t (x, y) VALUES (20, 0);
UPDATE t SET x = x / y;
SELECT * FROM t;
UPDATE t SET x = x + 1;
SELECT * FROM t;
ROLLBACK;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: INSERT 1
-- error 22012: division by zero
-- X: 10 Y: 2
-- X: 20 Y: 0
-- msg: UPDATE 2
-- X: 11 Y: 2
-- X: 21 Y: 0
-- msg: ROLLBACK

-- # ROLLBACK puts back every row the transaction deleted or updated, however
-- # many times, and removes a row that it inserted (even one it already
-- # deleted).
CREATE TABLE t (id INT NOT NULL, x INT, PRIMARY KEY(id));
INSERT INTO t (id, x) VALUES (1, 10);
START TRANSACTION;
DELETE FROM t WHERE id = 1;
SELECT * FROM t;
ROLLBACK;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: DELETE 1
-- msg: ROLLBACK
-- ID: 1 X: 10

CREATE TABLE t (id INT NOT NULL, x INT, PRIMARY KEY(id));
INSERT INTO t (id, x) VALUES (1, 10);
START TRANSACTION;
UPDATE t SET x = 99 WHERE id = 1;
UPDATE t SET x = 100 WHERE id = 1;
SELECT * FROM t;
ROLLBACK;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: UPDATE 1
-- msg: UPDATE 1
-- ID: 1 X: 100
-- msg: ROLLBACK
-- ID: 1 X: 10

CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (10);
INSERT INTO t (x) VALUES (20);
START TRANSACTION;
UPDATE t SET x = 99 WHERE x = 10;
DELETE FROM t WHERE x = 20;
INSERT INTO t (x) VALUES (30);
DELETE FROM t WHERE x = 30;
ROLLBACK;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: UPDATE 1
-- msg: DELETE 1
-- msg: INSERT 1
-- msg: DELETE 1
-- msg: ROLLBACK
-- X: 10
-- X: 20

-- # Changes to schemas are canceled by ROLLBACK too (17.8, General Rules, 2.b):
-- # a table or schema that was created is gone (so it can be created again),
-- # and one that was dropped is back with its rows.
START TRANSACTION;
CREATE TABLE t (x INT);
ROLLBACK;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: CREATE TABLE 1
-- msg: ROLLBACK
-- error 42P01: no such table: ":memory:".PUBLIC.T

START TRANSACTION;
CREATE SCHEMA s;
ROLLBACK;
CREATE SCHEMA s;
-- msg: START TRANSACTION
-- msg: CREATE SCHEMA 1
-- msg: ROLLBACK
-- msg: CREATE SCHEMA 1

CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
START TRANSACTION;
DROP TABLE t RESTRICT;
ROLLBACK;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: DROP TABLE 1
-- msg: ROLLBACK
-- X: 1

CREATE SCHEMA s;
CREATE TABLE s.t (x INT);
INSERT INTO s.t (x) VALUES (1);
START TRANSACTION;
DROP SCHEMA s CASCADE;
ROLLBACK;
SELECT * FROM s.t;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: DROP SCHEMA 1
-- msg: ROLLBACK
-- X: 1

-- # WORK is optional and doesn't change anything.
START TRANSACTION;
COMMIT WORK;
-- msg: START TRANSACTION
-- msg: COMMIT

START TRANSACTION;
ROLLBACK WORK;
-- msg: START TRANSACTION
-- msg: ROLLBACK
