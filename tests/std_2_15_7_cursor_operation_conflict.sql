/* setup */
CREATE TABLE t (x INTEGER, y INTEGER);
INSERT INTO t (x, y) VALUES (1, 10);
INSERT INTO t (x, y) VALUES (2, 20);

-- # The current row was updated by another statement. It's still updated.
/* extensions V108-01 V109-01 V110-01 V113-01 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM t;
OPEN c;
FETCH c;
UPDATE t SET y = 5 WHERE x = 1;
UPDATE t SET y = 3 WHERE CURRENT OF c;
UPDATE t SET y = 4 WHERE CURRENT OF c;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1 Y: 10
-- msg: UPDATE 1
-- warning 01001: cursor operation conflict: C
-- msg: UPDATE 1
-- warning 01001: cursor operation conflict: C
-- msg: UPDATE 1
-- X: 1 Y: 4
-- X: 2 Y: 20

-- # The current row was updated to the same values, which is still an update.
/* extensions V108-01 V109-01 V110-01 V112-01 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM t;
OPEN c;
FETCH c;
UPDATE t SET y = y WHERE x = 1;
DELETE FROM t WHERE CURRENT OF c;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1 Y: 10
-- msg: UPDATE 1
-- warning 01001: cursor operation conflict: C
-- msg: DELETE 1
-- X: 2 Y: 20

-- # The current row was deleted. Nothing is deleted, and the cursor is then
-- # before the next row, which isn't a conflict. It's not no data (02000).
/* extensions V108-01 V109-01 V110-01 V112-01 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM t;
OPEN c;
FETCH c;
DELETE FROM t WHERE x = 1;
DELETE FROM t WHERE CURRENT OF c;
DELETE FROM t WHERE CURRENT OF c;
FETCH c;
DELETE FROM t WHERE CURRENT OF c;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1 Y: 10
-- msg: DELETE 1
-- warning 01001: cursor operation conflict: C
-- msg: DELETE 0
-- error 24000: invalid cursor state: cursor C is not positioned on a row
-- X: 2 Y: 20
-- msg: DELETE 1

-- # The cursor stays on a row that was deleted when it's a positioned UPDATE, and
-- # the SET is still checked.
/* extensions V108-01 V109-01 V110-01 V113-01 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM t;
OPEN c;
FETCH c;
DELETE FROM t WHERE x = 1;
UPDATE t SET y = 3 WHERE CURRENT OF c;
UPDATE t SET y = 'a' WHERE CURRENT OF c;
UPDATE t SET y = 4 WHERE CURRENT OF c;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1 Y: 10
-- msg: DELETE 1
-- warning 01001: cursor operation conflict: C
-- msg: UPDATE 0
-- error 42846: cannot coerce CHARACTER(1) to INTEGER
-- warning 01001: cursor operation conflict: C
-- msg: UPDATE 0
-- X: 2 Y: 20

-- # Only a change to the current row, after the cursor is opened, is a conflict.
/* extensions V108-01 V109-01 V110-01 V111-01 V113-01 */
START TRANSACTION;
UPDATE t SET y = 11 WHERE x = 1;
DECLARE c CURSOR FOR SELECT * FROM t;
UPDATE t SET y = 12 WHERE x = 1;
OPEN c;
FETCH c;
UPDATE t SET y = 21 WHERE x = 2;
INSERT INTO t (x, y) VALUES (3, 30);
UPDATE t SET y = 13 WHERE CURRENT OF c;
UPDATE t SET y = y + 1 WHERE x = 1;
CLOSE c;
OPEN c;
FETCH c;
UPDATE t SET y = 15 WHERE CURRENT OF c;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: UPDATE 1
-- msg: DECLARE CURSOR
-- msg: UPDATE 1
-- msg: OPEN
-- X: 1 Y: 12
-- msg: UPDATE 1
-- msg: INSERT 1
-- msg: UPDATE 1
-- warning 01001: cursor operation conflict: C
-- msg: UPDATE 1
-- msg: CLOSE
-- msg: OPEN
-- X: 1 Y: 14
-- msg: UPDATE 1
-- X: 1 Y: 15
-- X: 2 Y: 21
-- X: 3 Y: 30

-- # A positioned statement of another cursor is a conflict, but not for a table
-- # that's different, a cursor that isn't open or one that can't change rows.
/* extensions V108-01 V109-01 V110-01 V112-01 V113-01 */
CREATE TABLE u (x INTEGER);
INSERT INTO u (x) VALUES (1);
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM t;
DECLARE d CURSOR FOR SELECT * FROM t;
DECLARE e CURSOR FOR SELECT * FROM u;
DECLARE f CURSOR FOR SELECT * FROM t;
DECLARE g CURSOR FOR SELECT * FROM t FOR READ ONLY;
OPEN c;
OPEN d;
OPEN e;
OPEN g;
FETCH c;
FETCH d;
FETCH e;
UPDATE t SET y = 3 WHERE CURRENT OF d;
UPDATE u SET x = 2 WHERE CURRENT OF e;
UPDATE t SET y = 4 WHERE CURRENT OF d;
DELETE FROM t WHERE CURRENT OF c;
DELETE FROM t WHERE CURRENT OF d;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: DECLARE CURSOR
-- msg: DECLARE CURSOR
-- msg: DECLARE CURSOR
-- msg: DECLARE CURSOR
-- msg: OPEN
-- msg: OPEN
-- msg: OPEN
-- msg: OPEN
-- X: 1 Y: 10
-- X: 1 Y: 10
-- X: 1
-- msg: UPDATE 1
-- msg: UPDATE 1
-- msg: UPDATE 1
-- warning 01001: cursor operation conflict: C
-- msg: DELETE 1
-- warning 01001: cursor operation conflict: D
-- msg: DELETE 0
-- X: 2 Y: 20

