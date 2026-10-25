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

/* connection 1 */
START TRANSACTION;
CREATE TABLE u (a INT);
/* connection 2 */
SELECT * FROM u;
/* connection 1 */
COMMIT;
/* connection 2 */
SELECT * FROM u;
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE TABLE 1
-- 2: error 42P01: no such table: "test".PUBLIC.U
-- 1: msg: COMMIT

/* connection 1 */
CREATE TABLE u (a INT);
INSERT INTO u (a) VALUES (1);
START TRANSACTION;
ALTER TABLE u ADD COLUMN b INT;
/* connection 2 */
SELECT * FROM u;
/* connection 1 */
COMMIT;
/* connection 2 */
SELECT * FROM u;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: msg: ALTER TABLE 1
-- 2: A: 1
-- 1: msg: COMMIT
-- 2: A: 1 B: NULL
