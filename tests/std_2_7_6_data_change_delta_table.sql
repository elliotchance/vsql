/* setup */
CREATE TABLE t (id INT GENERATED ALWAYS AS IDENTITY, x INT NOT NULL, y VARCHAR(10) DEFAULT 'none');
INSERT INTO t (x, y) VALUES (1, 'a'), (2, 'b');

-- # FINAL TABLE and NEW TABLE are the new rows of an INSERT, with every column
-- # of the table (7.6, Syntax Rules, 10.c), including the values of an identity
-- # column and a default. The rows are inserted.
/* flags */
SELECT * FROM FINAL TABLE (INSERT INTO t (x) VALUES (3));
-- flags: T495
-- ID: 3 X: 3 Y: none

SELECT * FROM FINAL TABLE (INSERT INTO t (x) VALUES (3), (4));
SELECT * FROM t;
-- ID: 3 X: 3 Y: none
-- ID: 4 X: 4 Y: none
-- ID: 1 X: 1 Y: a
-- ID: 2 X: 2 Y: b
-- ID: 3 X: 3 Y: none
-- ID: 4 X: 4 Y: none

SELECT id, x FROM NEW TABLE (INSERT INTO t (x, y) SELECT x + 10, y FROM t);
SELECT COUNT(*) FROM t;
-- ID: 3 X: 11
-- ID: 4 X: 12
-- COL1: 4

-- # The query can filter, group and sort the rows, and a correlation name can
-- # rename the columns.
SELECT n.x FROM NEW TABLE (INSERT INTO t (x) VALUES (5), (6), (7)) AS n WHERE n.x > 5 ORDER BY n.x DESC;
-- X: 7
-- X: 6

SELECT c, COUNT(*) FROM FINAL TABLE (INSERT INTO t (x, y) VALUES (5, 'p'), (6, 'q'), (7, 'p')) AS n (a, b, c) GROUP BY c ORDER BY c;
-- C: p COL2: 2
-- C: q COL2: 1

-- # Without a correlation name, a column can only be referenced by its name.
SELECT t.x FROM NEW TABLE (INSERT INTO t (x) VALUES (5));
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.T.X

-- # OLD TABLE is the old rows of an UPDATE, and NEW TABLE and FINAL TABLE are
-- # the new rows. A row that the UPDATE identifies is in both, even when none
-- # of its values change.
SELECT * FROM OLD TABLE (UPDATE t SET y = 'c' WHERE x = 2);
SELECT * FROM t;
-- ID: 2 X: 2 Y: b
-- ID: 1 X: 1 Y: a
-- ID: 2 X: 2 Y: c

SELECT * FROM NEW TABLE (UPDATE t SET x = x * 10);
-- ID: 1 X: 10 Y: a
-- ID: 2 X: 20 Y: b

SELECT * FROM FINAL TABLE (UPDATE t SET y = 'a' WHERE x = 1);
-- ID: 1 X: 1 Y: a

-- # OLD TABLE is the rows that a DELETE deletes.
SELECT * FROM OLD TABLE (DELETE FROM t WHERE x = 1);
SELECT * FROM t;
-- ID: 1 X: 1 Y: a
-- ID: 2 X: 2 Y: b

SELECT COUNT(*) FROM OLD TABLE (DELETE FROM t);
SELECT COUNT(*) FROM t;
-- COL1: 2
-- COL1: 0

-- # When the statement doesn't change any rows it's a no data warning, and the
-- # query has no rows.
SELECT * FROM OLD TABLE (DELETE FROM t WHERE x = 3);
-- warning 02000: no data

SELECT * FROM NEW TABLE (UPDATE t SET x = 3 WHERE x = 3);
-- warning 02000: no data

-- # An INSERT has no old rows, and a DELETE has no new rows (7.6, Syntax Rules,
-- # 10.a.i and 10.a.ii).
SELECT * FROM OLD TABLE (INSERT INTO t (x) VALUES (3));
-- error 42601: syntax error: OLD TABLE cannot be used with INSERT

SELECT * FROM NEW TABLE (DELETE FROM t);
-- error 42601: syntax error: NEW TABLE cannot be used with DELETE

SELECT * FROM FINAL TABLE (DELETE FROM t);
-- error 42601: syntax error: FINAL TABLE cannot be used with DELETE

-- # The table must exist.
SELECT * FROM NEW TABLE (INSERT INTO foo (x) VALUES (3));
-- error 42P01: no such table: ":memory:".PUBLIC.FOO

-- # When the statement fails, nothing is changed.
SELECT * FROM NEW TABLE (INSERT INTO t (x) VALUES (3), (NULL));
SELECT COUNT(*) FROM t;
-- error 23502: violates non-null constraint: column X
-- COL1: 2

-- # A data change delta table can only be the only table in the FROM of a
-- # query that's a statement (7.5, Syntax Rules, 3; 7.10, Syntax Rules, 2; 7.17,
-- # Syntax Rules, 2; 7.19, Syntax Rules, 1). So it can't be in a subquery, which
-- # includes one in a CASE abbreviation (6.12, Syntax Rules, 1.b and 2.b), and
-- # nothing is changed.
SELECT * FROM t, NEW TABLE (INSERT INTO t (x) VALUES (3)) AS n;
-- error 42601: syntax error: NEW TABLE can only be the only table in the FROM of a query that is a statement or cursor

