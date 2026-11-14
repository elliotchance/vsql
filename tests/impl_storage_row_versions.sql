-- # A row that another transaction is changing can't be changed (40001), even
-- # when its page is full. The new version doesn't fit in the page, so the page
-- # is split to add it. That must not add a third version, which the split
-- # would put in a different page to the version before it. Then the old
-- # version is never found (and expired) again, so both are visible. With these
-- # pages, the first UPDATE fills the page.
/* page_size 256 */
/* connection 1 */
CREATE TABLE t (id INT, s VARCHAR(100), PRIMARY KEY (id));
INSERT INTO t (id, s) VALUES (1, 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
UPDATE t SET s = 'b' WHERE id = 1;
/* connection 2 */
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
UPDATE t SET s = 'c' WHERE id = 1;
/* connection 1 */
COMMIT;
SELECT * FROM t;
UPDATE t SET s = 'd' WHERE id = 1;
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: msg: UPDATE 1
-- 2: msg: START TRANSACTION
-- 2: error 40001: serialization failure: avoiding concurrent write on individual row
-- 1: msg: COMMIT
-- 1: ID: 1 S: b
-- 1: msg: UPDATE 1
-- 1: ID: 1 S: d

-- # The same for a transaction left behind by a connection that stopped, which
-- # can't be rolled back while another connection is open.
/* page_size 256 */
/* connection 1 */
CREATE TABLE t (id INT, s VARCHAR(100), PRIMARY KEY (id));
INSERT INTO t (id, s) VALUES (1, 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
/* connection 2 */
/* connection 3 */
/* connection 1 */
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
UPDATE t SET s = 'b' WHERE id = 1;
/* disconnect 1 */
/* connection 2 */
UPDATE t SET s = 'c' WHERE id = 1;
/* disconnect 3 */
/* connection 2 */
UPDATE t SET s = 'd' WHERE id = 1;
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: msg: UPDATE 1
-- 2: error 40001: serialization failure: avoiding concurrent write on individual row
-- 2: msg: UPDATE 1
-- 2: ID: 1 S: d

-- # A row that's deleted and added again in the same transaction (here, by
-- # changing its PRIMARY KEY and changing it back) replaces the version that
-- # the transaction deleted. That version isn't visible, but it would count as
-- # one of the two versions of the row, and removing it at COMMIT would remove
-- # the new version too, since it has the same key and transaction.
/* page_size 256 */
CREATE TABLE t (id INT, s VARCHAR(200), PRIMARY KEY (id));
INSERT INTO t (id, s) VALUES (1, 'a');
START TRANSACTION;
UPDATE t SET id = 2;
UPDATE t SET id = 1;
UPDATE t SET id = 2;
COMMIT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: UPDATE 1
-- msg: UPDATE 1
-- msg: UPDATE 1
-- msg: COMMIT
-- ID: 2 S: a

-- # The same for a row that's too big for half a page, so it's kept in blob
-- # objects, which have the same keys and transaction as the new ones.
/* page_size 256 */
CREATE TABLE t (id INT, s VARCHAR(200), PRIMARY KEY (id));
INSERT INTO t (id, s) VALUES (1, 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx');
START TRANSACTION;
UPDATE t SET id = 2;
UPDATE t SET id = 1;
UPDATE t SET id = 2;
COMMIT;
SELECT id, CHAR_LENGTH(s) FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: UPDATE 1
-- msg: UPDATE 1
-- msg: UPDATE 1
-- msg: COMMIT
-- ID: 2 COL2: 150

-- # The same when only the deleted version is in blob objects.
/* page_size 256 */
CREATE TABLE t (id INT, s VARCHAR(200), PRIMARY KEY (id));
INSERT INTO t (id, s) VALUES (1, 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx');
START TRANSACTION;
UPDATE t SET id = 2;
UPDATE t SET id = 1;
UPDATE t SET id = 2, s = 'b';
COMMIT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: UPDATE 1
-- msg: UPDATE 1
-- msg: UPDATE 1
-- msg: COMMIT
-- ID: 2 S: b
