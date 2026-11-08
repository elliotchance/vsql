/* setup */
CREATE TABLE foo (x INT, y INT);
INSERT INTO foo (x, y) VALUES (3, 4);
INSERT INTO foo (x, y) VALUES (3, 6);
CREATE TABLE bar (z INT);
INSERT INTO bar (z) VALUES (5);

-- # A plain * must be the whole select list, so it can't be mixed with other
-- # columns or repeated.
SELECT *, 1 FROM foo;
-- error 42601: syntax error: unexpected ",", expecting FROM

SELECT 1, * FROM foo;
-- error 42601: syntax error: unexpected "*"

SELECT *, * FROM foo;
-- error 42601: syntax error: unexpected ",", expecting FROM

-- # A qualified asterisk is all the columns of its table, in order (Syntax
-- # Rules, 8.g.i). It can be mixed with other columns, repeated, and used for
-- # more than one table, and the other columns are named by their position.
SELECT foo.*, ABS(10 - x) FROM foo;
-- X: 3 Y: 4 COL3: 7
-- X: 3 Y: 6 COL3: 7

SELECT ABS(10 - x), foo.* FROM foo;
-- COL1: 7 X: 3 Y: 4
-- COL1: 7 X: 3 Y: 6

SELECT 1, foo.*, y AS w FROM foo;
-- COL1: 1 X: 3 Y: 4 W: 4
-- COL1: 1 X: 3 Y: 6 W: 6

SELECT foo.*, foo.* FROM foo;
-- X: 3 Y: 4 X: 3 Y: 4
-- X: 3 Y: 6 X: 3 Y: 6

SELECT bar.*, foo.*, x FROM foo JOIN bar ON TRUE;
-- Z: 5 X: 3 Y: 4 X: 3
-- Z: 5 X: 3 Y: 6 X: 3

/* extensions V001-01 */
EXPLAIN SELECT foo.*, 1 FROM foo;
-- EXPLAIN: TABLE ":memory:".PUBLIC.FOO (X INTEGER, Y INTEGER)
-- EXPLAIN: EXPR (":memory:".PUBLIC.FOO.X INTEGER, ":memory:".PUBLIC.FOO.Y INTEGER, COL3 SMALLINT)

-- # The table of a qualified asterisk must be in the FROM clause (Syntax Rules,
-- # 8.f.vii).
SELECT foo.*, baz.* FROM foo;
-- error 42P01: no such table: ":memory:".PUBLIC.BAZ

-- # A qualified asterisk works with GROUP BY and ORDER BY, and with the
-- # correlation name of a derived table.
SELECT foo.*, COUNT(*) FROM foo GROUP BY x, y;
-- X: 3 Y: 4 COL3: 1
-- X: 3 Y: 6 COL3: 1

SELECT foo.* FROM foo ORDER BY y DESC;
-- X: 3 Y: 6
-- X: 3 Y: 4

SELECT t.* FROM (SELECT x FROM foo) AS t;
-- X: 3
-- X: 3

SELECT t.*, 1 FROM (VALUES 1) AS t (x);
-- X: 1 COL2: 1

SELECT 1, t.*, bar.* FROM (VALUES 2) AS t (x) JOIN bar ON TRUE;
-- COL1: 1 X: 2 Z: 5

-- # A correlation name that isn't in the FROM clause is an error too.
SELECT u.* FROM (VALUES 1) AS t (x);
-- error 42P01: no such table: ":memory:".PUBLIC.U

-- # It also works for a table that another connection created.
/* connection 1 */
CREATE TABLE foo (x INT);
INSERT INTO foo (x) VALUES (1);
/* connection 2 */
SELECT foo.* FROM foo;
SELECT foo.*, x + 1 FROM foo;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 2: X: 1
-- 2: X: 1 COL2: 2
