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
