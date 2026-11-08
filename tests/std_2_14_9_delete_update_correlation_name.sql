/* setup */
CREATE TABLE t (id INT PRIMARY KEY, x INT);
CREATE TABLE s (id INT, y INT);
INSERT INTO t (id, x) VALUES (1, 10);
INSERT INTO t (id, x) VALUES (2, 20);
INSERT INTO t (id, x) VALUES (3, 30);
INSERT INTO s (id, y) VALUES (2, 200);
INSERT INTO s (id, y) VALUES (9, 900);

-- # A searched DELETE, with and without AS.
DELETE FROM t AS u WHERE u.x = 10;
DELETE FROM t v WHERE v.x = 20;
SELECT * FROM t;
-- msg: DELETE 1
-- msg: DELETE 1
-- ID: 3 X: 30

-- # Without a WHERE every row is deleted.
DELETE FROM t AS u;
DELETE FROM s v;
SELECT * FROM t;
SELECT * FROM s;
-- msg: DELETE 3
-- msg: DELETE 2

-- # A column doesn't have to be qualified.
DELETE FROM t AS u WHERE x = 10;
SELECT * FROM t;
-- msg: DELETE 1
-- ID: 2 X: 20
-- ID: 3 X: 30

-- # The primary key is still used to find a row.
DELETE FROM t AS u WHERE u.id = 2;
SELECT * FROM t;
-- msg: DELETE 1
-- ID: 1 X: 10
-- ID: 3 X: 30

-- # The correlation name hides the name of the table.
DELETE FROM t AS u WHERE t.x = 1;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.T.X

DELETE FROM t u WHERE t.x = 1;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.T.X

DELETE FROM t AS u WHERE public.t.x = 1;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.T.X

DELETE FROM t AS u WHERE t.id = 1;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.T.ID

UPDATE t AS u SET x = 1 WHERE t.x = 1;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.T.X

UPDATE t AS u SET x = t.x + 1;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.T.X

-- # It's the same in a subquery.
DELETE FROM t AS u WHERE EXISTS (SELECT * FROM s WHERE s.id = t.id);
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.T.ID

UPDATE t AS u SET x = (SELECT y FROM s WHERE s.id = t.id);
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.T.ID

-- # An unknown column of the correlation name.
DELETE FROM t AS u WHERE u.nope = 1;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.U.NOPE

UPDATE t AS u SET x = u.nope;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.U.NOPE

-- # The set clauses are still checked when no row is found.
UPDATE t AS u SET x = u.nope WHERE u.id = 99;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.U.NOPE

UPDATE t AS u SET x = t.x WHERE u.id = 99;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.T.X

UPDATE t AS u SET x = 'a' WHERE u.id = 99;
-- error 42846: cannot coerce CHARACTER(1) to INTEGER

UPDATE t AS u SET x = u.x + 1 WHERE u.id = 99;
SELECT * FROM t;
-- warning 02000: no data
-- msg: UPDATE 0
-- ID: 1 X: 10
-- ID: 2 X: 20
-- ID: 3 X: 30

-- # The correlation name can be the name of the table, or of another table.
DELETE FROM t AS t WHERE t.x = 10;
DELETE FROM t AS s WHERE s.x = 20;
UPDATE t AS s SET x = s.x + 1;
SELECT * FROM t;
-- msg: DELETE 1
-- msg: DELETE 1
-- msg: UPDATE 1
-- ID: 3 X: 31

-- # "t AS t" is only known as T, so it can't be qualified with the schema.
DELETE FROM t AS t WHERE public.t.x = 10;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.T.X

-- # A delimited correlation name.
DELETE FROM t AS "u v" WHERE "u v".x = 10;
UPDATE t AS "lower" SET x = "lower".x + 1 WHERE "lower".x = 20;
SELECT * FROM t;
-- msg: DELETE 1
-- msg: UPDATE 1
-- ID: 2 X: 21
-- ID: 3 X: 30

-- # It's the same for a table in a SELECT, and for a derived table.
SELECT "u v".x FROM t AS "u v" WHERE "u v".id = 1;
SELECT "lower".a FROM (VALUES ROW(1)) AS "lower" (a);
-- X: 10
-- A: 1

-- # A correlation name is case-insensitive unless it's delimited.
DELETE FROM t AS u WHERE U.x = 10;
SELECT * FROM t;
-- msg: DELETE 1
-- ID: 2 X: 20
-- ID: 3 X: 30

DELETE FROM t AS "u" WHERE u.x = 10;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.U.X

-- # A target table in another schema.
CREATE SCHEMA other;
CREATE TABLE other.t (a INT, b INT);
INSERT INTO other.t (a, b) VALUES (1, 2);
INSERT INTO other.t (a, b) VALUES (3, 4);
UPDATE other.t AS u SET a = u.a + u.b WHERE u.a = 1;
DELETE FROM other.t AS u WHERE u.b = 4;
SELECT * FROM other.t;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: UPDATE 1
-- msg: DELETE 1
-- A: 3 B: 2

