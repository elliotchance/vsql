/* connection 1 */
CREATE TABLE foo (bar INT);
START TRANSACTION;
INSERT INTO foo (bar) VALUES (123);
COMMIT;
/* connection 2 */
INSERT INTO foo (bar) VALUES (456);
SELECT * FROM foo;
/* connection 1 */
SELECT * FROM foo;
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 1: msg: INSERT 1
-- 1: msg: COMMIT
-- 2: msg: INSERT 1
-- 2: BAR: 123
-- 2: BAR: 456
-- 1: BAR: 123
-- 1: BAR: 456

/* connection 1 */
CREATE TABLE foo (bar INT);
START TRANSACTION;
INSERT INTO foo (bar) VALUES (123);
ROLLBACK;
/* connection 2 */
INSERT INTO foo (bar) VALUES (456);
SELECT * FROM foo;
/* connection 1 */
SELECT * FROM foo;
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 1: msg: INSERT 1
-- 1: msg: ROLLBACK
-- 2: msg: INSERT 1
-- 2: BAR: 456
-- 1: BAR: 456

/* connection 1 */
CREATE TABLE foo (bar INT);
START TRANSACTION;
INSERT INTO foo (bar) VALUES (123);
/* connection 2 */
INSERT INTO foo (bar) VALUES (456);
SELECT * FROM foo;
/* connection 1 */
SELECT * FROM foo;
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 1: msg: INSERT 1
-- 2: msg: INSERT 1
-- 2: BAR: 456
-- 1: BAR: 123
-- 1: BAR: 456

/* connection 1 */
CREATE TABLE foo (bar INT);
START TRANSACTION;
INSERT INTO foo (bar) VALUES (123);
COMMIT;
/* connection 2 */
DELETE FROM foo WHERE bar = 123;
SELECT * FROM foo;
/* connection 1 */
SELECT * FROM foo;
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 1: msg: INSERT 1
-- 1: msg: COMMIT
-- 2: msg: DELETE 1

/* connection 1 */
CREATE TABLE foo (bar INT);
START TRANSACTION;
INSERT INTO foo (bar) VALUES (123);
ROLLBACK;
/* connection 2 */
DELETE FROM foo WHERE bar = 123;
SELECT * FROM foo;
/* connection 1 */
SELECT * FROM foo;
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 1: msg: INSERT 1
-- 1: msg: ROLLBACK
-- 2: msg: DELETE 0

/* connection 1 */
CREATE TABLE foo (bar INT);
START TRANSACTION;
INSERT INTO foo (bar) VALUES (123);
/* connection 2 */
DELETE FROM foo WHERE bar = 123;
SELECT * FROM foo;
/* connection 1 */
SELECT * FROM foo;
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 1: msg: INSERT 1
-- 2: msg: DELETE 0
-- 1: BAR: 123

/* connection 1 */
CREATE TABLE foo (bar INT);
START TRANSACTION;
INSERT INTO foo (bar) VALUES (123);
COMMIT;
/* connection 2 */
UPDATE foo SET bar = 456 WHERE bar = 123;
SELECT * FROM foo;
/* connection 1 */
SELECT * FROM foo;
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 1: msg: INSERT 1
-- 1: msg: COMMIT
-- 2: msg: UPDATE 1
-- 2: BAR: 456
-- 1: BAR: 456

/* connection 1 */
CREATE TABLE foo (bar INT);
START TRANSACTION;
INSERT INTO foo (bar) VALUES (123);
ROLLBACK;
/* connection 2 */
UPDATE foo SET bar = 456 WHERE bar = 123;
SELECT * FROM foo;
/* connection 1 */
SELECT * FROM foo;
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 1: msg: INSERT 1
-- 1: msg: ROLLBACK
-- 2: msg: UPDATE 0

/* connection 1 */
CREATE TABLE foo (bar INT);
START TRANSACTION;
INSERT INTO foo (bar) VALUES (123);
/* connection 2 */
UPDATE foo SET bar = 456 WHERE bar = 123;
SELECT * FROM foo;
/* connection 1 */
SELECT * FROM foo;
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 1: msg: INSERT 1
-- 2: msg: UPDATE 0
-- 1: BAR: 123
