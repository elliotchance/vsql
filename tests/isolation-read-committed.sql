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

/* connection 1 */
CREATE TABLE foo (bar INT);
INSERT INTO foo (bar) VALUES (123);
START TRANSACTION;
UPDATE foo SET bar = 456;
SELECT * FROM foo;
/* connection 2 */
START TRANSACTION;
UPDATE foo SET bar = 789;
SELECT * FROM foo;
/* connection 1 */
SELECT * FROM foo;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: msg: UPDATE 1
-- 1: BAR: 456
-- 2: msg: START TRANSACTION
-- 2: error 40001: serialization failure: avoiding concurrent write on individual row
-- 2: BAR: 123
-- 1: BAR: 456

/* connection 1 */
CREATE TABLE foo (bar INT);
INSERT INTO foo (bar) VALUES (123);
START TRANSACTION;
UPDATE foo SET bar = 456;
UPDATE foo SET bar = 789;
UPDATE foo SET bar = 234;
SELECT * FROM foo;
/* connection 2 */
START TRANSACTION;
UPDATE foo SET bar = 345;
SELECT * FROM foo;
/* connection 1 */
SELECT * FROM foo;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: msg: UPDATE 1
-- 1: msg: UPDATE 1
-- 1: msg: UPDATE 1
-- 1: BAR: 234
-- 2: msg: START TRANSACTION
-- 2: error 40001: serialization failure: avoiding concurrent write on individual row
-- 2: BAR: 123
-- 1: BAR: 234

/* connection 1 */
CREATE TABLE foo (bar INT);
INSERT INTO foo (bar) VALUES (123);
START TRANSACTION;
DELETE FROM foo;
/* connection 2 */
SELECT * FROM foo;
/* connection 1 */
ROLLBACK;
/* connection 2 */
SELECT * FROM foo;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: msg: DELETE 1
-- 2: BAR: 123
-- 1: msg: ROLLBACK
-- 2: BAR: 123

/* connection 1 */
CREATE TABLE foo (bar INT);
/* connection 2 */
SELECT * FROM foo;
/* connection 1 */
START TRANSACTION;
DROP TABLE foo;
CREATE TABLE baz (x INT);
ROLLBACK;
SELECT * FROM foo;
SELECT * FROM baz;
/* connection 2 */
SELECT * FROM foo;
SELECT * FROM baz;
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 1: msg: DROP TABLE 1
-- 1: msg: CREATE TABLE 1
-- 1: msg: ROLLBACK
-- 1: error 42P01: no such table: "test".PUBLIC.BAZ
-- 2: error 42P01: no such table: "test".PUBLIC.BAZ

/* connection 1 */
CREATE TABLE foo (bar INT);
INSERT INTO foo (bar) VALUES (123);
START TRANSACTION;
SELECT * FROM foo;
/* connection 2 */
START TRANSACTION;
DELETE FROM foo;
/* connection 1 */
DELETE FROM foo;
/* connection 2 */
COMMIT;
/* connection 1 */
SELECT * FROM foo;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: BAR: 123
-- 2: msg: START TRANSACTION
-- 2: msg: DELETE 1
-- 1: error 40001: serialization failure: avoiding concurrent write on individual row
-- 2: msg: COMMIT

/* connection 1 */
CREATE TABLE foo (bar INT);
INSERT INTO foo (bar) VALUES (123);
/* connection 2 */
START TRANSACTION;
DELETE FROM foo;
/* connection 1 */
START TRANSACTION;
UPDATE foo SET bar = 456;
/* connection 2 */
ROLLBACK;
/* connection 1 */
SELECT * FROM foo;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 2: msg: START TRANSACTION
-- 2: msg: DELETE 1
-- 1: msg: START TRANSACTION
-- 1: error 40001: serialization failure: avoiding concurrent write on individual row
-- 2: msg: ROLLBACK
-- 1: BAR: 123

/* connection 1 */
CREATE TABLE foo (bar INT);
INSERT INTO foo (bar) VALUES (123);
/* connection 2 */
START TRANSACTION;
UPDATE foo SET bar = 456;
/* connection 1 */
START TRANSACTION;
DELETE FROM foo;
/* connection 2 */
COMMIT;
/* connection 1 */
SELECT * FROM foo;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 2: msg: START TRANSACTION
-- 2: msg: UPDATE 1
-- 1: msg: START TRANSACTION
-- 1: error 40001: serialization failure: avoiding concurrent write on individual row
-- 2: msg: COMMIT
-- 1: BAR: 456