-- # A searched UPDATE or DELETE of a row changed by a positioned UPDATE, while the
-- # cursor is open.
/* extensions V108-01 V109-01 V110-01 V111-01 V113-01 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM t;
OPEN c;
FETCH c;
UPDATE t SET y = 20 WHERE x = 2;
UPDATE t SET y = 3 WHERE CURRENT OF c;
UPDATE t SET y = 21 WHERE x = 2;
UPDATE t SET y = 4 WHERE x = 1;
UPDATE t SET y = 5 WHERE CURRENT OF c;
DELETE FROM t WHERE x = 1;
CLOSE c;
INSERT INTO t (x, y) VALUES (1, 1);
DELETE FROM t WHERE x = 1;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1 Y: 10
-- msg: UPDATE 1
-- msg: UPDATE 1
-- msg: UPDATE 1
-- warning 01001: cursor operation conflict: C
-- msg: UPDATE 1
-- warning 01001: cursor operation conflict: C
-- msg: UPDATE 1
-- warning 01001: cursor operation conflict: C
-- msg: DELETE 1
-- msg: CLOSE
-- msg: INSERT 1
-- msg: DELETE 1
-- X: 2 Y: 21

-- # A row that was deleted through the cursor can't be changed again.
/* extensions V108-01 V109-01 V110-01 V112-01 */
CREATE TABLE k (x INTEGER PRIMARY KEY);
INSERT INTO k (x) VALUES (1);
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM k;
OPEN c;
FETCH c;
DELETE FROM k WHERE CURRENT OF c;
INSERT INTO k (x) VALUES (1);
DELETE FROM k WHERE x = 1;
SELECT * FROM k;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1
-- msg: DELETE 1
-- msg: INSERT 1
-- msg: DELETE 1

-- # A row with the same PRIMARY KEY isn't the row that was deleted.
/* extensions V108-01 V109-01 V110-01 V112-01 */
CREATE TABLE k (x INTEGER PRIMARY KEY, y INTEGER);
INSERT INTO k (x, y) VALUES (1, 10);
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM k;
OPEN c;
FETCH c;
DELETE FROM k WHERE x = 1;
INSERT INTO k (x, y) VALUES (1, 11);
DELETE FROM k WHERE CURRENT OF c;
SELECT * FROM k;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1 Y: 10
-- msg: DELETE 1
-- msg: INSERT 1
-- warning 01001: cursor operation conflict: C
-- msg: DELETE 0
-- X: 1 Y: 11

-- # A change to the PRIMARY KEY doesn't lose the current row, whether it's made
-- # through the cursor or not, even when two rows swap their keys.
/* extensions V108-01 V109-01 V110-01 V113-01 */
CREATE TABLE k (x INTEGER PRIMARY KEY, y INTEGER);
INSERT INTO k (x, y) VALUES (1, 10);
INSERT INTO k (x, y) VALUES (2, 20);
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM k;
OPEN c;
FETCH c;
UPDATE k SET x = 5 WHERE CURRENT OF c;
UPDATE k SET x = 1 WHERE CURRENT OF c;
UPDATE k SET x = 3 - x;
UPDATE k SET y = 11 WHERE CURRENT OF c;
SELECT * FROM k;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1 Y: 10
-- msg: UPDATE 1
-- msg: UPDATE 1
-- warning 01001: cursor operation conflict: C
-- msg: UPDATE 2
-- warning 01001: cursor operation conflict: C
-- msg: UPDATE 1
-- X: 1 Y: 20
-- X: 2 Y: 11

-- # A statement that fails doesn't change the row, so it isn't a conflict.
/* extensions V108-01 V109-01 V110-01 V113-01 */
CREATE TABLE k (x INTEGER PRIMARY KEY, y INTEGER UNIQUE);
INSERT INTO k (x, y) VALUES (1, 10);
INSERT INTO k (x, y) VALUES (2, 20);
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM k;
OPEN c;
FETCH c;
UPDATE k SET y = y / 0 WHERE x = 1;
UPDATE k SET y = 11 WHERE CURRENT OF c;
SELECT * FROM k;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1 Y: 10
-- error 22012: division by zero
-- msg: UPDATE 1
-- X: 1 Y: 11
-- X: 2 Y: 20

