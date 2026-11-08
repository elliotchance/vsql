/* setup */
CREATE TABLE t (x INT, y VARCHAR(10));
INSERT INTO t (x, y) VALUES (1, 'a'), (2, 'b');

-- # A row in parentheses is the same as ROW.
VALUES (1, 2);
-- COL1: 1 COL2: 2

VALUES (1, 'a', TRUE, 1.5);
-- COL1: 1 COL2: a COL3: TRUE COL4: 1.5

/* extensions V001-01 */
EXPLAIN VALUES (1, 'a');
-- EXPLAIN: VALUES (COL1 SMALLINT, COL2 CHARACTER(1)) = ROW(1, 'a')

-- # One value in parentheses is an expression, so it's one column.
VALUES (1);
-- COL1: 1

VALUES ((1));
-- COL1: 1

VALUES (1 + 2), (3);
-- COL1: 3
-- COL1: 3

VALUES ((1), (2));
-- COL1: 1 COL2: 2

-- # Each value is any expression.
VALUES (1 + 2, UPPER('a'), (3 + 4) * 2, 1 > 0, NOT TRUE, CAST(NULL AS INT));
-- COL1: 3 COL2: A COL3: 14 COL4: TRUE COL5: FALSE COL6: NULL

VALUES ((1 + 2) * 3, 4);
-- COL1: 9 COL2: 4

VALUES ((SELECT x FROM t WHERE x = 2), 3);
-- COL1: 2 COL2: 3

-- # There are many rows, and they can be in either form.
VALUES (1, 'a'), (2, 'b'), (3, 'c');
-- COL1: 1 COL2: a
-- COL1: 2 COL2: b
-- COL1: 3 COL2: c

VALUES (1, 'a'), ROW(2, 'b');
-- COL1: 1 COL2: a
-- COL1: 2 COL2: b

VALUES ROW(1, 'a'), (2, 'b'), ROW(3, 'c');
-- COL1: 1 COL2: a
-- COL1: 2 COL2: b
-- COL1: 3 COL2: c

VALUES ROW(1), (2), 3;
-- COL1: 1
-- COL1: 2
-- COL1: 3

-- # Every row has the same number of columns.
VALUES (1, 2), (3);
-- error 42601: syntax error: VALUES rows must have the same number of columns

VALUES (1), (2, 3);
-- error 42601: syntax error: VALUES rows must have the same number of columns

VALUES (1, 2), 3;
-- error 42601: syntax error: VALUES rows must have the same number of columns

VALUES (1, 2), (3, 4, 5);
-- error 42601: syntax error: VALUES rows must have the same number of columns

VALUES (1, 2), ROW(3, 4, 5);
-- error 42601: syntax error: VALUES rows must have the same number of columns

-- # Each column has the combined type.
VALUES (1, 'a'), (200000, 'bcd');
-- COL1: 1 COL2: a
-- COL1: 200000 COL2: bcd

VALUES (1, 'a'), ('b', 2);
-- error 42804: data type mismatch in row 2, column 1 of VALUES: expected SMALLINT but got CHARACTER(1)

-- # NULL and DEFAULT get their type from a column, so they can't be in a query.
VALUES (1, NULL);
-- error 42601: syntax error: unexpected NULL

VALUES (NULL, 1);
-- error 42601: syntax error: unexpected NULL

VALUES (1, DEFAULT);
-- error 42601: syntax error: unexpected DEFAULT

VALUES (2, 3), (1, NULL);
-- error 42601: syntax error: unexpected NULL

-- # A row isn't a value, because there are no row types.
VALUES ((1, 2));
-- error 42601: syntax error: unexpected ")", expecting IS

VALUES ((1, 2), 3);
-- error 42601: syntax error: unexpected ",", expecting IS

VALUES (1, (2, 3));
-- error 42601: syntax error: unexpected ")", expecting IS

VALUES (ROW(1, 2), 3);
-- error 42601: syntax error: unexpected ",", expecting IS

-- # A row is still the start of a null predicate.
VALUES (1, 2) IS NULL;
-- COL1: FALSE

VALUES (1, 2) IS NOT NULL, (1, 2) IS NULL;
-- COL1: TRUE
-- COL1: FALSE

VALUES ((1, 2) IS NULL, 3);
-- COL1: FALSE COL2: 3

VALUES (1, NULL) IS NULL;
-- error 42601: syntax error: unexpected NULL

VALUES (1, 2) = (1, 2);
-- error 42601: syntax error: unexpected "="

