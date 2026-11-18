-- # A <row subquery> (F641) is a subquery of more than one column where a row
-- # can be, which is a row of its columns (Syntax Rules, 3 and 6). A subquery
-- # of one column is a <scalar subquery> (std_2_7_19_scalar_subquery.sql).
/* setup */
CREATE TABLE t (a INT, b INT);
INSERT INTO t (a, b) VALUES (1, 2), (3, 4), (5, NULL);
CREATE TABLE u (id INT, x INT, y INT);
INSERT INTO u (id, x, y) VALUES (1, 1, 2), (2, 3, 4);

-- # In a comparison, on either side.
SELECT * FROM t WHERE (a, b) = (SELECT x, y FROM u WHERE id = 1);
SELECT * FROM t WHERE (SELECT x, y FROM u WHERE id = 2) = (a, b);
SELECT * FROM t WHERE (a, b) < (SELECT x, y FROM u WHERE id = 2);
SELECT * FROM t WHERE ROW(a, b) <> (SELECT x, y FROM u WHERE id = 1);
-- A: 1 B: 2
-- A: 3 B: 4
-- A: 1 B: 2
-- A: 3 B: 4
-- A: 5 B: NULL

VALUES (SELECT x, y FROM u WHERE id = 1) = (SELECT x, y FROM u WHERE id = 1);
VALUES (SELECT x, y FROM u WHERE id = 1) >= (SELECT x, y FROM u WHERE id = 2);
-- COL1: TRUE
-- COL1: FALSE

-- # It's correlated when it refers to the row of the containing query.
SELECT a, (a, b) < (SELECT x, y FROM u WHERE x > t.a) FROM t;
-- A: 1 COL2: TRUE
-- A: 3 COL2: UNKNOWN
-- A: 5 COL2: UNKNOWN

-- # With no rows it's a row of NULLs, and more than one row is an error
-- # (General Rules, 2).
SELECT a, (a, b) = (SELECT x, y FROM u WHERE id = 9) FROM t;
VALUES ROW((SELECT x, y FROM u WHERE id = 9) IS NULL, (SELECT x, y FROM u WHERE id = 1) IS NOT NULL);
-- A: 1 COL2: UNKNOWN
-- A: 3 COL2: UNKNOWN
-- A: 5 COL2: UNKNOWN
-- COL1: TRUE COL2: TRUE

SELECT * FROM t WHERE (a, b) = (SELECT x, y FROM u);
-- error 21000: cardinality violation: more than one row returned by a subquery used as an expression

-- # The other predicates that compare rows.
SELECT a, (a, b) BETWEEN (SELECT x, y FROM u WHERE id = 1) AND (3, 0) FROM t;
-- A: 1 COL2: TRUE
-- A: 3 COL2: FALSE
-- A: 5 COL2: FALSE

SELECT a, (a, b) IN ((SELECT x, y FROM u WHERE id = 2), (0, 0)) FROM t;
SELECT a, (a, b) IS DISTINCT FROM (SELECT x, y FROM u WHERE id = 1) FROM t;
-- A: 1 COL2: FALSE
-- A: 3 COL2: TRUE
-- A: 5 COL2: FALSE
-- A: 1 COL2: FALSE
-- A: 3 COL2: TRUE
-- A: 5 COL2: TRUE

VALUES (SELECT x, y FROM u WHERE id = 2) IN (SELECT a, b FROM t);
VALUES (SELECT x, y FROM u WHERE id = 2) = ANY (SELECT a, b FROM t);
VALUES (SELECT x, y FROM u WHERE id = 2) > ALL (SELECT x, y FROM u WHERE id = 1);
-- COL1: TRUE
-- COL1: TRUE
-- COL1: TRUE

-- # The case operand of a simple CASE, or a value to compare it with.
SELECT a, CASE (a, b) WHEN (1, 2) THEN 'one' WHEN (SELECT x, y FROM u WHERE id = 2) THEN 'two' ELSE 'no' END FROM t;
VALUES CASE (SELECT x, y FROM u WHERE id = 2) WHEN (1, 2) THEN 'one' WHEN (3, 4) THEN 'two' END;
-- A: 1 COL2: one
-- A: 3 COL2: two
-- A: 5 COL2: no
-- COL1: two

-- # A row of a VALUES.
VALUES (SELECT x, y FROM u WHERE id = 2), (5, 6);
-- COL1: 3 COL2: 4
-- COL1: 5 COL2: 6

SELECT * FROM (VALUES (SELECT x, y FROM u WHERE id = 1)) AS v (c, d);
-- C: 1 D: 2

-- # It must have the same degree as the row it's compared with.
VALUES (1, 2, 3) = (SELECT x, y FROM u WHERE id = 1);
VALUES (1, 2) = (SELECT id, x, y FROM u WHERE id = 1);
VALUES (SELECT x, y FROM u WHERE id = 1), (1);
-- error 42601: syntax error: cannot compare a row of degree 3 with a row of degree 2
-- error 42601: syntax error: cannot compare a row of degree 2 with a row of degree 3
-- error 42601: syntax error: VALUES rows must have the same number of columns

-- # It's only a row where a row can be, so it's not a value.
VALUES (SELECT x, y FROM u WHERE id = 1) + 1;
VALUES ROW((SELECT x, y FROM u WHERE id = 1), 2);
-- error 42601: syntax error: subquery must return only one column
-- error 42601: syntax error: subquery must return only one column

-- # A row subquery needs F641 (7.1, Conformance Rules, 4). As a case operand
-- # it's a row, which needs F262 (6.12, Conformance Rules, 1 and 2).
/* flags */
SELECT a FROM t WHERE (a, b) = (SELECT x, y FROM u WHERE id = 1);
-- flags: F641
-- A: 1

/* flags */
SELECT a FROM t WHERE a = (SELECT x FROM u WHERE id = 1);
-- flags:
-- A: 1

/* flags */
SELECT CASE (SELECT x, y FROM u WHERE id = 1) WHEN (SELECT x, y FROM u WHERE id = 1) THEN 'yes' END FROM u;
-- flags: F262, F641
-- COL1: yes
-- COL1: yes