-- # A referential action changes the current row of a cursor.
/* extensions V108-01 V109-01 V110-01 V112-01 V113-01 */
CREATE TABLE p (id INTEGER PRIMARY KEY);
CREATE TABLE a (id INTEGER PRIMARY KEY, p INTEGER REFERENCES p (id) ON DELETE CASCADE ON UPDATE CASCADE);
CREATE TABLE b (id INTEGER PRIMARY KEY, p INTEGER REFERENCES p (id) ON DELETE SET NULL ON UPDATE CASCADE);
INSERT INTO p (id) VALUES (1);
INSERT INTO a (id, p) VALUES (1, 1);
INSERT INTO b (id, p) VALUES (1, 1);
START TRANSACTION;
DECLARE ca CURSOR FOR SELECT * FROM a;
DECLARE cb CURSOR FOR SELECT * FROM b;
OPEN ca;
OPEN cb;
FETCH ca;
FETCH cb;
UPDATE p SET id = 2;
UPDATE b SET id = 3 WHERE CURRENT OF cb;
DELETE FROM p;
DELETE FROM a WHERE CURRENT OF ca;
SELECT * FROM b;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: DECLARE CURSOR
-- msg: OPEN
-- msg: OPEN
-- ID: 1 P: 1
-- ID: 1 P: 1
-- msg: UPDATE 1
-- warning 01001: cursor operation conflict: CB
-- msg: UPDATE 1
-- warning 01001: cursor operation conflict: CB
-- msg: DELETE 1
-- warning 01001: cursor operation conflict: CA
-- msg: DELETE 0
-- ID: 3 P: NULL

-- # A referential action updates the current row of a cursor, and a positioned
-- # UPDATE has already changed the row.
/* extensions V108-01 V109-01 V110-01 V113-01 */
CREATE TABLE p (id INTEGER PRIMARY KEY);
CREATE TABLE c1 (id INTEGER PRIMARY KEY, p INTEGER REFERENCES p (id) ON UPDATE CASCADE, y INTEGER);
INSERT INTO p (id) VALUES (1);
INSERT INTO c1 (id, p, y) VALUES (1, 1, 10);
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM c1;
OPEN c;
FETCH c;
UPDATE c1 SET y = 11 WHERE CURRENT OF c;
UPDATE p SET id = 2;
UPDATE c1 SET y = 12 WHERE CURRENT OF c;
SELECT * FROM c1;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- ID: 1 P: 1 Y: 10
-- msg: UPDATE 1
-- warning 01001: cursor operation conflict: C
-- msg: UPDATE 1
-- warning 01001: cursor operation conflict: C
-- msg: UPDATE 1
-- ID: 1 P: 2 Y: 12

-- # A transaction of another connection changes the rows of a held cursor. The
-- # first row wasn't changed, so that's not a conflict.
/* extensions V108-01 V109-01 V110-01 V113-01 */
/* connection 1 */
CREATE TABLE t (x INTEGER, y INTEGER);
INSERT INTO t (x, y) VALUES (1, 10), (2, 20);
DECLARE c CURSOR WITH HOLD FOR SELECT * FROM t;
START TRANSACTION;
OPEN c;
COMMIT;
/* connection 2 */
UPDATE t SET y = 21 WHERE x = 2;
/* connection 1 */
START TRANSACTION;
FETCH c;
UPDATE t SET y = 11 WHERE CURRENT OF c;
FETCH c;
UPDATE t SET y = 22 WHERE CURRENT OF c;
COMMIT;
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 2
-- 1: msg: DECLARE CURSOR
-- 1: msg: START TRANSACTION
-- 1: msg: OPEN
-- 1: msg: COMMIT
-- 2: msg: UPDATE 1
-- 1: msg: START TRANSACTION
-- 1: X: 1 Y: 10
-- 1: msg: UPDATE 1
-- 1: X: 2 Y: 20
-- warning 01001: cursor operation conflict: C
-- 1: msg: UPDATE 1
-- 1: msg: COMMIT
-- 1: X: 1 Y: 11
-- 1: X: 2 Y: 22

-- # Deleted by another connection.
/* extensions V108-01 V109-01 V110-01 V112-01 */
/* connection 1 */
CREATE TABLE t (x INTEGER, y INTEGER);
INSERT INTO t (x, y) VALUES (1, 10), (2, 20);
DECLARE c CURSOR WITH HOLD FOR SELECT * FROM t;
START TRANSACTION;
OPEN c;
COMMIT;
/* connection 2 */
DELETE FROM t WHERE x = 1;
/* connection 1 */
START TRANSACTION;
FETCH c;
DELETE FROM t WHERE CURRENT OF c;
COMMIT;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 2
-- 1: msg: DECLARE CURSOR
-- 1: msg: START TRANSACTION
-- 1: msg: OPEN
-- 1: msg: COMMIT
-- 2: msg: DELETE 1
-- 1: msg: START TRANSACTION
-- 1: X: 1 Y: 10
-- warning 01001: cursor operation conflict: C
-- 1: msg: DELETE 0
-- 1: msg: COMMIT