-- # Other syntax errors.
VALUES ();
-- error 42601: syntax error: unexpected ")"

VALUES (1,);
-- error 42601: syntax error: unexpected ")"

VALUES (1, 2;
-- error 42601: syntax error: unexpected $end, expecting ")" or ","

VALUES (1 2);
-- error 42601: syntax error: unexpected number, expecting ","

-- # As a derived table.
/* extensions V201-02 */
SELECT * FROM (VALUES (1, 2));
-- COL1: 1 COL2: 2

SELECT * FROM (VALUES (1, 'a'), (2, 'b')) AS v (a, b);
-- A: 1 B: a
-- A: 2 B: b

SELECT b FROM (VALUES (1, 'a'), ROW(2, 'b')) AS v (a, b) WHERE a = 2;
-- B: b

SELECT * FROM (VALUES (1)) AS v (a);
-- A: 1

SELECT * FROM (VALUES (1, 2)) AS v (a);
-- error 42601: syntax error: ROW provides the wrong number of columns for the correlation

/* extensions V201-02 */
SELECT * FROM ((VALUES (1, 2)));
-- COL1: 1 COL2: 2

/* extensions V001-01 */
EXPLAIN SELECT * FROM (VALUES (123, 'hi'), ROW(456, 'there')) AS foo (bar, baz);
-- EXPLAIN: FOO:
-- EXPLAIN:   VALUES (BAR SMALLINT, BAZ CHARACTER(5)) = ROW(123, 'hi'), ROW(456, 'there')
-- EXPLAIN: TABLE FOO (BAR SMALLINT, BAZ CHARACTER(5))
-- EXPLAIN: EXPR (FOO.BAR SMALLINT, FOO.BAZ CHARACTER(5))

SELECT t.x, v.b FROM t INNER JOIN (VALUES (1, 'one'), (2, 'two')) AS v (a, b) ON t.x = v.a;
-- X: 1 B: one
-- X: 2 B: two

-- # In parentheses, with clauses and with a set operation.
(VALUES (1, 2));
-- COL1: 1 COL2: 2

((VALUES (1, 2)));
-- COL1: 1 COL2: 2

VALUES (2, 'b'), (1, 'a') ORDER BY COL1;
-- COL1: 1 COL2: a
-- COL1: 2 COL2: b

VALUES (1, 'a'), (2, 'b'), (3, 'c') OFFSET 1 ROW FETCH FIRST 1 ROW ONLY;
-- COL1: 2 COL2: b

VALUES (1, 'a') UNION VALUES (2, 'b');
-- COL1: 1 COL2: a
-- COL1: 2 COL2: b

VALUES (1, 'a') UNION ALL VALUES (1, 'a'), ROW(2, 'b');
-- COL1: 1 COL2: a
-- COL1: 1 COL2: a
-- COL1: 2 COL2: b

VALUES (1, 'a'), (2, 'b') EXCEPT VALUES (2, 'b');
-- COL1: 1 COL2: a

(VALUES (1, 'a')) UNION (VALUES (2, 'b'));
-- COL1: 1 COL2: a
-- COL1: 2 COL2: b

SELECT x, y FROM t UNION VALUES (3, 'c');
-- X: 1 Y: a
-- X: 2 Y: b
-- X: 3 Y: c

VALUES (1, 2) UNION VALUES (3);
-- error 42601: syntax error: each UNION query must have the same number of columns

-- # In a subquery.
SELECT x FROM t WHERE x IN (VALUES (1), (3));
-- X: 1

SELECT x FROM t WHERE x IN (VALUES (1, 2));
-- error 42601: syntax error: subquery must return only one column

SELECT x FROM t WHERE EXISTS (VALUES (1, 2));
-- X: 1
-- X: 2

SELECT (VALUES (5)) AS v FROM t WHERE x = 1;
-- V: 5

SELECT (VALUES (5, 6)) AS v FROM t WHERE x = 1;
-- error 42601: syntax error: subquery must return only one column

SELECT x, (SELECT b FROM (VALUES (t.x, 'c')) AS v (a, b)) AS b FROM t;
-- X: 1 B: c
-- X: 2 B: c

-- # INSERT has its own form of a row, which can have NULL and DEFAULT.
CREATE TABLE u (a INT, b INT DEFAULT 7);
INSERT INTO u (a, b) VALUES (1, 2), (3, NULL), (4, DEFAULT);
SELECT * FROM u;
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- A: 1 B: 2
-- A: 3 B: NULL
-- A: 4 B: 7
