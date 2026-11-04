/* setup */
CREATE TABLE t (x INTEGER, y INTEGER);
INSERT INTO t (x, y) VALUES (1, 10);
INSERT INTO t (x, y) VALUES (2, 20);
CREATE TABLE u (x INTEGER);

-- # FETCH, FETCH FROM and FETCH NEXT FROM are the same (14.5, Syntax Rules,
-- # 2). After the last row it's no data, and the cursor stays after the last
-- # row (15.3, General Rules, 9.b.ii).
/* extensions V108-01 V109-01 V110-01 V111-01 */
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

-- # A closed cursor can be opened again, and it starts before the first row.
/* extensions V108-01 V109-01 V110-01 V111-01 */
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

-- # Without START TRANSACTION each statement commits, and COMMIT closes a
-- # cursor that isn't WITH HOLD (17.7, General Rules, 3).
/* extensions V108-01 V109-01 V110-01 */
DECLARE c CURSOR FOR SELECT * FROM t;
OPEN c;
FETCH c;
-- msg: DECLARE CURSOR
-- msg: OPEN
-- error 24000: invalid cursor state: cursor C is not open

/* extensions V108-01 V109-01 V110-01 */
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

-- # A WITH HOLD cursor stays open after COMMIT, but ROLLBACK closes it (17.8,
-- # General Rules, 2.e).
/* extensions V108-01 V109-01 V110-01 */
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

/* extensions V108-01 V109-01 V110-01 */
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

-- # Cursor names are compared like other names, so c and C are the same
-- # cursor, but "c" is another one.
/* extensions V108-01 */
DECLARE c CURSOR FOR SELECT * FROM t;
DECLARE c CURSOR FOR SELECT * FROM u;
DECLARE "c" CURSOR FOR SELECT * FROM u;
-- msg: DECLARE CURSOR
-- error 42P03: duplicate cursor: C
-- msg: DECLARE CURSOR

-- # The query is checked when the cursor is declared. A cursor must exist to be
-- # used, and it must be open to be fetched or closed (15.3, General Rules, 2)
-- # and (15.4, General Rules, 2).
/* extensions V108-01 */
DECLARE c CURSOR FOR SELECT * FROM missing;
-- error 42P01: no such table: ":memory:".PUBLIC.MISSING

/* extensions V109-01 */
OPEN c;
-- error 34000: invalid cursor name: cursor C does not exist

/* extensions V110-01 */
FETCH c;
-- error 34000: invalid cursor name: cursor C does not exist

/* extensions V108-01 V111-01 */
DECLARE c CURSOR FOR SELECT * FROM t;
CLOSE c;
-- msg: DECLARE CURSOR
-- error 24000: invalid cursor state: cursor C is not open

-- # A cursor that's already open can't be opened (15.1, General Rules, 2).
/* extensions V108-01 V109-01 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM t;
OPEN c;
OPEN c;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- error 24000: invalid cursor state: cursor C is already open

-- # The query is evaluated each time the cursor is opened, so a sequence gives
-- # its next value.
/* extensions V108-01 V109-01 V110-01 V111-01 */
CREATE SEQUENCE seq;
START TRANSACTION;
DECLARE c CURSOR FOR SELECT NEXT VALUE FOR seq FROM (VALUES 1) AS t;
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

-- # A positioned DELETE deletes the current row, and then the cursor isn't on a
-- # row (15.5, General Rules, 6) until the next FETCH, which gets the row after
-- # it (15.5, General Rules, 13).
/* extensions V108-01 V109-01 V110-01 V112-01 */
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

-- # The table of a positioned DELETE is the table of the cursor's query, even
-- # when the query gives it a correlation name (14.8, Syntax Rules, 6).
/* extensions V108-01 V109-01 V110-01 V112-01 */
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

-- # The cursor must exist, be open and be on a row, and the table must be the
-- # table of its query (14.8, Syntax Rules, 6).
/* extensions V108-01 V109-01 V112-01 */
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

/* extensions V112-01 */
DELETE FROM t WHERE CURRENT OF c;
-- error 34000: invalid cursor name: cursor C does not exist

/* extensions V108-01 V109-01 V110-01 V112-01 */
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

-- # A positioned DELETE of a row that another statement deleted is an error.
-- # The standard says it's a warning (15.5, General Rules, 12), which isn't
-- # implemented yet (#797).
/* extensions V108-01 V109-01 V110-01 V112-01 */
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
-- warning 01001: cursor operation conflict: C
-- msg: DELETE 0

-- # After COMMIT, a WITH HOLD cursor has to be fetched again before a
-- # positioned DELETE (15.5, General Rules, 7).
/* extensions V108-01 V109-01 V110-01 V112-01 */
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

