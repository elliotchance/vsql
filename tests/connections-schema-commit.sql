/* connection 1 */
CREATE TABLE bar (x INT);
START TRANSACTION;
CREATE TABLE foo (x INT);
/* connection 2 */
SELECT * FROM bar;
/* connection 1 */
COMMIT;
/* connection 2 */
SELECT * FROM foo;
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE TABLE 1
-- 1: msg: COMMIT

/* connection 1 */
CREATE TABLE bar (x INT);
CREATE TABLE foo (x INT);
START TRANSACTION;
DROP TABLE foo;
/* connection 2 */
SELECT * FROM bar;
/* connection 1 */
COMMIT;
/* connection 2 */
SELECT * FROM foo;
-- 1: msg: CREATE TABLE 1
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 1: msg: DROP TABLE 1
-- 1: msg: COMMIT
-- 2: error 42P01: no such table: "test".PUBLIC.FOO

/* connection 1 */
CREATE TABLE bar (x INT);
START TRANSACTION;
CREATE SCHEMA s;
/* connection 2 */
SELECT * FROM bar;
/* connection 1 */
COMMIT;
/* connection 2 */
CREATE TABLE s.t (x INT);
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE SCHEMA 1
-- 1: msg: COMMIT
-- 2: msg: CREATE TABLE 1