-- # A searched UPDATE, with and without AS, and with and without a WHERE.
UPDATE t AS u SET x = 11 WHERE u.x = 10;
UPDATE t v SET x = 21 WHERE v.x = 20;
SELECT * FROM t;
UPDATE t AS u SET x = 0;
UPDATE t v SET id = v.id + 10;
SELECT * FROM t;
-- msg: UPDATE 1
-- msg: UPDATE 1
-- ID: 1 X: 11
-- ID: 2 X: 21
-- ID: 3 X: 30
-- msg: UPDATE 3
-- msg: UPDATE 3
-- ID: 11 X: 0
-- ID: 12 X: 0
-- ID: 13 X: 0

-- # The set clauses use the correlation name, and don't have to.
UPDATE t AS u SET x = u.x + 1, id = id + 10 WHERE u.id = 1;
SELECT * FROM t;
-- msg: UPDATE 1
-- ID: 2 X: 20
-- ID: 3 X: 30
-- ID: 11 X: 11

-- # A set clause sees the old value of each column.
UPDATE t AS u SET x = u.id, id = u.x;
SELECT * FROM t;
-- msg: UPDATE 3
-- ID: 10 X: 1
-- ID: 20 X: 2
-- ID: 30 X: 3

-- # A row that doesn't change is still counted.
UPDATE t AS u SET x = u.x;
-- msg: UPDATE 3

-- # NULL and DEFAULT.
CREATE TABLE d (id INT, x INT DEFAULT 7, y INT NOT NULL);
INSERT INTO d (id, x, y) VALUES (1, 1, 1);
UPDATE d AS u SET x = DEFAULT WHERE u.id = 1;
SELECT * FROM d;
UPDATE d AS u SET x = NULL WHERE u.id = 1;
SELECT * FROM d;
UPDATE d AS u SET y = NULL WHERE u.id = 1;
UPDATE d AS u SET y = NULL WHERE u.id = 2;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: UPDATE 1
-- ID: 1 X: 7 Y: 1
-- msg: UPDATE 1
-- ID: 1 X: NULL Y: 1
-- error 23502: violates non-null constraint: column Y
-- error 23502: violates non-null constraint: column Y

-- # A column can't be set more than once, and a generated column can't be set.
UPDATE t AS u SET x = 1, x = 2;
-- error 42601: syntax error: column X is set more than once

CREATE TABLE g (a INT, b INT GENERATED ALWAYS AS (a + 1));
INSERT INTO g (a) VALUES (1);
UPDATE g AS u SET a = u.a + 1;
SELECT * FROM g;
UPDATE g AS u SET b = 1;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: UPDATE 1
-- A: 2 B: 3
-- error 428C9: cannot assign a value other than DEFAULT to column B, which is GENERATED ALWAYS

-- # A CHECK and a FOREIGN KEY apply as usual.
CREATE TABLE c (x INT CHECK (x > 0));
INSERT INTO c (x) VALUES (1);
UPDATE c AS u SET x = u.x - 1;
SELECT * FROM c;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 23514: violates check constraint: CHECK (X > 0) on ":memory:".PUBLIC.C
-- X: 1

CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (id INT PRIMARY KEY, parent_id INT REFERENCES parent ON DELETE CASCADE ON UPDATE CASCADE);
INSERT INTO parent (id) VALUES (1);
INSERT INTO child (id, parent_id) VALUES (1, 1);
UPDATE parent AS u SET id = u.id + 1;
SELECT * FROM child;
DELETE FROM parent AS u WHERE u.id = 2;
SELECT * FROM child;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: UPDATE 1
-- ID: 1 PARENT_ID: 2
-- msg: DELETE 1

-- # A correlated subquery in the WHERE.
DELETE FROM t AS u WHERE EXISTS (SELECT * FROM s WHERE s.id = u.id);
SELECT * FROM t;
-- msg: DELETE 1
-- ID: 1 X: 10
-- ID: 3 X: 30

UPDATE t AS u SET x = 0 WHERE u.id IN (SELECT id FROM s WHERE s.id = u.id);
SELECT * FROM t;
-- msg: UPDATE 1
-- ID: 1 X: 10
-- ID: 2 X: 0
-- ID: 3 X: 30

-- # A correlated subquery in a set clause.
UPDATE t AS u SET x = (SELECT y + u.x FROM s WHERE s.id = u.id);
SELECT * FROM t;
-- msg: UPDATE 3
-- ID: 1 X: NULL
-- ID: 2 X: 220
-- ID: 3 X: NULL

-- # A subquery can read the target table by its own name.
DELETE FROM t AS u WHERE u.x = (SELECT MAX(t.x) FROM t);
SELECT * FROM t;
-- msg: DELETE 1
-- ID: 1 X: 10
-- ID: 2 X: 20

