-- # A transaction can run SQL-schema statements and SQL-data statements
-- # (T670, 4.43.1 and General Rules, 11.a), rather than raising 25007.
CREATE TABLE t (x INT);
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
ALTER TABLE t ADD COLUMN y INT;
INSERT INTO t (x, y) VALUES (2, 3);
CREATE TABLE u (z INT);
INSERT INTO u (z) SELECT x FROM t;
SELECT * FROM t;
SELECT * FROM u;
ROLLBACK;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: ALTER TABLE 1
-- msg: INSERT 1
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- X: 1 Y: NULL
-- X: 2 Y: 3
-- Z: 1
-- Z: 2
-- msg: ROLLBACK

-- # The effect on an open cursor is implementation-defined (General Rules, 11):
-- # it keeps the rows it had when it was opened, even when its table is
-- # changed or dropped.
/* extensions V108-01 V109-01 V110-01 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1), (2), (3);
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM t;
OPEN c;
FETCH c;
ALTER TABLE t ADD COLUMN y INT;
FETCH c;
DROP TABLE t RESTRICT;
FETCH c;
COMMIT;
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1
-- msg: ALTER TABLE 1
-- X: 2
-- msg: DROP TABLE 1
-- X: 3
-- msg: COMMIT

-- # So is the effect on a deferred constraint: one that's dropped isn't checked
-- # when the transaction ends.
CREATE TABLE u (x INT, CONSTRAINT k CHECK (x > 0) INITIALLY DEFERRED);
START TRANSACTION;
INSERT INTO u (x) VALUES (-1);
ALTER TABLE u DROP CONSTRAINT k RESTRICT;
COMMIT;
SELECT * FROM u;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: ALTER TABLE 1
-- msg: COMMIT
-- X: -1
