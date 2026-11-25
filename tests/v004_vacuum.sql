-- # VACUUM is a vsql extension (V004-01) that makes the database file smaller.
-- # By default (COMPACT) it packs the pages of the B-tree, and moves pages from
-- # the end of the file into the free pages. Every row, index and large value is
-- # kept. The result has the number of pages that were read, and how many were
-- # removed from the file. See v004_vacuum_options.sql for the other options.

/* setup */
CREATE TABLE t (id INT PRIMARY KEY, x VARCHAR(20), c CLOB);
INSERT INTO t (id, x, c) VALUES (1, 'a', REPEAT('abc', 20000)), (2, 'b', 'small'), (3, 'c', NULL);
DELETE FROM t WHERE id = 3;

/* extensions V004-01 */
/* flags */
VACUUM;
-- flags: V004-01
-- msg: VACUUM 477 1

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
-- msg: VACUUM 485 3
-- msg: VACUUM 480 0
-- COL1: 7

/* extensions V002-01 V004-01 */
CREATE INDEX t_x ON t (x);
VACUUM;
SELECT id, x, CHAR_LENGTH(c), SUBSTRING(c FROM 59998) FROM t WHERE x >= 'a';
INSERT INTO t (id, x, c) VALUES (3, 'c', REPEAT('xyz', 20000));
SELECT id, CHAR_LENGTH(c) FROM t;
-- msg: CREATE INDEX 1
-- msg: VACUUM 479 0
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

-- # It can be used while another connection has a transaction, such as on a
-- # server that doesn't stop. The rows that the transaction added or deleted,
-- # and hasn't committed, are kept as they are, so it can still commit them.
/* extensions V004-01 */
/* connection 1 */
CREATE TABLE u (id INT PRIMARY KEY, x VARCHAR(200));
INSERT INTO u (id, x) VALUES (1, 'a'), (2, 'b'), (3, 'c');
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
INSERT INTO u (id, x) VALUES (11, REPEAT('x', 200)), (12, REPEAT('x', 200)), (13, REPEAT('x', 200)), (14, REPEAT('x', 200)), (15, REPEAT('x', 200)), (16, REPEAT('x', 200)), (17, REPEAT('x', 200)), (18, REPEAT('x', 200)), (19, REPEAT('x', 200)), (20, REPEAT('x', 200)), (21, REPEAT('x', 200)), (22, REPEAT('x', 200)), (23, REPEAT('x', 200)), (24, REPEAT('x', 200)), (25, REPEAT('x', 200)), (26, REPEAT('x', 200)), (27, REPEAT('x', 200)), (28, REPEAT('x', 200)), (29, REPEAT('x', 200)), (30, REPEAT('x', 200)), (31, REPEAT('x', 200)), (32, REPEAT('x', 200)), (33, REPEAT('x', 200)), (34, REPEAT('x', 200)), (35, REPEAT('x', 200)), (36, REPEAT('x', 200)), (37, REPEAT('x', 200)), (38, REPEAT('x', 200)), (39, REPEAT('x', 200)), (40, REPEAT('x', 200)), (41, REPEAT('x', 200)), (42, REPEAT('x', 200)), (43, REPEAT('x', 200)), (44, REPEAT('x', 200)), (45, REPEAT('x', 200)), (46, REPEAT('x', 200)), (47, REPEAT('x', 200)), (48, REPEAT('x', 200)), (49, REPEAT('x', 200)), (50, REPEAT('x', 200)), (51, REPEAT('x', 200)), (52, REPEAT('x', 200)), (53, REPEAT('x', 200)), (54, REPEAT('x', 200)), (55, REPEAT('x', 200)), (56, REPEAT('x', 200)), (57, REPEAT('x', 200)), (58, REPEAT('x', 200)), (59, REPEAT('x', 200)), (60, REPEAT('x', 200)), (61, REPEAT('x', 200)), (62, REPEAT('x', 200)), (63, REPEAT('x', 200)), (64, REPEAT('x', 200)), (65, REPEAT('x', 200)), (66, REPEAT('x', 200)), (67, REPEAT('x', 200)), (68, REPEAT('x', 200)), (69, REPEAT('x', 200)), (70, REPEAT('x', 200));
DELETE FROM u WHERE id = 2;
/* connection 2 */
VACUUM;
SELECT COUNT(*) FROM u;
/* connection 1 */
SELECT COUNT(*) FROM u;
COMMIT;
/* connection 2 */
SELECT COUNT(*), MIN(id), MAX(id) FROM u;
VACUUM;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 3
-- 1: msg: START TRANSACTION
-- 1: msg: INSERT 60
-- 1: msg: DELETE 1
-- 2: msg: VACUUM 137 0
-- 2: COL1: 3
-- 1: COL1: 62
-- 1: msg: COMMIT
-- 2: COL1: 62 COL2: 1 COL3: 70
-- 2: msg: VACUUM 137 0

