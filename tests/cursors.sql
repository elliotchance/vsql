/* setup */
CREATE TABLE t (x INTEGER, y INTEGER);
INSERT INTO t (x, y) VALUES (1, 10);
INSERT INTO t (x, y) VALUES (2, 20);
CREATE TABLE u (x INTEGER);

/* extensions V004-01 V004-02 V004-03 V004-04 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT x, y * 2 AS z FROM t;
OPEN c;
FETCH c;
FETCH FROM c;
FETCH NEXT FROM c;
FETCH c;
CLOSE c;
COMMIT;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1 Z: 20
-- X: 2 Z: 40
-- warning 02000: no data
-- warning 02000: no data
-- msg: CLOSE
-- msg: COMMIT

/* extensions V004-01 V004-02 V004-03 V004-04 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM t;
OPEN c;
FETCH c;
CLOSE c;
OPEN c;
FETCH c;
COMMIT;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1 Y: 10
-- msg: CLOSE
-- msg: OPEN
-- X: 1 Y: 10
-- msg: COMMIT

/* extensions V004-01 V004-02 V004-03 */
DECLARE c CURSOR FOR SELECT * FROM t;
OPEN c;
FETCH c;
-- msg: DECLARE CURSOR
-- msg: OPEN
-- error 24000: invalid cursor state: cursor C is not open

/* extensions V004-01 V004-02 V004-03 */
DECLARE c CURSOR FOR SELECT * FROM t;
START TRANSACTION;
OPEN c;
COMMIT;
FETCH c;
-- msg: DECLARE CURSOR
-- msg: START TRANSACTION
-- msg: OPEN
-- msg: COMMIT
-- error 24000: invalid cursor state: cursor C is not open

/* extensions V004-01 V004-02 V004-03 */
DECLARE c CURSOR WITH HOLD FOR SELECT * FROM t;
OPEN c;
FETCH c;
START TRANSACTION;
FETCH c;
COMMIT;
FETCH c;
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1 Y: 10
-- msg: START TRANSACTION
-- X: 2 Y: 20
-- msg: COMMIT
-- warning 02000: no data

/* extensions V004-01 V004-02 V004-03 */
DECLARE c CURSOR WITH HOLD FOR SELECT * FROM t;
START TRANSACTION;
OPEN c;
ROLLBACK;
FETCH c;
-- msg: DECLARE CURSOR
-- msg: START TRANSACTION
-- msg: OPEN
-- msg: ROLLBACK
-- error 24000: invalid cursor state: cursor C is not open

/* extensions V004-01 */
DECLARE c CURSOR FOR SELECT * FROM t;
DECLARE c CURSOR FOR SELECT * FROM u;
DECLARE "c" CURSOR FOR SELECT * FROM u;
-- msg: DECLARE CURSOR
-- error 42P03: duplicate cursor: C
-- msg: DECLARE CURSOR

/* extensions V004-01 */
DECLARE c CURSOR FOR SELECT * FROM missing;
-- error 42P01: no such table: ":memory:".PUBLIC.MISSING

/* extensions V004-02 */
OPEN c;
-- error 34000: invalid cursor name: cursor C does not exist

/* extensions V004-03 */
FETCH c;
-- error 34000: invalid cursor name: cursor C does not exist

/* extensions V004-01 V004-04 */
DECLARE c CURSOR FOR SELECT * FROM t;
CLOSE c;
-- msg: DECLARE CURSOR
-- error 24000: invalid cursor state: cursor C is not open

/* extensions V004-01 V004-02 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM t;
OPEN c;
OPEN c;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- error 24000: invalid cursor state: cursor C is already open

/* extensions V004-01 V004-02 V004-03 V004-04 */
CREATE SEQUENCE seq;
START TRANSACTION;
DECLARE c CURSOR FOR VALUES NEXT VALUE FOR seq;
OPEN c;
FETCH c;
CLOSE c;
OPEN c;
FETCH c;
-- msg: CREATE SEQUENCE 1
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- COL1: 1
-- msg: CLOSE
-- msg: OPEN
-- COL1: 2

/* extensions V004-01 V004-02 V004-03 V004-05 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM t;
OPEN c;
FETCH c;
DELETE FROM t WHERE CURRENT OF c;
DELETE FROM t WHERE CURRENT OF c;
FETCH c;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1 Y: 10
-- msg: DELETE 1
-- error 24000: invalid cursor state: cursor C is not positioned on a row
-- X: 2 Y: 20
-- X: 2 Y: 20

/* extensions V004-01 V004-02 V004-03 V004-05 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT x FROM t AS a WHERE x = 2;
OPEN c;
FETCH c;
DELETE FROM t WHERE CURRENT OF c;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 2
-- msg: DELETE 1
-- X: 1 Y: 10

/* extensions V004-01 V004-02 V004-05 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM t;
DELETE FROM t WHERE CURRENT OF c;
OPEN c;
DELETE FROM t WHERE CURRENT OF c;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- error 24000: invalid cursor state: cursor C is not open
-- msg: OPEN
-- error 24000: invalid cursor state: cursor C is not positioned on a row

/* extensions V004-05 */
DELETE FROM t WHERE CURRENT OF c;
-- error 34000: invalid cursor name: cursor C does not exist

