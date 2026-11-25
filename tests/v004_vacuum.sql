-- # VACUUM is a vsql extension (V004-01) that rebuilds the database file, so
-- # that it's as small as it can be. Every row, index and large value is kept.
-- # The result has the number of pages before, and how many were removed.

/* setup */
CREATE TABLE t (id INT PRIMARY KEY, x VARCHAR(20), c CLOB);
INSERT INTO t (id, x, c) VALUES (1, 'a', REPEAT('abc', 20000)), (2, 'b', 'small'), (3, 'c', NULL);
DELETE FROM t WHERE id = 3;

/* extensions V004-01 */
/* flags */
VACUUM;
-- flags: V004-01
-- msg: VACUUM 502 0

-- # The pages of the rows that are deleted are removed, so the next VACUUM
-- # has nothing to remove.
/* extensions V004-01 */
INSERT INTO t (id, x) VALUES (11, 'row'), (12, 'row'), (13, 'row'), (14, 'row'), (15, 'row'), (16, 'row'), (17, 'row'), (18, 'row'), (19, 'row'), (20, 'row'), (21, 'row'), (22, 'row'), (23, 'row'), (24, 'row'), (25, 'row'), (26, 'row'), (27, 'row'), (28, 'row'), (29, 'row'), (30, 'row');
DELETE FROM t WHERE x = 'row' AND MOD(id, 4) <> 0;
VACUUM;
VACUUM;
SELECT COUNT(*) FROM t;
-- msg: INSERT 20
-- msg: DELETE 15
-- msg: VACUUM 509 4
-- msg: VACUUM 505 0
-- COL1: 7

/* extensions V002-01 V004-01 */
CREATE INDEX t_x ON t (x);
VACUUM;
SELECT id, x, CHAR_LENGTH(c), SUBSTRING(c FROM 59998) FROM t WHERE x >= 'a';
INSERT INTO t (id, x, c) VALUES (3, 'c', REPEAT('xyz', 20000));
SELECT id, CHAR_LENGTH(c) FROM t;
-- msg: CREATE INDEX 1
-- msg: VACUUM 503 0
-- ID: 1 X: a COL3: 60000 COL4: abc
-- ID: 2 X: b COL3: 5 COL4:
-- msg: INSERT 1
-- ID: 1 COL2: 60000
-- ID: 2 COL2: 5
-- ID: 3 COL2: 60000

-- # The pages replace every page of the file, so it can't be part of a
-- # transaction.
/* extensions V004-01 */
START TRANSACTION;
VACUUM;
ROLLBACK;
-- msg: START TRANSACTION
-- error 25001: invalid transaction state: active sql transaction
-- msg: ROLLBACK

-- # It can't be used while another connection has a transaction, which may
-- # have changes that it hasn't committed.
/* extensions V004-01 */
/* connection 1 */
CREATE TABLE u (id INT);
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
INSERT INTO u (id) VALUES (1);
/* connection 2 */
VACUUM;
/* connection 1 */
COMMIT;
/* connection 2 */
VACUUM;
SELECT id FROM u;
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 1: msg: INSERT 1
-- 2: error 40001: serialization failure: cannot VACUUM while another connection has a transaction
-- 1: msg: COMMIT
-- 2: msg: VACUUM 1 0
-- 2: ID: 1

/* extensions V004-01 */
EXPLAIN VACUUM;
-- error 42601: syntax error: Cannot EXPLAIN VACUUM

-- # VACUUM isn't a reserved word.
CREATE TABLE vacuum (vacuum INT);
INSERT INTO vacuum (vacuum) VALUES (1);
SELECT vacuum FROM vacuum;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- VACUUM: 1
