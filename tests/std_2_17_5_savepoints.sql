-- # A savepoint undoes changes made after it, and keeps those made before it.
CREATE TABLE t (x INT);
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
SAVEPOINT s;
INSERT INTO t (x) VALUES (2);
ROLLBACK TO SAVEPOINT s;
INSERT INTO t (x) VALUES (3);
COMMIT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: SAVEPOINT
-- msg: INSERT 1
-- msg: ROLLBACK
-- msg: INSERT 1
-- msg: COMMIT
-- X: 1
-- X: 3

-- # A committed row that's updated and deleted after the savepoint.
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
INSERT INTO t (x) VALUES (2);
START TRANSACTION;
SAVEPOINT s;
UPDATE t SET x = 10 WHERE x = 1;
DELETE FROM t WHERE x = 2;
SELECT * FROM t;
ROLLBACK WORK TO SAVEPOINT s;
SELECT * FROM t;
COMMIT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: SAVEPOINT
-- msg: UPDATE 1
-- msg: DELETE 1
-- X: 10
-- msg: ROLLBACK
-- X: 1
-- X: 2
-- msg: COMMIT
-- X: 1
-- X: 2

-- # A row inserted before the savepoint, then updated or deleted after it.
CREATE TABLE t (x INT);
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
INSERT INTO t (x) VALUES (2);
SAVEPOINT s;
UPDATE t SET x = 10 WHERE x = 1;
DELETE FROM t WHERE x = 2;
ROLLBACK AND NO CHAIN TO SAVEPOINT s;
SELECT * FROM t;
COMMIT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: SAVEPOINT
-- msg: UPDATE 1
-- msg: DELETE 1
-- msg: ROLLBACK
-- X: 1
-- X: 2
-- msg: COMMIT
-- X: 1
-- X: 2

-- # A row updated twice, on both sides of the savepoint.
CREATE TABLE t (id INT NOT NULL, x INT, PRIMARY KEY (id));
INSERT INTO t (id, x) VALUES (1, 1);
START TRANSACTION;
UPDATE t SET x = 2;
SAVEPOINT a;
UPDATE t SET x = 3;
UPDATE t SET x = 4;
SAVEPOINT b;
UPDATE t SET x = 5;
ROLLBACK TO SAVEPOINT b;
SELECT * FROM t;
ROLLBACK TO SAVEPOINT a;
SELECT * FROM t;
COMMIT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: UPDATE 1
-- msg: SAVEPOINT
-- msg: UPDATE 1
-- msg: UPDATE 1
-- msg: SAVEPOINT
-- msg: UPDATE 1
-- msg: ROLLBACK
-- ID: 1 X: 4
-- msg: ROLLBACK
-- ID: 1 X: 2
-- msg: COMMIT
-- ID: 1 X: 2

-- # A value large enough for a blob, updated across a savepoint.
CREATE TABLE t (s VARCHAR(5000));
INSERT INTO t (s) VALUES ('xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx');
START TRANSACTION;
UPDATE t SET s = 'yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy';
SAVEPOINT s;
UPDATE t SET s = 'small';
SELECT CHARACTER_LENGTH(s) FROM t;
ROLLBACK TO SAVEPOINT s;
SELECT SUBSTRING(s FROM 1 FOR 2), CHARACTER_LENGTH(s) FROM t;
UPDATE t SET s = 'small';
ROLLBACK TO SAVEPOINT s;
SELECT SUBSTRING(s FROM 1 FOR 2), CHARACTER_LENGTH(s) FROM t;
COMMIT;
SELECT SUBSTRING(s FROM 1 FOR 2), CHARACTER_LENGTH(s) FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: UPDATE 1
-- msg: SAVEPOINT
-- msg: UPDATE 1
-- COL1: 5
-- msg: ROLLBACK
-- COL1: yy COL2: 3000
-- msg: UPDATE 1
-- msg: ROLLBACK
-- COL1: yy COL2: 3000
-- msg: COMMIT
-- COL1: yy COL2: 3000

