/* setup */
CREATE TABLE t (a INT, b INT);
INSERT INTO t (a, b) VALUES (1, 1), (1, 2), (2, NULL), (3, 3), (3, 3);

-- # SIMPLE (the default) is TRUE when a row of the subquery is equal to the
-- # row (General Rules, 2.b.ii.1), or when the row has a NULL (2.a and 2.b.i).
VALUES (1, 2) MATCH (SELECT a, b FROM t);
VALUES (1, 3) MATCH SIMPLE (SELECT a, b FROM t);
VALUES (2, CAST(NULL AS INT)) MATCH (SELECT a, b FROM t);
VALUES (9, CAST(NULL AS INT)) MATCH SIMPLE (SELECT a, b FROM t);
VALUES 1 MATCH (SELECT a FROM t);
VALUES 4 MATCH (SELECT a FROM t);
VALUES CAST(NULL AS INT) MATCH (SELECT a FROM t);
-- COL1: TRUE
-- COL1: FALSE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: FALSE
-- COL1: TRUE

-- # UNIQUE needs exactly one equal row (General Rules, 2.b.ii.2), so a
-- # duplicate row doesn't match.
VALUES (1, 1) MATCH UNIQUE (SELECT a, b FROM t);
VALUES (3, 3) MATCH UNIQUE (SELECT a, b FROM t);
VALUES 1 MATCH UNIQUE SIMPLE (SELECT a FROM t);
VALUES (3, CAST(NULL AS INT)) MATCH UNIQUE (SELECT a, b FROM t);
-- COL1: TRUE
-- COL1: FALSE
-- COL1: FALSE
-- COL1: TRUE

-- # PARTIAL is TRUE when every field is NULL, or when a row of the subquery is
-- # equal on every field that isn't NULL (General Rules, 3).
VALUES (1, CAST(NULL AS INT)) MATCH PARTIAL (SELECT a, b FROM t);
VALUES (CAST(NULL AS INT), 3) MATCH PARTIAL (SELECT a, b FROM t);
VALUES (CAST(NULL AS INT), 4) MATCH PARTIAL (SELECT a, b FROM t);
VALUES (CAST(NULL AS INT), CAST(NULL AS INT)) MATCH PARTIAL (SELECT a, b FROM t);
VALUES (2, CAST(NULL AS INT)) MATCH PARTIAL (SELECT a, b FROM t);
VALUES (1, 1) MATCH PARTIAL (SELECT a, b FROM t);
VALUES (1, CAST(NULL AS INT)) MATCH UNIQUE PARTIAL (SELECT a, b FROM t);
VALUES (2, CAST(NULL AS INT)) MATCH UNIQUE PARTIAL (SELECT a, b FROM t);
-- COL1: TRUE
-- COL1: TRUE
-- COL1: FALSE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: FALSE
-- COL1: TRUE

-- # FULL is TRUE when every field is NULL, and FALSE when only some of them
-- # are. Otherwise, it's like SIMPLE (General Rules, 4).
VALUES (CAST(NULL AS INT), CAST(NULL AS INT)) MATCH FULL (SELECT a, b FROM t);
VALUES (2, CAST(NULL AS INT)) MATCH FULL (SELECT a, b FROM t);
VALUES (1, 2) MATCH FULL (SELECT a, b FROM t);
VALUES (1, 3) MATCH FULL (SELECT a, b FROM t);
VALUES (3, 3) MATCH UNIQUE FULL (SELECT a, b FROM t);
VALUES (1, 2) MATCH UNIQUE FULL (SELECT a, b FROM t);
-- COL1: TRUE
-- COL1: FALSE
-- COL1: TRUE
-- COL1: FALSE
-- COL1: FALSE
-- COL1: TRUE

-- # It's never UNKNOWN, so NOT is the opposite. The row can use the columns of
-- # the outer query, and the subquery can be empty.
SELECT a, b FROM t WHERE NOT (a, b) MATCH FULL (SELECT a, b FROM t WHERE a = 3);
VALUES 1 MATCH (SELECT a FROM t WHERE a > 5);
-- A: 1 B: 1
-- A: 1 B: 2
-- A: 2 B: NULL
-- COL1: FALSE

-- # The row and the rows of the subquery must have the same degree, and values
-- # that can be compared (Syntax Rules, 1 and 2).
VALUES (1, 2) MATCH (SELECT a FROM t);
VALUES 'x' MATCH (SELECT a FROM t);
-- error 42601: syntax error: subquery must return 2 columns
-- error 42883: cannot compare CHARACTER(1) and INTEGER

-- # A match predicate can be the operand of a simple CASE, and is shown in
-- # EXPLAIN.
SELECT a, CASE b WHEN MATCH PARTIAL (SELECT b FROM t WHERE a = 1) THEN 'yes' ELSE 'no' END FROM t;
/* extensions V001-01 */
EXPLAIN SELECT * FROM t WHERE (a, b) MATCH UNIQUE FULL (SELECT a, b FROM t);
-- A: 1 COL2: yes
-- A: 1 COL2: yes
-- A: 2 COL2: yes
-- A: 3 COL2: no
-- A: 3 COL2: no
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (A INTEGER, B INTEGER)
-- EXPLAIN: WHERE ROW(A, B) MATCH UNIQUE FULL (SELECT A, B FROM T)
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.A INTEGER, ":memory:".PUBLIC.T.B INTEGER)

-- # The match predicate needs F741.
/* flags */
VALUES 1 MATCH (SELECT a FROM t);
SELECT CASE a WHEN MATCH FULL (SELECT a FROM t) THEN 1 END FROM t WHERE a = 2;
-- flags: F641, F661, F741
-- COL1: TRUE
-- flags: F262, F741
-- COL1: 1
