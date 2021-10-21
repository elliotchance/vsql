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
-- 2: error 42P01: no such table: FOO

/* connection 1 */
START TRANSACTION;
CREATE TABLE foo (bar INT);
ROLLBACK;
/* connection 2 */
SELECT * FROM foo;
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE TABLE 1
-- 1: msg: ROLLBACK
-- 2: error 42P01: no such table: FOO

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
-- 2: error 42P01: no such table: FOO