SELECT * FROM t JOIN NEW TABLE (INSERT INTO t (x) VALUES (3)) AS n ON t.x = n.x;
-- error 42601: syntax error: NEW TABLE can only be the only table in the FROM of a query that is a statement or cursor

SELECT * FROM (SELECT * FROM OLD TABLE (DELETE FROM t)) AS d;
SELECT COUNT(*) FROM t;
-- error 42601: syntax error: OLD TABLE can only be the only table in the FROM of a query that is a statement or cursor
-- COL1: 2

SELECT x FROM t WHERE x IN (SELECT x FROM NEW TABLE (INSERT INTO t (x) VALUES (3)));
-- error 42601: syntax error: NEW TABLE can only be the only table in the FROM of a query that is a statement or cursor

SELECT COALESCE((SELECT MAX(x) FROM OLD TABLE (DELETE FROM t)), 0) FROM t;
-- error 42601: syntax error: OLD TABLE can only be the only table in the FROM of a query that is a statement or cursor

SELECT x FROM t UNION SELECT x FROM NEW TABLE (INSERT INTO t (x) VALUES (3));
-- error 42601: syntax error: NEW TABLE can only be the only table in the FROM of a query that is a statement or cursor

INSERT INTO t (x) SELECT x FROM OLD TABLE (DELETE FROM t);
SELECT COUNT(*) FROM t;
-- error 42601: syntax error: OLD TABLE can only be the only table in the FROM of a query that is a statement or cursor
-- COL1: 2

-- # EXPLAIN shows the statement without running it.
/* extensions V001-01 */
EXPLAIN SELECT x FROM FINAL TABLE (INSERT INTO t (x) VALUES (3)) AS n;
SELECT COUNT(*) FROM t;
-- EXPLAIN: N:
-- EXPLAIN:   FINAL TABLE (INSERT INTO T) (ID INTEGER NOT NULL, X INTEGER NOT NULL, Y CHARACTER VARYING(10))
-- EXPLAIN: TABLE N (ID INTEGER NOT NULL, X INTEGER NOT NULL, Y CHARACTER VARYING(10))
-- EXPLAIN: EXPR (X INTEGER NOT NULL)
-- COL1: 2

-- # The statement changes the database, so it can't be in a READ ONLY
-- # transaction.
START TRANSACTION READ ONLY;
SELECT * FROM NEW TABLE (UPDATE t SET x = 3);
-- msg: START TRANSACTION
-- error 25006: read-only sql transaction: cannot execute UPDATE

-- # A referential action can't change the table of a FINAL TABLE (15.17,
-- # General Rules, 15), but it can change the table of a NEW TABLE.
CREATE TABLE tree (id INT NOT NULL PRIMARY KEY, parent INT REFERENCES tree (id) ON UPDATE CASCADE);
INSERT INTO tree (id, parent) VALUES (1, NULL), (2, 1);
SELECT * FROM FINAL TABLE (UPDATE tree SET id = 10 WHERE id = 1);
SELECT * FROM NEW TABLE (UPDATE tree SET id = 10 WHERE id = 1);
SELECT * FROM tree;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- error 27001: triggered data change violation: modify table modified by data change delta table: ":memory:".PUBLIC.TREE
-- ID: 10 PARENT: NULL
-- ID: 2 PARENT: 10
-- ID: 10 PARENT: NULL

-- # FINAL TABLE only restricts its own table.
CREATE TABLE parent (id INT NOT NULL PRIMARY KEY);
CREATE TABLE child (parent INT REFERENCES parent (id) ON UPDATE CASCADE);
INSERT INTO parent (id) VALUES (1);
INSERT INTO child (parent) VALUES (1);
SELECT * FROM FINAL TABLE (UPDATE parent SET id = 2);
SELECT * FROM child;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- ID: 2
-- PARENT: 2

-- # The query of a cursor can also contain a data change delta table (4.39.2.3),
-- # and the statement runs each time the cursor is opened.
/* extensions V108-01 V109-01 V110-01 V111-01 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT x FROM NEW TABLE (INSERT INTO t (x) VALUES (3), (4));
SELECT COUNT(*) FROM t;
OPEN c;
FETCH NEXT FROM c;
SELECT COUNT(*) FROM t;
CLOSE c;
OPEN c;
SELECT COUNT(*) FROM t;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- COL1: 2
-- msg: OPEN
-- X: 3
-- COL1: 4
-- msg: CLOSE
-- msg: OPEN
-- COL1: 6

-- # The cursor can't be updatable (7.6, Syntax Rules, 20.a; 7.16, Syntax Rules,
-- # 24.e).
/* extensions V108-01 */
DECLARE c CURSOR FOR SELECT x FROM NEW TABLE (INSERT INTO t (x) VALUES (3)) FOR UPDATE;
-- error 42601: syntax error: cursor C is not updatable

-- # Opening it changes the database, so it can't be opened in a READ ONLY
-- # transaction.
/* extensions V108-01 V109-01 */
START TRANSACTION READ ONLY;
DECLARE c CURSOR FOR SELECT * FROM OLD TABLE (DELETE FROM t);
OPEN c;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- error 25006: read-only sql transaction: cannot execute DELETE
