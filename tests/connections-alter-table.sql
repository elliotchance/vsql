/* connection 1 */
CREATE TABLE t (a INT);
START TRANSACTION;
ALTER TABLE t ADD COLUMN b INT DEFAULT 2 NOT NULL;
/* connection 2 */
INSERT INTO t (a) VALUES (5);
/* connection 1 */
COMMIT;
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 1: msg: ALTER TABLE 1
-- 2: error 40001: serialization failure: avoiding concurrent write on table definition
-- 1: msg: COMMIT

/* connection 1 */
CREATE TABLE t (a INT);
INSERT INTO t (a) VALUES (1);
/* connection 2 */
START TRANSACTION;
INSERT INTO t (a) VALUES (5);
/* connection 1 */
ALTER TABLE t ADD COLUMN b INT DEFAULT 2 NOT NULL;
/* connection 2 */
COMMIT;
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 2: msg: START TRANSACTION
-- 2: msg: INSERT 1
-- 1: error 40001: serialization failure: avoiding concurrent write on table definition
-- 2: msg: COMMIT
-- 2: A: 1
-- 2: A: 5

/* connection 1 */
CREATE TABLE t (a INT);
INSERT INTO t (a) VALUES (1);
START TRANSACTION;
ALTER TABLE t ADD COLUMN b INT DEFAULT 2;
/* connection 2 */
UPDATE t SET a = 2;
DELETE FROM t;
/* connection 1 */
COMMIT;
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: msg: ALTER TABLE 1
-- 2: error 40001: serialization failure: avoiding concurrent write on table definition
-- 2: error 40001: serialization failure: avoiding concurrent write on table definition
-- 1: msg: COMMIT
-- 1: A: 1 B: 2

/* connection 1 */
CREATE TABLE t (a INT);
START TRANSACTION;
DROP TABLE t;
/* connection 2 */
INSERT INTO t (a) VALUES (5);
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 1: msg: DROP TABLE 1
-- 2: error 40001: serialization failure: avoiding concurrent write on table definition

/* connection 1 */
CREATE TABLE t (a INT);
/* connection 2 */
START TRANSACTION;
INSERT INTO t (a) VALUES (5);
/* connection 1 */
DROP TABLE t;
-- 1: msg: CREATE TABLE 1
-- 2: msg: START TRANSACTION
-- 2: msg: INSERT 1
-- 1: error 40001: serialization failure: avoiding concurrent write on table definition