UPDATE t AS u SET x = (SELECT COUNT(*) FROM t WHERE t.x < u.x);
SELECT * FROM t;
-- msg: UPDATE 3
-- ID: 1 X: 0
-- ID: 2 X: 1
-- ID: 3 X: 2

-- # A derived column list isn't allowed.
DELETE FROM t AS u (a, b);
-- error 42601: syntax error: unexpected "("

UPDATE t AS u (a, b) SET a = 1;
-- error 42601: syntax error: unexpected "(", expecting SET

-- # A reserved word can't be the correlation name, and neither can a qualified
-- # name.
DELETE FROM t AS WHERE x = 1;
-- error 42601: syntax error: unexpected WHERE

UPDATE t AS SET x = 1;
-- error 42601: syntax error: unexpected SET

DELETE FROM t AS a.b;
-- error 42601: syntax error: unexpected "."

-- # EXPLAIN.
/* extensions V001-02 */
EXPLAIN DELETE FROM t AS u WHERE u.x = 10;
-- EXPLAIN: U:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.T (ID INTEGER NOT NULL, X INTEGER)
-- EXPLAIN: TABLE U (ID INTEGER NOT NULL, X INTEGER)
-- EXPLAIN: WHERE U.X = 10

/* extensions V001-03 */
EXPLAIN UPDATE t u SET x = 1 WHERE u.id = 1;
-- EXPLAIN: U:
-- EXPLAIN:   PRIMARY KEY ":memory:".PUBLIC.T (ID INTEGER NOT NULL, X INTEGER) RANGE U.ID = 1
-- EXPLAIN: TABLE U (ID INTEGER NOT NULL, X INTEGER)
-- EXPLAIN: WHERE U.ID = 1

-- # A positioned DELETE.
/* extensions V108-01 V109-01 V110-01 V111-01 V112-01 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM t;
OPEN c;
FETCH c;
DELETE FROM t AS u WHERE CURRENT OF c;
FETCH c;
DELETE FROM t v WHERE CURRENT OF c;
CLOSE c;
SELECT * FROM t;
COMMIT;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- ID: 1 X: 10
-- msg: DELETE 1
-- ID: 2 X: 20
-- msg: DELETE 1
-- msg: CLOSE
-- ID: 3 X: 30
-- msg: COMMIT

-- # A positioned UPDATE.
/* extensions V108-01 V109-01 V110-01 V111-01 V113-01 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM t;
OPEN c;
FETCH c;
UPDATE t AS u SET x = u.x + 1 WHERE CURRENT OF c;
FETCH c;
UPDATE t v SET x = v.x + (SELECT y FROM s WHERE s.id = v.id) WHERE CURRENT OF c;
CLOSE c;
SELECT * FROM t;
COMMIT;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- ID: 1 X: 10
-- msg: UPDATE 1
-- ID: 2 X: 20
-- msg: UPDATE 1
-- msg: CLOSE
-- ID: 1 X: 11
-- ID: 2 X: 220
-- ID: 3 X: 30
-- msg: COMMIT

-- # A positioned statement hides the name of the table in a set clause.
/* extensions V108-01 V109-01 V110-01 V113-01 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM t;
OPEN c;
FETCH c;
UPDATE t AS u SET x = t.x + 1 WHERE CURRENT OF c;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- ID: 1 X: 10
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.T.X

-- # The cursor is matched by the table name, not the correlation name.
/* extensions V108-01 V109-01 V110-01 V112-01 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM t;
OPEN c;
FETCH c;
DELETE FROM s AS t WHERE CURRENT OF c;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- ID: 1 X: 10
-- error 42601: syntax error: table S is not the table of cursor C

/* extensions V108-01 V109-01 V110-01 V113-01 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM t;
OPEN c;
FETCH c;
UPDATE s AS t SET y = 1 WHERE CURRENT OF c;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- ID: 1 X: 10
-- error 42601: syntax error: table S is not the table of cursor C

-- # The column of a positioned UPDATE must still be updatable by the cursor.
/* extensions V108-01 V109-01 V110-01 V113-01 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM t FOR UPDATE OF x;
OPEN c;
FETCH c;
UPDATE t AS u SET id = 5 WHERE CURRENT OF c;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- ID: 1 X: 10
-- error 42601: syntax error: column ID is not updatable by cursor C

-- # Another catalog.
/* create_catalog FOO */
SET CATALOG 'FOO';
CREATE TABLE foo.public.bar (baz INTEGER);
INSERT INTO foo.public.bar (baz) VALUES (123);
UPDATE foo.public.bar AS u SET baz = u.baz + 1 WHERE u.baz = 123;
SELECT * FROM foo.public.bar;
DELETE FROM foo.public.bar AS u WHERE u.baz = 124;
SELECT * FROM foo.public.bar;
DROP TABLE foo.public.bar RESTRICT;
-- msg: SET CATALOG 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: UPDATE 1
-- BAZ: 124
-- msg: DELETE 1
-- msg: DROP TABLE 1
