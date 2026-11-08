-- # A positioned UPDATE can't set a column that a sort key of its cursor uses
-- # (14.13, Syntax Rules, 13), since that could change the order of the rows.
-- # Other columns can still be set. A statement that sets a sort key column is
-- # rejected as a whole, even when it sets another column too.
/* setup */
CREATE TABLE t (x INTEGER, y INTEGER, z INTEGER);
INSERT INTO t (x, y, z) VALUES (1, 10, 100);
INSERT INTO t (x, y, z) VALUES (2, 20, 200);
CREATE TABLE u (x INTEGER, y INTEGER);
INSERT INTO u (x, y) VALUES (1, 10);

/* extensions V108-01 V109-01 V110-01 V113-01 */
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

-- # Every sort key counts, whether it's DESC or qualified with the table name.
/* extensions V108-01 V109-01 V110-01 V113-01 */
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

-- # A sort key that's an expression uses every column in it.
/* extensions V108-01 V109-01 V110-01 V113-01 */
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

-- # ORDER BY 1 is a constant (a sort key without a column reference, V202-01),
-- # not the first column of the result, so it uses no columns.
/* extensions V108-01 V109-01 V110-01 V113-01 V202-01 */
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

-- # An updatable cursor can't yet use the alias of a column of the result as a
-- # sort key: it's an unknown column. A SELECT allows it (7.17, Syntax Rules,
-- # 28.d.ii), so this is a bug (#1100).
/* extensions V108-01 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT x AS a FROM t ORDER BY a FOR UPDATE;
-- msg: START TRANSACTION
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.A

-- # When an alias is also the name of a column of the table, the sort key uses
-- # both the column the alias is for (Z) and the column of the table (X).
/* extensions V108-01 V109-01 V110-01 V113-01 */
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

-- # A qualified name is always the column of the table, not an alias.
/* extensions V108-01 V109-01 V110-01 V113-01 */
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

-- # A correlation name, or a derived column list that renames the columns,
-- # still leads back to the column of the table.
/* extensions V108-01 V109-01 V110-01 V113-01 */
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

/* extensions V108-01 V109-01 V110-01 V113-01 */
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

-- # A column in a subquery of a sort key is used too when it's a column of the
-- # table of the cursor: an outer reference (T.Y), or the same table read
-- # again, even renamed. A column of another table with the same name (U.Y)
-- # isn't.
/* extensions V108-01 V109-01 V110-01 V113-01 V202-02 V202-03 */
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

/* extensions V108-01 V109-01 V110-01 V113-01 V202-02 V202-03 */
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

/* extensions V108-01 V109-01 V110-01 V113-01 V202-02 V202-03 */
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

/* extensions V108-01 V109-01 V110-01 V113-01 V202-02 V202-03 */
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

-- # Every column that a subquery refers to is used, including through a derived
-- # table. SELECT * refers to every column (7.16, Syntax Rules, 4.b), so X is
-- # used as well as Z.
/* extensions V108-01 V109-01 V110-01 V113-01 V202-02 V202-03 */
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

-- # A column that's only used by the WHERE of the cursor isn't a sort key.
/* extensions V108-01 V109-01 V110-01 V113-01 */
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

-- # With FOR UPDATE OF, a column must also be in the list (14.13, Syntax Rules,
-- # 14). A sort key column is reported as a sort key.
/* extensions V108-01 V109-01 V110-01 V113-01 */
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

-- # A positioned DELETE isn't affected by the sort keys.
/* extensions V108-01 V109-01 V110-01 V112-01 */
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

-- # Without an ORDER BY, any column can be set.
/* extensions V108-01 V109-01 V110-01 V113-01 */
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
