/* setup */
CREATE TABLE t (id INT PRIMARY KEY, x INT, y VARCHAR(10) DEFAULT 'def');
INSERT INTO t (id, x, y) VALUES (1, 10, 'a'), (2, 20, 'b'), (3, 30, 'c');

-- # A view that reads the rows of one table, where each column is a column of
-- # the table, is simply updatable (Syntax Rules, 11). Its new rows are inserted
-- # into the table, and the other columns of the table get their default
-- # (15.13).
CREATE VIEW v AS SELECT id, x FROM t WHERE x > 10;
INSERT INTO v VALUES (4, 40);
INSERT INTO v (x, id) VALUES (50, 5);
SELECT * FROM t;
-- msg: CREATE VIEW 1
-- msg: INSERT 1
-- msg: INSERT 1
-- ID: 1 X: 10 Y: a
-- ID: 2 X: 20 Y: b
-- ID: 3 X: 30 Y: c
-- ID: 4 X: 40 Y: def
-- ID: 5 X: 50 Y: def

-- # A new row doesn't have to be seen through the view, because there's no
-- # WITH CHECK OPTION (#1258).
CREATE VIEW v AS SELECT id, x FROM t WHERE x > 10;
INSERT INTO v VALUES (4, 5);
SELECT * FROM v;
SELECT * FROM t WHERE id = 4;
-- msg: CREATE VIEW 1
-- msg: INSERT 1
-- ID: 2 X: 20
-- ID: 3 X: 30
-- ID: 4 X: 5 Y: def

-- # INSERT with a query.
CREATE VIEW v AS SELECT id, x FROM t;
INSERT INTO v SELECT id + 10, x + 1 FROM t;
SELECT COUNT(*) FROM t;
-- msg: CREATE VIEW 1
-- msg: INSERT 3
-- COL1: 6

-- # UPDATE and DELETE only change the rows that are seen through the view
-- # (15.10 and 15.16).
CREATE VIEW v AS SELECT id, x FROM t WHERE x > 10;
UPDATE v SET x = x + 1;
UPDATE v SET x = 0 WHERE id = 3;
SELECT * FROM t;
DELETE FROM v WHERE id = 2;
DELETE FROM v;
SELECT * FROM t;
-- msg: CREATE VIEW 1
-- msg: UPDATE 2
-- msg: UPDATE 1
-- ID: 1 X: 10 Y: a
-- ID: 2 X: 21 Y: b
-- ID: 3 X: 0 Y: c
-- msg: DELETE 1
-- warning 02000: no data
-- msg: DELETE 0
-- ID: 1 X: 10 Y: a
-- ID: 3 X: 0 Y: c

-- # The columns of the view can have other names, from a view column list, an
-- # AS or a correlation name of the table.
CREATE VIEW v (a, b) AS SELECT id, x FROM t;
CREATE VIEW w AS SELECT i AS k, z FROM t AS u (i, z, s);
INSERT INTO v (a, b) VALUES (4, 40);
UPDATE w SET z = k * 100 WHERE k > 2;
DELETE FROM v WHERE b = 200;
SELECT * FROM t;
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: INSERT 1
-- msg: UPDATE 2
-- warning 02000: no data
-- msg: DELETE 0
-- ID: 1 X: 10 Y: a
-- ID: 2 X: 20 Y: b
-- ID: 3 X: 300 Y: c
-- ID: 4 X: 400 Y: def

-- # A correlation name is the name of the view in UPDATE and DELETE.
CREATE VIEW v AS SELECT id, x FROM t;
UPDATE v AS q SET x = q.x + q.id WHERE q.id = 1;
DELETE FROM v AS q WHERE q.id = 2;
UPDATE v SET x = v.x + 1 WHERE v.id = 1;
SELECT * FROM t;
-- msg: CREATE VIEW 1
-- msg: UPDATE 1
-- msg: DELETE 1
-- msg: UPDATE 1
-- ID: 1 X: 12 Y: a
-- ID: 3 X: 30 Y: c

-- # A view of an updatable view changes the base table that it reads in the end,
-- # with the WHERE of both views.
CREATE VIEW v AS SELECT * FROM t WHERE x > 10;
CREATE VIEW w (n, m) AS SELECT id, x FROM v WHERE id < 3;
UPDATE w SET m = m * 2;
INSERT INTO w VALUES (9, 90);
DELETE FROM w WHERE n = 9;
SELECT * FROM t;
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: UPDATE 1
-- msg: INSERT 1
-- warning 02000: no data
-- msg: DELETE 0
-- ID: 1 X: 10 Y: a
-- ID: 2 X: 40 Y: b
-- ID: 3 X: 30 Y: c
-- ID: 9 X: 90 Y: def