/* extensions V004-01 V004-02 V004-03 V004-05 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM t;
OPEN c;
FETCH c;
DELETE FROM u WHERE CURRENT OF c;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1 Y: 10
-- error 42601: syntax error: table U is not the table of cursor C

/* extensions V004-01 V004-02 V004-03 V004-05 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM t;
OPEN c;
FETCH c;
DELETE FROM t;
DELETE FROM t WHERE CURRENT OF c;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1 Y: 10
-- msg: DELETE 2
-- error 24000: invalid cursor state: the current row of cursor C has been deleted

/* extensions V004-01 V004-02 V004-03 V004-05 */
DECLARE c CURSOR WITH HOLD FOR SELECT * FROM t;
START TRANSACTION;
OPEN c;
FETCH c;
COMMIT;
DELETE FROM t WHERE CURRENT OF c;
START TRANSACTION;
FETCH c;
DELETE FROM t WHERE CURRENT OF c;
COMMIT;
SELECT * FROM t;
-- msg: DECLARE CURSOR
-- msg: START TRANSACTION
-- msg: OPEN
-- X: 1 Y: 10
-- msg: COMMIT
-- error 24000: invalid cursor state: cursor C has not been fetched in this transaction
-- msg: START TRANSACTION
-- X: 2 Y: 20
-- msg: DELETE 1
-- msg: COMMIT
-- X: 1 Y: 10

/* extensions V004-01 V004-02 V004-03 V004-06 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM t;
OPEN c;
FETCH c;
UPDATE t SET y = y + 1 WHERE CURRENT OF c;
UPDATE t SET y = y + 1 WHERE CURRENT OF c;
FETCH c;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1 Y: 10
-- msg: UPDATE 1
-- msg: UPDATE 1
-- X: 2 Y: 20
-- X: 1 Y: 12
-- X: 2 Y: 20

/* extensions V004-01 V004-02 V004-03 V004-06 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM t FOR UPDATE OF y;
OPEN c;
FETCH c;
UPDATE t SET x = 3 WHERE CURRENT OF c;
UPDATE t SET y = 3 WHERE CURRENT OF c;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1 Y: 10
-- error 42601: syntax error: column X is not updatable by cursor C
-- msg: UPDATE 1
-- X: 1 Y: 3
-- X: 2 Y: 20

/* extensions V004-01 V004-02 V004-03 V004-06 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM t;
OPEN c;
FETCH c;
DELETE FROM t WHERE x = 1;
UPDATE t SET y = 3 WHERE CURRENT OF c;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1 Y: 10
-- msg: DELETE 1
-- error 24000: invalid cursor state: the current row of cursor C has been deleted

/* extensions V004-01 V004-02 V004-03 V004-05 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM t ORDER BY x DESC;
OPEN c;
FETCH c;
DELETE FROM t WHERE CURRENT OF c;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 2 Y: 20
-- error 34000: invalid cursor name: cursor C is not updatable

/* extensions V004-01 V004-02 V004-03 V004-06 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM t FOR READ ONLY;
OPEN c;
FETCH c;
UPDATE t SET y = 3 WHERE CURRENT OF c;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1 Y: 10
-- error 34000: invalid cursor name: cursor C is not updatable

/* extensions V004-01 V004-02 V004-03 V004-05 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM t ORDER BY x DESC FOR UPDATE;
OPEN c;
FETCH c;
DELETE FROM t WHERE CURRENT OF c;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 2 Y: 20
-- msg: DELETE 1
-- X: 1 Y: 10

/* extensions V004-01 */
DECLARE c1 CURSOR FOR VALUES 1 FOR UPDATE;
DECLARE c2 CURSOR FOR SELECT * FROM t FETCH FIRST 1 ROW ONLY FOR UPDATE;
DECLARE c3 CURSOR FOR SELECT * FROM t JOIN u ON t.x = u.x FOR UPDATE;
DECLARE c4 CURSOR FOR SELECT * FROM (SELECT * FROM t) AS d FOR UPDATE;
DECLARE c5 CURSOR FOR SELECT COUNT(*) FROM t FOR UPDATE;
DECLARE c6 CURSOR FOR SELECT DISTINCT x FROM t FOR UPDATE;
DECLARE c7 CURSOR FOR SELECT * FROM information_schema.tables FOR UPDATE;
-- error 42601: syntax error: cursor C1 is not updatable
-- error 42601: syntax error: cursor C2 is not updatable
-- error 42601: syntax error: cursor C3 is not updatable
-- error 42601: syntax error: cursor C4 is not updatable
-- error 42601: syntax error: cursor C5 is not updatable
-- error 42601: syntax error: cursor C6 is not updatable
-- error 42601: syntax error: cursor C7 is not updatable

/* extensions V004-01 V004-02 V004-03 V004-04 V004-05 V004-06 */
EXPLAIN DECLARE c CURSOR FOR SELECT * FROM t;
EXPLAIN OPEN c;
EXPLAIN FETCH c;
EXPLAIN CLOSE c;
EXPLAIN DELETE FROM t WHERE CURRENT OF c;
EXPLAIN UPDATE t SET x = 1 WHERE CURRENT OF c;
-- error 42601: syntax error: Cannot EXPLAIN DECLARE CURSOR
-- error 42601: syntax error: Cannot EXPLAIN OPEN
-- error 42601: syntax error: Cannot EXPLAIN FETCH
-- error 42601: syntax error: Cannot EXPLAIN CLOSE
-- error 42601: syntax error: Cannot EXPLAIN DELETE WHERE CURRENT OF
-- error 42601: syntax error: Cannot EXPLAIN UPDATE WHERE CURRENT OF
