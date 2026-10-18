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
-- error 2D000: invalid transaction termination

COMMIT;
-- error 2D000: invalid transaction termination

START TRANSACTION;
COMMIT;
ROLLBACK;
-- msg: START TRANSACTION
-- msg: COMMIT
-- error 2D000: invalid transaction termination

ROLLBACK;
-- error 2D000: invalid transaction termination

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

/* connection 1 */
START TRANSACTION;
/* connection 2 */
START TRANSACTION;
-- 1: msg: START TRANSACTION
-- 2: msg: START TRANSACTION

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
DROP TABLE foo;
SELECT * FROM foo;
/* connection 1 */
SELECT * FROM foo;
-- 1: msg: CREATE TABLE 1
-- 2: msg: START TRANSACTION
-- 2: msg: DROP TABLE 1
-- 2: error 42P01: no such table: "test".PUBLIC.FOO

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
-- error 25P02: transaction is aborted, commands ignored until end of transaction block

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
DROP TABLE t;
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
