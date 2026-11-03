/* setup */
CREATE TABLE t (x INTEGER, y INTEGER, z INTEGER);
INSERT INTO t (x, y, z) VALUES (1, 10, 100);
INSERT INTO t (x, y, z) VALUES (2, 20, 200);
CREATE TABLE u (x INTEGER, y INTEGER);
INSERT INTO u (x, y) VALUES (1, 10);

/* extensions V004-01 V004-02 V004-03 V004-06 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT x, y FROM t ORDER BY x FOR UPDATE;
OPEN c;
FETCH NEXT FROM c;
UPDATE t SET x = 5 WHERE CURRENT OF c;
UPDATE t SET y = 5 WHERE CURRENT OF c;
UPDATE t SET z = 5 WHERE CURRENT OF c;
UPDATE t SET y = 6, x = 6 WHERE CURRENT OF c;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1 Y: 10
-- error 42601: syntax error: column X is used by a sort key of cursor C
-- msg: UPDATE 1
-- msg: UPDATE 1
-- error 42601: syntax error: column X is used by a sort key of cursor C
-- X: 1 Y: 5 Z: 5
-- X: 2 Y: 20 Z: 200

/* extensions V004-01 V004-02 V004-03 V004-06 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM t ORDER BY x DESC, t.y FOR UPDATE;
OPEN c;
FETCH c;
UPDATE t SET x = 5 WHERE CURRENT OF c;
UPDATE t SET y = 5 WHERE CURRENT OF c;
UPDATE t SET z = 5 WHERE CURRENT OF c;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 2 Y: 20 Z: 200
-- error 42601: syntax error: column X is used by a sort key of cursor C
-- error 42601: syntax error: column Y is used by a sort key of cursor C
-- msg: UPDATE 1

/* extensions V004-01 V004-02 V004-03 V004-06 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT x FROM t ORDER BY ABS(x + y) FOR UPDATE;
OPEN c;
FETCH c;
UPDATE t SET x = 5 WHERE CURRENT OF c;
UPDATE t SET y = 5 WHERE CURRENT OF c;
UPDATE t SET z = 5 WHERE CURRENT OF c;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1
-- error 42601: syntax error: column X is used by a sort key of cursor C
-- error 42601: syntax error: column Y is used by a sort key of cursor C
-- msg: UPDATE 1

/* extensions V004-01 V004-02 V004-03 V004-06 V006-02 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT x, y FROM t ORDER BY 1 FOR UPDATE;
OPEN c;
FETCH c;
UPDATE t SET x = 5 WHERE CURRENT OF c;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1 Y: 10
-- msg: UPDATE 1

/* extensions V004-01 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT x AS a FROM t ORDER BY a FOR UPDATE;
-- msg: START TRANSACTION
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.A

/* extensions V004-01 V004-02 V004-03 V004-06 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT z AS x, y FROM t ORDER BY x FOR UPDATE;
OPEN c;
FETCH c;
UPDATE t SET x = 5 WHERE CURRENT OF c;
UPDATE t SET z = 5 WHERE CURRENT OF c;
UPDATE t SET y = 5 WHERE CURRENT OF c;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 100 Y: 10
-- error 42601: syntax error: column X is used by a sort key of cursor C
-- error 42601: syntax error: column Z is used by a sort key of cursor C
-- msg: UPDATE 1

/* extensions V004-01 V004-02 V004-03 V004-06 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT y AS x FROM t ORDER BY t.x FOR UPDATE;
OPEN c;
FETCH c;
UPDATE t SET y = 5 WHERE CURRENT OF c;
UPDATE t SET x = 5 WHERE CURRENT OF c;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 10
-- msg: UPDATE 1
-- error 42601: syntax error: column X is used by a sort key of cursor C

/* extensions V004-01 V004-02 V004-03 V004-06 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT x FROM t AS a ORDER BY a.x FOR UPDATE;
OPEN c;
FETCH c;
UPDATE t SET x = 5 WHERE CURRENT OF c;
UPDATE t SET y = 5 WHERE CURRENT OF c;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1
-- error 42601: syntax error: column X is used by a sort key of cursor C
-- msg: UPDATE 1

/* extensions V004-01 V004-02 V004-03 V004-06 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT p FROM t AS a (p, q, r) ORDER BY q FOR UPDATE;
OPEN c;
FETCH c;
UPDATE t SET y = 5 WHERE CURRENT OF c;
UPDATE t SET x = 5 WHERE CURRENT OF c;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- P: 1
-- error 42601: syntax error: column Y is used by a sort key of cursor C
-- msg: UPDATE 1

/* extensions V004-01 V004-02 V004-03 V004-06 V006-03 V006-04 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT x FROM t ORDER BY (SELECT MAX(u.y) FROM u WHERE u.x = t.y) FOR UPDATE;
OPEN c;
FETCH c;
UPDATE t SET y = 5 WHERE CURRENT OF c;
UPDATE t SET x = 5 WHERE CURRENT OF c;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1
-- error 42601: syntax error: column Y is used by a sort key of cursor C
-- msg: UPDATE 1

/* extensions V004-01 V004-02 V004-03 V004-06 V006-03 V006-04 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT x FROM t ORDER BY (SELECT MAX(y) FROM u) FOR UPDATE;
OPEN c;
FETCH c;
UPDATE t SET y = 5 WHERE CURRENT OF c;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1
-- msg: UPDATE 1

/* extensions V004-01 V004-02 V004-03 V004-06 V006-03 V006-04 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT x FROM t ORDER BY (SELECT MAX(z) FROM t) FOR UPDATE;
OPEN c;
FETCH c;
UPDATE t SET z = 5 WHERE CURRENT OF c;
UPDATE t SET x = 5 WHERE CURRENT OF c;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1
-- error 42601: syntax error: column Z is used by a sort key of cursor C
-- msg: UPDATE 1

/* extensions V004-01 V004-02 V004-03 V004-06 V006-03 V006-04 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT x FROM t ORDER BY (SELECT MAX(b.q) FROM t AS b (p, q, r)) FOR UPDATE;
OPEN c;
FETCH c;
UPDATE t SET y = 5 WHERE CURRENT OF c;
UPDATE t SET x = 5 WHERE CURRENT OF c;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1
-- error 42601: syntax error: column Y is used by a sort key of cursor C
-- msg: UPDATE 1

/* extensions V004-01 V004-02 V004-03 V004-06 V006-03 V006-04 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT x FROM t ORDER BY (SELECT MAX(a.z) FROM (SELECT * FROM t AS a) AS a) FOR UPDATE;
OPEN c;
FETCH c;
UPDATE t SET z = 5 WHERE CURRENT OF c;
UPDATE t SET x = 5 WHERE CURRENT OF c;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1
-- error 42601: syntax error: column Z is used by a sort key of cursor C
-- error 42601: syntax error: column X is used by a sort key of cursor C

/* extensions V004-01 V004-02 V004-03 V004-06 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT x FROM t WHERE y > 0 ORDER BY z FOR UPDATE;
OPEN c;
FETCH c;
UPDATE t SET y = 5 WHERE CURRENT OF c;
UPDATE t SET x = 5 WHERE CURRENT OF c;
UPDATE t SET z = 5 WHERE CURRENT OF c;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1
-- msg: UPDATE 1
-- msg: UPDATE 1
-- error 42601: syntax error: column Z is used by a sort key of cursor C

/* extensions V004-01 V004-02 V004-03 V004-06 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT x, y FROM t ORDER BY x FOR UPDATE OF y;
OPEN c;
FETCH c;
UPDATE t SET x = 5 WHERE CURRENT OF c;
UPDATE t SET z = 5 WHERE CURRENT OF c;
UPDATE t SET y = 5 WHERE CURRENT OF c;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1 Y: 10
-- error 42601: syntax error: column X is used by a sort key of cursor C
-- error 42601: syntax error: column Z is not updatable by cursor C
-- msg: UPDATE 1

/* extensions V004-01 V004-02 V004-03 V004-05 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT x FROM t ORDER BY x FOR UPDATE;
OPEN c;
FETCH c;
DELETE FROM t WHERE CURRENT OF c;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1
-- msg: DELETE 1

/* extensions V004-01 V004-02 V004-03 V004-06 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT x FROM t FOR UPDATE;
OPEN c;
FETCH c;
UPDATE t SET x = 5 WHERE CURRENT OF c;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1
-- msg: UPDATE 1