-- # A transaction that's rolled back after a VACUUM leaves the rows as they
-- # were.
/* extensions V004-01 */
/* connection 1 */
CREATE TABLE u (id INT PRIMARY KEY, x VARCHAR(200));
INSERT INTO u (id, x) VALUES (1, 'a'), (2, 'b'), (3, 'c'), (11, REPEAT('x', 200)), (12, REPEAT('x', 200)), (13, REPEAT('x', 200)), (14, REPEAT('x', 200)), (15, REPEAT('x', 200)), (16, REPEAT('x', 200)), (17, REPEAT('x', 200)), (18, REPEAT('x', 200)), (19, REPEAT('x', 200)), (20, REPEAT('x', 200)), (21, REPEAT('x', 200)), (22, REPEAT('x', 200)), (23, REPEAT('x', 200)), (24, REPEAT('x', 200)), (25, REPEAT('x', 200)), (26, REPEAT('x', 200)), (27, REPEAT('x', 200)), (28, REPEAT('x', 200)), (29, REPEAT('x', 200)), (30, REPEAT('x', 200)), (31, REPEAT('x', 200)), (32, REPEAT('x', 200)), (33, REPEAT('x', 200)), (34, REPEAT('x', 200)), (35, REPEAT('x', 200)), (36, REPEAT('x', 200)), (37, REPEAT('x', 200)), (38, REPEAT('x', 200)), (39, REPEAT('x', 200)), (40, REPEAT('x', 200)), (41, REPEAT('x', 200)), (42, REPEAT('x', 200)), (43, REPEAT('x', 200)), (44, REPEAT('x', 200)), (45, REPEAT('x', 200)), (46, REPEAT('x', 200)), (47, REPEAT('x', 200)), (48, REPEAT('x', 200)), (49, REPEAT('x', 200)), (50, REPEAT('x', 200)), (51, REPEAT('x', 200)), (52, REPEAT('x', 200)), (53, REPEAT('x', 200)), (54, REPEAT('x', 200)), (55, REPEAT('x', 200)), (56, REPEAT('x', 200)), (57, REPEAT('x', 200)), (58, REPEAT('x', 200)), (59, REPEAT('x', 200)), (60, REPEAT('x', 200)), (61, REPEAT('x', 200)), (62, REPEAT('x', 200)), (63, REPEAT('x', 200)), (64, REPEAT('x', 200)), (65, REPEAT('x', 200)), (66, REPEAT('x', 200)), (67, REPEAT('x', 200)), (68, REPEAT('x', 200)), (69, REPEAT('x', 200)), (70, REPEAT('x', 200));
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
DELETE FROM u WHERE id > 10;
INSERT INTO u (id, x) VALUES (100, 'new');
UPDATE u SET x = 'changed';
/* connection 2 */
VACUUM;
/* connection 1 */
ROLLBACK;
SELECT COUNT(*), MAX(id) FROM u;
SELECT x FROM u WHERE id = 1;
/* connection 2 */
VACUUM;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 63
-- 1: msg: START TRANSACTION
-- 1: msg: DELETE 60
-- 1: msg: INSERT 1
-- 1: msg: UPDATE 4
-- 2: msg: VACUUM 139 0
-- 1: msg: ROLLBACK
-- 1: COL1: 63 COL2: 70
-- 1: X: a
-- 2: msg: VACUUM 139 1

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
