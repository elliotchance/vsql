/* setup */
CREATE TABLE t (x INTEGER, y INTEGER, z INTEGER);
INSERT INTO t (x, y, z) VALUES (1, 30, 200);
INSERT INTO t (x, y, z) VALUES (2, 10, 300);
INSERT INTO t (x, y, z) VALUES (3, 20, 100);
CREATE TABLE u (x INTEGER, w INTEGER);
INSERT INTO u (x, w) VALUES (1, 3);
INSERT INTO u (x, w) VALUES (2, 1);
INSERT INTO u (x, w) VALUES (3, 2);
CREATE TABLE col (col1 INTEGER, col2 INTEGER);
INSERT INTO col (col1, col2) VALUES (1, 20);
INSERT INTO col (col1, col2) VALUES (2, 10);
CREATE TABLE d (a INTEGER, b INTEGER);
INSERT INTO d (a, b) VALUES (1, 5);
INSERT INTO d (a, b) VALUES (1, 6);
INSERT INTO d (a, b) VALUES (2, 7);
CREATE TABLE g (a INTEGER, b INTEGER);
INSERT INTO g (a, b) VALUES (1, 5);
INSERT INTO g (a, b) VALUES (1, 6);
INSERT INTO g (a, b) VALUES (2, 1);
INSERT INTO g (a, b) VALUES (3, 2);
INSERT INTO g (a, b) VALUES (3, 3);
INSERT INTO g (a, b) VALUES (3, 4);
CREATE SEQUENCE seq;

-- # The alias of a column, and of an expression.
SELECT x AS a FROM t ORDER BY a DESC;
SELECT y + 1 AS a FROM t ORDER BY a;
SELECT y + 1 AS a FROM t ORDER BY a DESC;
SELECT x, y AS a, z AS b FROM t ORDER BY b, a;
-- A: 3
-- A: 2
-- A: 1
-- A: 11
-- A: 21
-- A: 31
-- A: 31
-- A: 21
-- A: 11
-- X: 3 A: 20 B: 100
-- X: 1 A: 30 B: 200
-- X: 2 A: 10 B: 300

-- # A NULL is sorted the same as if it was the column.
SELECT NULLIF(x, 2) AS a FROM t ORDER BY a;
SELECT NULLIF(x, 2) AS a FROM t ORDER BY a DESC;
-- A: NULL
-- A: 1
-- A: 3
-- A: 3
-- A: 1
-- A: NULL

-- # An alias hides a column of the table with the same name, but a qualified
-- # name is still the column of the table. A column that doesn't have the alias
-- # is still the column of the table too.
SELECT -x AS x FROM t ORDER BY x;
SELECT -x AS x FROM t ORDER BY t.x;
SELECT y AS x, x AS y FROM t ORDER BY x;
SELECT y AS x, x AS y FROM t ORDER BY y;
SELECT y AS x FROM t ORDER BY z;
SELECT y AS a FROM t ORDER BY y;
-- X: -3
-- X: -2
-- X: -1
-- X: -1
-- X: -2
-- X: -3
-- X: 10 Y: 2
-- X: 20 Y: 3
-- X: 30 Y: 1
-- X: 30 Y: 1
-- X: 10 Y: 2
-- X: 20 Y: 3
-- X: 20
-- X: 30
-- X: 10
-- A: 10
-- A: 20
-- A: 30

-- # It can be inside of an expression, where it can also be used with a column
-- # that isn't in the select list. It also hides the column of the table there.
SELECT y AS a FROM t ORDER BY a + 1 DESC;
SELECT y AS a FROM t ORDER BY ABS(a - 25);
SELECT y AS a FROM t ORDER BY a + z;
SELECT -x AS x FROM t ORDER BY x * 2;
SELECT -x AS x FROM t ORDER BY t.x * 2;
-- A: 30
-- A: 20
-- A: 10
-- A: 30
-- A: 20
-- A: 10
-- A: 20
-- A: 30
-- A: 10
-- X: -3
-- X: -2
-- X: -1
-- X: -1
-- X: -2
-- X: -3

-- # A column of the result can be used even if the name is in more than one
-- # table, and without an alias. A name that isn't a column of the result is
-- # ambiguous if more than one table has it.
SELECT t.x FROM t JOIN u ON t.x = u.x ORDER BY x DESC;
SELECT t.y AS w, u.w AS y FROM t JOIN u ON t.x = u.x ORDER BY w;
SELECT t.y AS w, u.w AS y FROM t JOIN u ON t.x = u.x ORDER BY u.w;
SELECT y FROM t JOIN u ON t.x = u.x ORDER BY x;
-- X: 3
-- X: 2
-- X: 1
-- W: 10 Y: 1
-- W: 20 Y: 2
-- W: 30 Y: 3
-- W: 10 Y: 1
-- W: 20 Y: 2
-- W: 30 Y: 3
-- error 42702: ambiguous column: X

