CREATE TABLE t (a INT, PRIMARY KEY (a));
INSERT INTO t (a) VALUES (1);
INSERT INTO t (a) VALUES (2);
INSERT INTO t (a) VALUES (10);
UPDATE t SET a = a + 8;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T
-- A: 1
-- A: 2
-- A: 10

CREATE TABLE t (x INT, y INT);
INSERT INTO t (x, y) VALUES (10, 2);
INSERT INTO t (x, y) VALUES (20, 0);
UPDATE t SET x = x / y;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- error 22012: division by zero
-- X: 10 Y: 2
-- X: 20 Y: 0

CREATE SEQUENCE s START WITH 10;
CREATE TABLE t (x INT, y INT);
INSERT INTO t (x, y) VALUES (1, 1);
INSERT INTO t (x, y) VALUES (2, 0);
UPDATE t SET x = NEXT VALUE FOR s / y;
SELECT * FROM t;
VALUES NEXT VALUE FOR s;
-- msg: CREATE SEQUENCE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- error 22012: division by zero
-- X: 1 Y: 1
-- X: 2 Y: 0
-- COL1: 12

/* connection 1 */
CREATE TABLE t (x INT, y INT);
INSERT INTO t (x, y) VALUES (10, 2);
INSERT INTO t (x, y) VALUES (20, 0);
UPDATE t SET x = x / y;
/* connection 2 */
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: INSERT 1
-- 1: error 22012: division by zero
-- 2: X: 10 Y: 2
-- 2: X: 20 Y: 0