-- # A positioned UPDATE changes the current row and the cursor stays on it, so
-- # it can be updated again. The next FETCH gets the next row.
/* extensions V108-01 V109-01 V110-01 V113-01 */
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

-- # With FOR UPDATE OF, only the listed columns can be set (14.13, Syntax
-- # Rules, 14).
/* extensions V108-01 V109-01 V110-01 V113-01 */
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

-- # A positioned UPDATE of a row that another statement deleted is an error,
-- # rather than the warning of the standard (15.6, General Rules, 9) (#797).
/* extensions V108-01 V109-01 V110-01 V113-01 */
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
-- warning 01001: cursor operation conflict: C
-- msg: UPDATE 0

-- # With ORDER BY or FOR READ ONLY a cursor is read-only (14.3, Syntax Rules,
-- # 4.a), so a positioned DELETE or UPDATE is an invalid cursor name, as it is
-- # for a dynamic cursor (20.23, General Rules, 3) and (20.24, General Rules,
-- # 3).
/* extensions V108-01 V109-01 V110-01 V112-01 */
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

/* extensions V108-01 V109-01 V110-01 V113-01 */
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

-- # FOR UPDATE makes a cursor with ORDER BY updatable (14.3, Syntax Rules,
-- # 6.a). This needs Feature F831 (14.3, Conformance Rules, 1).
/* extensions V108-01 V109-01 V110-01 V112-01 */
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

-- # FOR UPDATE needs a query that's simply updatable (14.3, Syntax Rules, 5):
-- # a query specification of one base table (7.16, Syntax Rules, 27), so not
-- # VALUES, FETCH FIRST, a join, a derived table, an aggregate, DISTINCT or
-- # INFORMATION_SCHEMA.
/* extensions V108-01 */
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

-- # Every column of the query must be a column of the table (7.16, Syntax
-- # Rules, 27.c), not an expression.
/* extensions V108-01 */
CREATE TABLE b (p BOOLEAN, q BOOLEAN);
DECLARE c1 CURSOR FOR SELECT x + 1 AS z FROM t FOR UPDATE;
DECLARE c2 CURSOR FOR SELECT x, 1 AS z FROM t FOR UPDATE;
DECLARE c3 CURSOR FOR SELECT (x) AS z FROM t FOR UPDATE;
DECLARE c4 CURSOR FOR SELECT p OR q AS z FROM b FOR UPDATE;
DECLARE c5 CURSOR FOR SELECT p AND q AS z FROM b FOR UPDATE;
DECLARE c6 CURSOR FOR SELECT NOT p AS z FROM b FOR UPDATE;
DECLARE c7 CURSOR FOR SELECT p IS TRUE AS z FROM b FOR UPDATE;
-- msg: CREATE TABLE 1
-- error 42601: syntax error: cursor C1 is not updatable
-- error 42601: syntax error: cursor C2 is not updatable
-- error 42601: syntax error: cursor C3 is not updatable
-- error 42601: syntax error: cursor C4 is not updatable
-- error 42601: syntax error: cursor C5 is not updatable
-- error 42601: syntax error: cursor C6 is not updatable
-- error 42601: syntax error: cursor C7 is not updatable

-- # A column of the table can't be selected more than once (7.16, Syntax
-- # Rules, 24.b), even with another name.
/* extensions V108-01 */
DECLARE c1 CURSOR FOR SELECT x, x FROM t FOR UPDATE;
DECLARE c2 CURSOR FOR SELECT x, t.x FROM t FOR UPDATE;
DECLARE c3 CURSOR FOR SELECT x AS a, x AS b FROM t FOR UPDATE;
DECLARE c4 CURSOR FOR SELECT t.*, x FROM t FOR UPDATE;
DECLARE c5 CURSOR FOR SELECT t.*, t.* FROM t FOR UPDATE;
-- error 42601: syntax error: cursor C1 is not updatable
-- error 42601: syntax error: cursor C2 is not updatable
-- error 42601: syntax error: cursor C3 is not updatable
-- error 42601: syntax error: cursor C4 is not updatable
-- error 42601: syntax error: cursor C5 is not updatable