-- # A name is ambiguous if it's more than one column of the result, even in an
-- # expression, and even if they're the same expression. It's fine as long as
-- # it isn't used.
SELECT x AS a, y AS a FROM t ORDER BY a;
SELECT x AS a, y AS a FROM t ORDER BY a + 1;
SELECT x AS a, x AS a FROM t ORDER BY a;
SELECT x, y AS x FROM t ORDER BY x;
SELECT t.*, y AS x FROM t ORDER BY x;
SELECT t.x, u.x FROM t JOIN u ON t.x = u.x ORDER BY x;
SELECT x AS a, y AS a FROM t ORDER BY z;
SELECT x AS a, y AS a FROM t ORDER BY t.x DESC;
-- error 42702: ambiguous column: A
-- error 42702: ambiguous column: A
-- error 42702: ambiguous column: A
-- error 42702: ambiguous column: X
-- error 42702: ambiguous column: X
-- error 42702: ambiguous column: X
-- A: 3 A: 20
-- A: 1 A: 30
-- A: 2 A: 10
-- A: 3 A: 20
-- A: 2 A: 10
-- A: 1 A: 30

-- # An unnamed column has an implementation-dependent name, so it doesn't hide
-- # a column of a table or make a name ambiguous.
SELECT -col1 FROM col ORDER BY col1;
SELECT col1 + 1, col2 AS col1 FROM col ORDER BY col1;
SELECT col2 AS col2, col1 + 1 FROM col ORDER BY col2;
-- COL1: -1
-- COL1: -2
-- COL1: 3 COL1: 10
-- COL1: 2 COL1: 20
-- COL2: 10 COL2: 3
-- COL2: 20 COL2: 2

-- # With DISTINCT, the alias is in the select list so it's always allowed, but
-- # a column of the table has to be.
SELECT DISTINCT a AS c FROM d ORDER BY c DESC;
SELECT DISTINCT a + 1 AS c FROM d ORDER BY c DESC;
SELECT DISTINCT a + 1 AS c FROM d ORDER BY c * 2 DESC;
SELECT DISTINCT -a AS a FROM d ORDER BY a;
SELECT DISTINCT a + 1 AS c FROM d ORDER BY c + b;
SELECT DISTINCT a + 1 AS c FROM d ORDER BY a;
SELECT DISTINCT a AS c, a AS c FROM d ORDER BY c;
-- C: 2
-- C: 1
-- C: 3
-- C: 2
-- C: 3
-- C: 2
-- A: -2
-- A: -1
-- error 42P10: column B must be in the select list to be used in ORDER BY with SELECT DISTINCT
-- error 42P10: column A must be in the select list to be used in ORDER BY with SELECT DISTINCT
-- error 42702: ambiguous column: C

-- # With GROUP BY or an aggregate function, it can be a grouping column, an
-- # expression of one, or an aggregate function.
SELECT a AS c FROM g GROUP BY a ORDER BY c DESC;
SELECT a + 1 AS c FROM g GROUP BY a ORDER BY c DESC;
SELECT b AS a FROM g GROUP BY b ORDER BY a DESC FETCH FIRST 1 ROW ONLY;
SELECT a, COUNT(*) AS n FROM g GROUP BY a ORDER BY n DESC;
SELECT a, SUM(b) AS n FROM g GROUP BY a ORDER BY n;
SELECT a, SUM(b) + 1 AS n FROM g GROUP BY a ORDER BY n * 2;
SELECT a, COUNT(*) AS a FROM g GROUP BY a ORDER BY a;
SELECT a, SUM(b) AS b FROM g GROUP BY a ORDER BY b;
SELECT COUNT(*) AS n FROM g ORDER BY n;
SELECT a, COUNT(*) AS n FROM g GROUP BY a HAVING COUNT(*) > 1 ORDER BY n;
-- C: 3
-- C: 2
-- C: 1
-- C: 4
-- C: 3
-- C: 2
-- A: 6
-- A: 3 N: 3
-- A: 1 N: 2
-- A: 2 N: 1
-- A: 2 N: 1
-- A: 3 N: 9
-- A: 1 N: 11
-- A: 2 N: 2
-- A: 3 N: 10
-- A: 1 N: 12
-- error 42702: ambiguous column: A
-- A: 2 B: 1
-- A: 3 B: 9
-- A: 1 B: 11
-- N: 6
-- A: 1 N: 2
-- A: 3 N: 3

-- # The argument of an aggregate function isn't a column of the result.
/* extensions V202-03 */
SELECT a AS b, SUM(b) AS s FROM g GROUP BY a ORDER BY SUM(b);
-- B: 2 S: 1
-- B: 3 S: 9
-- B: 1 S: 11

-- # A subquery in a sort key can't use an alias (it isn't standard SQL anyway),
-- # so the name is the column of the table.
/* extensions V202-02 V202-03 */
SELECT y AS a FROM t ORDER BY (SELECT MAX(w) FROM u WHERE u.x = a);
SELECT -y AS w FROM t ORDER BY (SELECT w FROM u WHERE u.x = t.x);
SELECT z AS y FROM t ORDER BY (SELECT y FROM (VALUES 1) AS v);
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.A
-- W: -10
-- W: -20
-- W: -30
-- Y: 300
-- Y: 100
-- Y: 200