-- # The constraints of the table are checked.
CREATE VIEW v AS SELECT id, x FROM t;
INSERT INTO v VALUES (1, 1);
UPDATE v SET id = 2 WHERE id = 1;
INSERT INTO v (x) VALUES (1);
-- msg: CREATE VIEW 1
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T
-- error 23502: violates non-null constraint: column ID

-- # A column of the table that isn't in the view can't be used.
CREATE VIEW v AS SELECT id, x FROM t;
INSERT INTO v (id, y) VALUES (4, 'd');
UPDATE v SET y = 'd';
-- msg: CREATE VIEW 1
-- error 42703: no such column: Y
-- error 42703: no such column: Y

-- # A view isn't updatable if its query has a set operator, DISTINCT, GROUP BY,
-- # an aggregate function, more than one table, a column that isn't a column of
-- # the table (or a column more than once), an OFFSET or FETCH FIRST, a table
-- # that isn't a base table or updatable view, or a subquery in the WHERE that
-- # reads the same table (7.16, Syntax Rules, 22 to 25, and 7.17, Syntax Rules,
-- # 7 and 11).
CREATE VIEW v1 AS SELECT id FROM t UNION SELECT id FROM t;
CREATE VIEW v2 AS SELECT DISTINCT x FROM t;
CREATE VIEW v3 AS SELECT x FROM t GROUP BY x;
CREATE VIEW v4 AS SELECT COUNT(*) AS c FROM t;
CREATE VIEW v5 AS SELECT a.id FROM t AS a, t AS b;
CREATE VIEW v6 AS SELECT id, x + 1 AS x FROM t;
CREATE VIEW v7 AS SELECT id, x, x AS z FROM t;
CREATE VIEW v8 AS SELECT id FROM t FETCH FIRST 1 ROW ONLY;
CREATE VIEW v9 AS SELECT * FROM (SELECT id FROM t) AS d;
CREATE VIEW v10 AS SELECT * FROM v1;
CREATE VIEW v11 AS SELECT id FROM t WHERE x > (SELECT MIN(x) FROM t);
CREATE VIEW v12 AS SELECT * FROM information_schema.schemata;
CREATE VIEW v13 AS VALUES 1;
INSERT INTO v1 VALUES (4);
UPDATE v2 SET x = 1;
DELETE FROM v3;
DELETE FROM v4;
DELETE FROM v5;
DELETE FROM v6;
DELETE FROM v7;
DELETE FROM v8;
DELETE FROM v9;
DELETE FROM v10;
DELETE FROM v11;
DELETE FROM v12;
DELETE FROM v13;
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- error 42601: syntax error: view ":memory:".PUBLIC.V1 is not updatable
-- error 42601: syntax error: view ":memory:".PUBLIC.V2 is not updatable
-- error 42601: syntax error: view ":memory:".PUBLIC.V3 is not updatable
-- error 42601: syntax error: view ":memory:".PUBLIC.V4 is not updatable
-- error 42601: syntax error: view ":memory:".PUBLIC.V5 is not updatable
-- error 42601: syntax error: view ":memory:".PUBLIC.V6 is not updatable
-- error 42601: syntax error: view ":memory:".PUBLIC.V7 is not updatable
-- error 42601: syntax error: view ":memory:".PUBLIC.V8 is not updatable
-- error 42601: syntax error: view ":memory:".PUBLIC.V9 is not updatable
-- error 42601: syntax error: view ":memory:".PUBLIC.V10 is not updatable
-- error 42601: syntax error: view ":memory:".PUBLIC.V11 is not updatable
-- error 42601: syntax error: view ":memory:".PUBLIC.V12 is not updatable
-- error 42601: syntax error: view ":memory:".PUBLIC.V13 is not updatable

-- # A view with an ORDER BY is updatable.
CREATE VIEW v AS SELECT id, x FROM t ORDER BY x DESC;
UPDATE v SET x = 1 WHERE id = 1;
SELECT * FROM v;
-- msg: CREATE VIEW 1
-- msg: UPDATE 1
-- ID: 3 X: 30
-- ID: 2 X: 20
-- ID: 1 X: 1

-- # The names in the view are those of its schema.
CREATE SCHEMA s;
CREATE TABLE s.t (a INT);
CREATE VIEW s.v AS SELECT a FROM t;
INSERT INTO s.v VALUES (7);
UPDATE s.v SET a = a + 1;
SELECT * FROM s.t;
SELECT COUNT(*) FROM t;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: CREATE VIEW 1
-- msg: INSERT 1
-- msg: UPDATE 1
-- A: 8
-- COL1: 3