-- # Many inserts split pages, then all of them are undone.
CREATE TABLE t (id INT NOT NULL, s VARCHAR(500), PRIMARY KEY (id));
INSERT INTO t (id, s) VALUES (1000, 'keep');
START TRANSACTION;
SAVEPOINT s;
INSERT INTO t (id, s) VALUES (0, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (1, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (2, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (3, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (4, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (5, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (6, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (7, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (8, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (9, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (10, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (11, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (12, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (13, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (14, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (15, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (16, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (17, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (18, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (19, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (20, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (21, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (22, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (23, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (24, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (25, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (26, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (27, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (28, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (29, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (30, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (31, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (32, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (33, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (34, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (35, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (36, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (37, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (38, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
INSERT INTO t (id, s) VALUES (39, 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
ROLLBACK TO SAVEPOINT s;
SELECT id, s FROM t;
INSERT INTO t (id, s) VALUES (1, 'after');
COMMIT;
SELECT id, s FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: SAVEPOINT
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: ROLLBACK
-- ID: 1000 S: keep
-- msg: INSERT 1
-- msg: COMMIT
-- ID: 1 S: after
-- ID: 1000 S: keep

/* extensions V104-01 V107-01 */
-- # Tables, schemas and sequences that are created, altered and dropped.
CREATE TABLE keep (x INT);
CREATE SEQUENCE seq1;
INSERT INTO keep (x) VALUES (1);
START TRANSACTION;
SAVEPOINT s;
CREATE TABLE t2 (x INT);
INSERT INTO t2 (x) VALUES (1);
CREATE SCHEMA s2;
CREATE SEQUENCE seq2;
ALTER TABLE keep ADD COLUMN y INT;
ALTER SEQUENCE seq1 RESTART WITH 100;
ROLLBACK TO SAVEPOINT s;
SELECT * FROM t2;
SET SCHEMA 's2';
SELECT NEXT VALUE FOR seq2 FROM keep;
SELECT * FROM keep;
SELECT NEXT VALUE FOR seq1 FROM keep;
SAVEPOINT s2;
DROP TABLE keep;
DROP SEQUENCE seq1;
SELECT * FROM keep;
ROLLBACK TO SAVEPOINT s2;
SELECT * FROM keep;
SELECT NEXT VALUE FOR seq1 FROM keep;
COMMIT;
SELECT * FROM keep;
SELECT NEXT VALUE FOR seq1 FROM keep;
CREATE TABLE t2 (x INT);
-- msg: CREATE TABLE 1
-- msg: CREATE SEQUENCE 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: SAVEPOINT
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: CREATE SCHEMA 1
-- msg: CREATE SEQUENCE 1
-- msg: ALTER TABLE 1
-- msg: ALTER SEQUENCE 1
-- msg: ROLLBACK
-- error 42P01: no such table: ":memory:".PUBLIC.T2
-- error 3F000: invalid schema name: S2
-- error 42P01: no such sequence: ":memory:".PUBLIC.SEQ2
-- X: 1
-- COL1: 1
-- msg: SAVEPOINT
-- msg: DROP TABLE 1
-- msg: DROP SEQUENCE 1
-- error 42P01: no such table: ":memory:".PUBLIC.KEEP
-- msg: ROLLBACK
-- X: 1
-- COL1: 2
-- msg: COMMIT
-- X: 1
-- COL1: 3
-- msg: CREATE TABLE 1

/* extensions V104-01 */
-- # A schema that's dropped, and a table created before the savepoint.
CREATE SCHEMA s1;
START TRANSACTION;
CREATE TABLE s1.t (x INT);
SAVEPOINT s;
DROP TABLE s1.t;
DROP SCHEMA s1 RESTRICT;
ROLLBACK TO SAVEPOINT s;
INSERT INTO s1.t (x) VALUES (1);
COMMIT;
SELECT * FROM s1.t;
-- msg: CREATE SCHEMA 1
-- msg: START TRANSACTION
-- msg: CREATE TABLE 1
-- msg: SAVEPOINT
-- msg: DROP TABLE 1
-- msg: DROP SCHEMA 1
-- msg: ROLLBACK
-- msg: INSERT 1
-- msg: COMMIT
-- X: 1

-- # A statement that fails after a savepoint hasn't changed anything, so
-- # there's nothing to undo for it.
CREATE TABLE t (id INT NOT NULL, x INT, PRIMARY KEY (id));
INSERT INTO t (id, x) VALUES (1, 1);
INSERT INTO t (id, x) VALUES (2, 2);
START TRANSACTION;
SAVEPOINT s;
INSERT INTO t (id, x) VALUES (3, 3);
UPDATE t SET x = 1 / (x - 2);
INSERT INTO t (id, x) VALUES (1, 1);
SELECT * FROM t;
ROLLBACK TO SAVEPOINT s;
SELECT * FROM t;
COMMIT;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: SAVEPOINT
-- msg: INSERT 1
-- error 22012: division by zero
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T
-- ID: 1 X: 1
-- ID: 2 X: 2
-- ID: 3 X: 3
-- msg: ROLLBACK
-- ID: 1 X: 1
-- ID: 2 X: 2
-- msg: COMMIT

-- # Nested savepoints: rolling back keeps the savepoint and destroys later ones,
-- # and releasing destroys it and the later ones.
CREATE TABLE t (x INT);
START TRANSACTION;
SAVEPOINT a;
INSERT INTO t (x) VALUES (1);
SAVEPOINT b;
INSERT INTO t (x) VALUES (2);
SAVEPOINT c;
INSERT INTO t (x) VALUES (3);
ROLLBACK TO SAVEPOINT b;
ROLLBACK TO SAVEPOINT c;
SELECT * FROM t;
ROLLBACK TO SAVEPOINT b;
INSERT INTO t (x) VALUES (4);
RELEASE SAVEPOINT b;
ROLLBACK TO SAVEPOINT b;
SELECT * FROM t;
ROLLBACK TO SAVEPOINT a;
SELECT * FROM t;
RELEASE SAVEPOINT a;
RELEASE SAVEPOINT a;
COMMIT;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: SAVEPOINT
-- msg: INSERT 1
-- msg: SAVEPOINT
-- msg: INSERT 1
-- msg: SAVEPOINT
-- msg: INSERT 1
-- msg: ROLLBACK
-- error 3B001: savepoint exception: invalid specification: C
-- X: 1
-- msg: ROLLBACK
-- msg: INSERT 1
-- msg: RELEASE SAVEPOINT
-- error 3B001: savepoint exception: invalid specification: B
-- X: 1
-- X: 4
-- msg: ROLLBACK
-- msg: RELEASE SAVEPOINT
-- error 3B001: savepoint exception: invalid specification: A
-- msg: COMMIT

-- # Using a name again only destroys the old savepoint (17.5, General Rule 2).
CREATE TABLE t (x INT);
START TRANSACTION;
SAVEPOINT a;
INSERT INTO t (x) VALUES (1);
SAVEPOINT b;
INSERT INTO t (x) VALUES (2);
SAVEPOINT a;
INSERT INTO t (x) VALUES (3);
ROLLBACK TO SAVEPOINT a;
SELECT * FROM t;
ROLLBACK TO SAVEPOINT b;
SELECT * FROM t;
ROLLBACK;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: SAVEPOINT
-- msg: INSERT 1
-- msg: SAVEPOINT
-- msg: INSERT 1
-- msg: SAVEPOINT
-- msg: INSERT 1
-- msg: ROLLBACK
-- X: 1
-- X: 2
-- msg: ROLLBACK
-- X: 1
-- msg: ROLLBACK

-- # Sequences keep advancing, because they aren't part of a transaction.
CREATE SEQUENCE seq;
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
START TRANSACTION;
SELECT NEXT VALUE FOR seq FROM t;
SAVEPOINT s;
SELECT NEXT VALUE FOR seq FROM t;
ROLLBACK TO SAVEPOINT s;
SELECT NEXT VALUE FOR seq FROM t;
COMMIT;
-- msg: CREATE SEQUENCE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- COL1: 1
-- msg: SAVEPOINT
-- COL1: 2
-- msg: ROLLBACK
-- COL1: 3
-- msg: COMMIT

-- # Every catalog is rolled back.
/* create_catalog FOO */
CREATE TABLE foo.public.bar (baz INTEGER);
CREATE TABLE t (x INT);
START TRANSACTION;
INSERT INTO foo.public.bar (baz) VALUES (1);
INSERT INTO t (x) VALUES (1);
SAVEPOINT s;
INSERT INTO foo.public.bar (baz) VALUES (2);
INSERT INTO t (x) VALUES (2);
ROLLBACK TO SAVEPOINT s;
COMMIT;
SELECT * FROM foo.public.bar;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: SAVEPOINT
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: ROLLBACK
-- msg: COMMIT
-- BAZ: 1
-- X: 1

-- # COMMIT and ROLLBACK destroy every savepoint.
START TRANSACTION;
SAVEPOINT a;
COMMIT;
START TRANSACTION;
RELEASE SAVEPOINT a;
SAVEPOINT b;
ROLLBACK;
START TRANSACTION;
ROLLBACK TO SAVEPOINT b;
SAVEPOINT c;
COMMIT AND CHAIN;
RELEASE SAVEPOINT c;
ROLLBACK;
-- msg: START TRANSACTION
-- msg: SAVEPOINT
-- msg: COMMIT
-- msg: START TRANSACTION
-- error 3B001: savepoint exception: invalid specification: A
-- msg: SAVEPOINT
-- msg: ROLLBACK
-- msg: START TRANSACTION
-- error 3B001: savepoint exception: invalid specification: B
-- msg: SAVEPOINT
-- msg: COMMIT
-- error 3B001: savepoint exception: invalid specification: C
-- msg: ROLLBACK

-- # A statement on its own is its own transaction, so a savepoint ends with it.
SAVEPOINT s;
RELEASE SAVEPOINT s;
ROLLBACK TO SAVEPOINT s;
-- msg: SAVEPOINT
-- error 3B001: savepoint exception: invalid specification: S
-- error 3B001: savepoint exception: invalid specification: S

-- # A cursor that isn't holdable is closed, and a holdable one stays open.
/* extensions V108-01 V109-01 V110-01 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
INSERT INTO t (x) VALUES (2);
START TRANSACTION;
DECLARE a CURSOR FOR SELECT * FROM t;
DECLARE b CURSOR WITH HOLD FOR SELECT * FROM t;
OPEN a;
OPEN b;
SAVEPOINT s;
ROLLBACK TO SAVEPOINT s;
FETCH NEXT FROM a;
FETCH NEXT FROM b;
COMMIT;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: DECLARE CURSOR
-- msg: OPEN
-- msg: OPEN
-- msg: SAVEPOINT
-- msg: ROLLBACK
-- error 24000: invalid cursor state: cursor A is not open
-- X: 1
-- msg: COMMIT

-- # Deferred constraints added after the savepoint aren't checked any more.
CREATE TABLE t (x INT, CONSTRAINT c UNIQUE (x) INITIALLY DEFERRED);
START TRANSACTION;
SAVEPOINT s;
INSERT INTO t (x) VALUES (1);
INSERT INTO t (x) VALUES (1);
ROLLBACK TO SAVEPOINT s;
COMMIT;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: SAVEPOINT
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: ROLLBACK
-- msg: COMMIT

-- # It works in a READ ONLY transaction, where there's nothing to undo.
START TRANSACTION READ ONLY;
SAVEPOINT s;
ROLLBACK TO SAVEPOINT s;
RELEASE SAVEPOINT s;
COMMIT;
-- msg: START TRANSACTION
-- msg: SAVEPOINT
-- msg: ROLLBACK
-- msg: RELEASE SAVEPOINT
-- msg: COMMIT

-- # Each isolation level, with another connection committing in READ COMMITTED.
/* connection 1 */
CREATE TABLE t (x INT);
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
INSERT INTO t (x) VALUES (1);
SAVEPOINT s;
INSERT INTO t (x) VALUES (2);
/* connection 2 */
INSERT INTO t (x) VALUES (3);
SELECT * FROM t;
/* connection 1 */
ROLLBACK TO SAVEPOINT s;
SELECT * FROM t;
COMMIT;
/* connection 2 */
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 1: msg: INSERT 1
-- 1: msg: SAVEPOINT
-- 1: msg: INSERT 1
-- 2: msg: INSERT 1
-- 2: X: 3
-- 1: msg: ROLLBACK
-- 1: X: 1
-- 1: X: 3
-- 1: msg: COMMIT
-- 2: X: 1
-- 2: X: 3

/* connection 1 */
CREATE TABLE t (x INT);
START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
INSERT INTO t (x) VALUES (1);
SAVEPOINT s;
INSERT INTO t (x) VALUES (2);
/* connection 2 */
INSERT INTO t (x) VALUES (3);
/* connection 1 */
ROLLBACK TO SAVEPOINT s;
SELECT * FROM t;
/* connection 2 */
INSERT INTO t (x) VALUES (3);
/* connection 1 */
COMMIT;
/* connection 2 */
INSERT INTO t (x) VALUES (3);
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 1: msg: INSERT 1
-- 1: msg: SAVEPOINT
-- 1: msg: INSERT 1
-- 2: error 40001: serialization failure: another connection has a transaction that must finish first
-- 1: msg: ROLLBACK
-- 1: X: 1
-- 2: error 40001: serialization failure: another connection has a transaction that must finish first
-- 1: msg: COMMIT
-- 2: msg: INSERT 1
-- 2: X: 1
-- 2: X: 3

-- # The names and errors.
START TRANSACTION;
SAVEPOINT "abc";
SAVEPOINT abc;
ROLLBACK TO SAVEPOINT "abc";
ROLLBACK TO SAVEPOINT abc;
ROLLBACK;
ROLLBACK AND CHAIN TO SAVEPOINT s;
ROLLBACK WORK AND CHAIN TO SAVEPOINT s;
SAVEPOINT;
RELEASE s;
ROLLBACK TO s;
EXPLAIN SAVEPOINT s;
EXPLAIN RELEASE SAVEPOINT s;
-- msg: START TRANSACTION
-- msg: SAVEPOINT
-- msg: SAVEPOINT
-- msg: ROLLBACK
-- error 3B001: savepoint exception: invalid specification: ABC
-- msg: ROLLBACK
-- error 42601: syntax error: AND CHAIN cannot be used with TO SAVEPOINT
-- error 42601: syntax error: AND CHAIN cannot be used with TO SAVEPOINT
-- error 42601: syntax error: unexpected $end at line 1, column 10 near "SAVEPOINT"
-- error 42601: syntax error: unexpected identifier at line 1, column 9 near "RELEASE s", expecting SAVEPOINT
-- error 42601: syntax error: unexpected identifier at line 1, column 13 near "ROLLBACK TO s", expecting SAVEPOINT
-- error 42601: syntax error: Cannot EXPLAIN SAVEPOINT
-- error 42601: syntax error: Cannot EXPLAIN RELEASE SAVEPOINT

/* flags */
SAVEPOINT s;
-- flags: T271
-- msg: SAVEPOINT

/* flags */
RELEASE SAVEPOINT s;
-- flags: T271
-- error 3B001: savepoint exception: invalid specification: S

/* flags */
ROLLBACK TO SAVEPOINT s;
-- flags: T271
-- error 3B001: savepoint exception: invalid specification: S

-- # A statement that can't be written doesn't lose the savepoint. A COMMIT that
-- # can't be written rolls back the SQL-transaction, which destroys it.
/* connection 1 */
CREATE TABLE t (x INT);
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
SAVEPOINT s;
INSERT INTO t (x) VALUES (1);
/* fault wal_write */
ROLLBACK TO SAVEPOINT s;
SELECT * FROM t;
ROLLBACK TO SAVEPOINT s;
SELECT * FROM t;
INSERT INTO t (x) VALUES (2);
/* fault wal_write */
INSERT INTO t (x) VALUES (3);
ROLLBACK TO SAVEPOINT s;
SELECT * FROM t;
INSERT INTO t (x) VALUES (4);
/* fault wal_write */
COMMIT;
ROLLBACK TO SAVEPOINT s;
SELECT * FROM t;
COMMIT;
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 1: msg: SAVEPOINT
-- 1: msg: INSERT 1
-- 1: error 58030: wal_write failed (fault injected by test)
-- 1: X: 1
-- 1: msg: ROLLBACK
-- 1: msg: INSERT 1
-- 1: error 58030: wal_write failed (fault injected by test)
-- 1: msg: ROLLBACK
-- 1: msg: INSERT 1
-- 1: error 40V01: transaction rollback: wal_write failed (fault injected by test)
-- 1: error 3B001: savepoint exception: invalid specification: S
-- 1: msg: COMMIT

-- # An index that's created after the savepoint is dropped again.
/* extensions V002-01 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
START TRANSACTION;
SAVEPOINT s;
CREATE INDEX ix ON t (x);
INSERT INTO t (x) VALUES (2);
ROLLBACK TO SAVEPOINT s;
CREATE INDEX ix ON t (x);
SELECT * FROM t WHERE x = 1;
COMMIT;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: SAVEPOINT
-- msg: CREATE INDEX 1
-- msg: INSERT 1
-- msg: ROLLBACK
-- msg: CREATE INDEX 1
-- X: 1
-- msg: COMMIT