-- # A query with UNION or EXCEPT can only use the columns of the result, by the
-- # name of the left query, in any expression. A name is still ambiguous.
SELECT x AS a FROM t UNION SELECT y FROM t ORDER BY a DESC FETCH FIRST 2 ROWS ONLY;
SELECT x AS a FROM t UNION SELECT y FROM t ORDER BY a * -1 FETCH FIRST 2 ROWS ONLY;
SELECT y AS x FROM t EXCEPT SELECT x FROM t ORDER BY x;
SELECT x AS a FROM t UNION SELECT y FROM t ORDER BY y;
SELECT x AS a FROM t UNION SELECT y FROM t ORDER BY t.x;
SELECT x AS a, y AS a FROM t UNION SELECT y, z FROM t ORDER BY a;
SELECT x AS a, y AS a FROM t UNION SELECT y, z FROM t ORDER BY a + 1;
(SELECT x AS a FROM t) ORDER BY a DESC;
(SELECT x AS a FROM t ORDER BY a DESC FETCH FIRST 1 ROW ONLY) UNION ALL (SELECT y FROM t ORDER BY y FETCH FIRST 1 ROW ONLY) ORDER BY a;
-- A: 30
-- A: 20
-- A: 30
-- A: 20
-- X: 10
-- X: 20
-- X: 30
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.Y
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.T.X
-- error 42702: ambiguous column: A
-- error 42702: ambiguous column: A
-- A: 3
-- A: 2
-- A: 1
-- A: 3
-- A: 10

-- # A derived table or an ORDER BY in a subquery has its own columns.
SELECT b FROM (SELECT -x AS b FROM t ORDER BY b) AS d ORDER BY b DESC;
SELECT MAX(a) AS m FROM (SELECT -x AS a FROM t ORDER BY a FETCH FIRST 2 ROWS ONLY) AS d;
SELECT x FROM t WHERE x = (SELECT -w AS x FROM u ORDER BY x FETCH FIRST 1 ROW ONLY) + 4;
-- B: -1
-- B: -2
-- B: -3
-- M: -2
-- X: 1

-- # A sort key can't contain a NEXT VALUE FOR, but it can be the name of a
-- # column of the result that does. Each row uses one value, whatever the sort
-- # compares.
/* extensions V202-01 */
SELECT x FROM t ORDER BY NEXT VALUE FOR seq;
SELECT NEXT VALUE FOR seq AS n FROM t ORDER BY x FETCH FIRST 1 ROW ONLY;
SELECT NEXT VALUE FOR seq AS n FROM t ORDER BY n DESC;
SELECT NEXT VALUE FOR seq AS n, NEXT VALUE FOR seq + 1 AS m FROM t ORDER BY n * -1;
SELECT NEXT VALUE FOR seq + 1 AS n, x FROM t ORDER BY n FETCH FIRST 1 ROW ONLY;
SELECT NEXT VALUE FOR seq AS n FROM t ORDER BY x FETCH FIRST 1 ROW ONLY;
SELECT DISTINCT NEXT VALUE FOR seq AS n FROM t ORDER BY n;
SELECT NEXT VALUE FOR seq AS n FROM t GROUP BY x ORDER BY n;
-- error 42601: syntax error: NEXT VALUE FOR cannot be used in ORDER BY
-- N: 1
-- N: 4
-- N: 3
-- N: 2
-- N: 7 M: 8
-- N: 6 M: 7
-- N: 5 M: 6
-- N: 9 X: 1
-- N: 11
-- error 42601: syntax error: NEXT VALUE FOR cannot be used in SELECT DISTINCT
-- error 42601: syntax error: NEXT VALUE FOR cannot be used in a grouped query

-- # EXPLAIN shows the sort by the alias, after any NEXT VALUE FOR is evaluated.
/* extensions V001-01 */
EXPLAIN SELECT NEXT VALUE FOR seq AS n FROM t ORDER BY n;
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (X INTEGER, Y INTEGER, Z INTEGER)
-- EXPLAIN: SEQUENCE VALUES (NEXT VALUE FOR SEQ)
-- EXPLAIN: ORDER BY N ASC
-- EXPLAIN: EXPR (N BIGINT)

/* extensions V001-01 */
EXPLAIN SELECT y + 1 AS a FROM t ORDER BY a;
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (X INTEGER, Y INTEGER, Z INTEGER)
-- EXPLAIN: ORDER BY A ASC
-- EXPLAIN: EXPR (A INTEGER)

-- # The same rule applies to a cursor. Its rows are found when it's opened.
/* extensions V108-01 V109-01 V110-01 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT y + 1 AS a FROM t ORDER BY a;
OPEN c;
FETCH NEXT FROM c;
FETCH NEXT FROM c;
FETCH NEXT FROM c;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- A: 11
-- A: 21
-- A: 31

/* extensions V108-01 V109-01 V110-01 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT -x AS x FROM t ORDER BY x;
OPEN c;
FETCH NEXT FROM c;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: -3

/* extensions V108-01 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT x AS a, y AS a FROM t ORDER BY a;
-- msg: START TRANSACTION
-- error 42702: ambiguous column: A