-- # The INFORMATION_SCHEMA says which views are updatable and insertable-into.
CREATE VIEW v AS SELECT id, x FROM t;
CREATE VIEW w AS SELECT DISTINCT x FROM t;
SELECT table_name, is_updatable, insertable_into FROM information_schema.views WHERE table_schema = 'PUBLIC';
SELECT table_name, is_insertable_into FROM information_schema.tables WHERE table_schema = 'PUBLIC';
SELECT table_name, column_name, is_updatable FROM information_schema.columns WHERE table_schema = 'PUBLIC' AND table_name <> 'T';
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- TABLE_NAME: V IS_UPDATABLE: YES INSERTABLE_INTO: YES
-- TABLE_NAME: W IS_UPDATABLE: NO INSERTABLE_INTO: NO
-- TABLE_NAME: T IS_INSERTABLE_INTO: YES
-- TABLE_NAME: V IS_INSERTABLE_INTO: YES
-- TABLE_NAME: W IS_INSERTABLE_INTO: NO
-- TABLE_NAME: V COLUMN_NAME: ID IS_UPDATABLE: YES
-- TABLE_NAME: V COLUMN_NAME: X IS_UPDATABLE: YES
-- TABLE_NAME: W COLUMN_NAME: X IS_UPDATABLE: NO

-- # A change through a view is undone by a ROLLBACK.
CREATE VIEW v AS SELECT id, x FROM t;
START TRANSACTION;
DELETE FROM v;
SELECT COUNT(*) FROM t;
ROLLBACK;
SELECT COUNT(*) FROM t;
-- msg: CREATE VIEW 1
-- msg: START TRANSACTION
-- msg: DELETE 3
-- COL1: 0
-- msg: ROLLBACK
-- COL1: 3

-- # A cursor that reads an updatable view is updatable, and a positioned UPDATE
-- # or DELETE of the view changes the row of its base table.
/* extensions V108-01 V109-01 V110-01 V112-01 V113-01 */
CREATE VIEW v (a, b) AS SELECT id, x FROM t WHERE id > 1;
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM v WHERE b > 0;
OPEN c;
FETCH c;
UPDATE v SET b = 99 WHERE CURRENT OF c;
FETCH c;
DELETE FROM v WHERE CURRENT OF c;
DELETE FROM v WHERE CURRENT OF c;
DELETE FROM t WHERE CURRENT OF c;
SELECT * FROM t;
-- msg: CREATE VIEW 1
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- A: 2 B: 20
-- msg: UPDATE 1
-- A: 3 B: 30
-- msg: DELETE 1
-- error 24000: invalid cursor state: cursor C is not positioned on a row
-- error 42601: syntax error: table T is not the table of cursor C
-- ID: 1 X: 10 Y: a
-- ID: 2 X: 99 Y: b

-- # FOR UPDATE OF names the columns of the view, and a sort key can't be
-- # changed. A view that isn't updatable can't be.
/* extensions V108-01 V109-01 V110-01 V113-01 */
CREATE VIEW v (a, b) AS SELECT id, x FROM t;
CREATE VIEW w AS SELECT DISTINCT x FROM t;
START TRANSACTION;
DECLARE c1 CURSOR FOR SELECT * FROM v FOR UPDATE OF x;
DECLARE c2 CURSOR FOR SELECT * FROM v ORDER BY b FOR UPDATE OF a, b;
DECLARE c3 CURSOR FOR SELECT * FROM w FOR UPDATE;
OPEN c2;
FETCH c2;
UPDATE v SET b = 1 WHERE CURRENT OF c2;
UPDATE v SET a = 7 WHERE CURRENT OF c2;
SELECT * FROM t;
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: START TRANSACTION
-- error 42703: no such column: X
-- msg: DECLARE CURSOR
-- error 42601: syntax error: cursor C3 is not updatable
-- msg: OPEN
-- A: 1 B: 10
-- error 42601: syntax error: column B is used by a sort key of cursor C2
-- msg: UPDATE 1
-- ID: 2 X: 20 Y: b
-- ID: 3 X: 30 Y: c
-- ID: 7 X: 10 Y: a

-- # A query in parentheses, and an explicit table, are updatable too (7.17,
-- # Syntax Rules, 11.b and 11.c).
CREATE VIEW v AS (SELECT id, x FROM t);
CREATE VIEW w AS TABLE t;
UPDATE v SET x = 1;
UPDATE w SET x = 2;
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: UPDATE 3
-- msg: UPDATE 3