-- # A subquery in WHERE can't read the table of the cursor (7.16, Syntax
-- # Rules, 27.d), however deeply it's nested.
/* extensions V108-01 */
DECLARE c1 CURSOR FOR SELECT x FROM t WHERE x IN (SELECT x FROM t) FOR UPDATE;
DECLARE c2 CURSOR FOR SELECT x FROM t WHERE EXISTS (SELECT * FROM t AS a WHERE a.x = t.x) FOR UPDATE;
DECLARE c3 CURSOR FOR SELECT x FROM t AS a WHERE x IN (SELECT x FROM public.t) FOR UPDATE;
DECLARE c4 CURSOR FOR SELECT x FROM t WHERE x IN (SELECT u.x FROM u JOIN t AS a ON u.x = a.x) FOR UPDATE;
DECLARE c5 CURSOR FOR SELECT x FROM t WHERE x IN (SELECT x FROM (SELECT x FROM t) AS d) FOR UPDATE;
DECLARE c6 CURSOR FOR SELECT x FROM t WHERE x IN (SELECT x FROM u WHERE x IN (SELECT x FROM t)) FOR UPDATE;
DECLARE c7 CURSOR FOR SELECT x FROM t WHERE x IN (SELECT x FROM u UNION SELECT x FROM t) FOR UPDATE;
-- error 42601: syntax error: cursor C1 is not updatable
-- error 42601: syntax error: cursor C2 is not updatable
-- error 42601: syntax error: cursor C3 is not updatable
-- error 42601: syntax error: cursor C4 is not updatable
-- error 42601: syntax error: cursor C5 is not updatable
-- error 42601: syntax error: cursor C6 is not updatable
-- error 42601: syntax error: cursor C7 is not updatable

-- # These are simply updatable: all the columns of the table, columns with
-- # other names, and a subquery of another table, even one with the same name
-- # in another schema. Without FOR UPDATE they're updatable (14.3, Syntax
-- # Rules, 4.b).
/* extensions V108-01 V109-01 V110-01 V112-01 V113-01 */
CREATE SCHEMA s;
CREATE TABLE s.t (x INTEGER);
START TRANSACTION;
DECLARE c1 CURSOR FOR SELECT t.* FROM t FOR UPDATE;
DECLARE c2 CURSOR FOR SELECT y AS a, x AS b FROM t FOR UPDATE;
DECLARE c3 CURSOR FOR SELECT x, y FROM t WHERE x NOT IN (SELECT x FROM u) FOR UPDATE;
DECLARE c4 CURSOR FOR SELECT x FROM t WHERE x NOT IN (SELECT x FROM s.t);
DECLARE c5 CURSOR FOR SELECT x FROM t WHERE x = 2;
OPEN c4;
FETCH c4;
UPDATE t SET y = 3 WHERE CURRENT OF c4;
OPEN c5;
FETCH c5;
DELETE FROM t WHERE CURRENT OF c5;
SELECT * FROM t;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: DECLARE CURSOR
-- msg: DECLARE CURSOR
-- msg: DECLARE CURSOR
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1
-- msg: UPDATE 1
-- msg: OPEN
-- X: 2
-- msg: DELETE 1
-- X: 1 Y: 3

-- # A subquery of the same table in ORDER BY is allowed, it's only checked in
-- # WHERE (7.16, Syntax Rules, 27.d).
/* extensions V108-01 V109-01 V110-01 V112-01 V202-02 V202-03 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM t ORDER BY (SELECT MAX(x) FROM t) FOR UPDATE;
OPEN c;
FETCH c;
DELETE FROM t WHERE CURRENT OF c;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1 Y: 10
-- msg: DELETE 1

-- # Without FOR UPDATE, a query that isn't simply updatable is read-only (14.3,
-- # Syntax Rules, 4.a), so it's the positioned statement that fails.
/* extensions V108-01 V109-01 V110-01 V112-01 V113-01 */
START TRANSACTION;
DECLARE c1 CURSOR FOR SELECT x + 1 AS z FROM t;
OPEN c1;
FETCH c1;
UPDATE t SET x = 5 WHERE CURRENT OF c1;
DECLARE c2 CURSOR FOR SELECT x FROM t WHERE x IN (SELECT x FROM t);
OPEN c2;
FETCH c2;
DELETE FROM t WHERE CURRENT OF c2;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- Z: 2
-- error 34000: invalid cursor name: cursor C1 is not updatable
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 1
-- error 34000: invalid cursor name: cursor C2 is not updatable
-- X: 1 Y: 10
-- X: 2 Y: 20

-- # Cursor statements can't be explained.
/* extensions V108-01 V109-01 V110-01 V111-01 V112-01 V113-01 */
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

-- # FOR UPDATE OF can list any column of the table, even one that isn't
-- # selected, but each must exist (14.3, Syntax Rules, 9).
/* extensions V108-01 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT x FROM t FOR UPDATE OF nope;
DECLARE c CURSOR FOR SELECT x FROM t FOR UPDATE OF x, nope;
DECLARE c CURSOR FOR SELECT x FROM t FOR UPDATE OF y;
-- msg: START TRANSACTION
-- error 42703: no such column: NOPE
-- error 42703: no such column: NOPE
-- msg: DECLARE CURSOR
