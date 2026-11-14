-- # Rows of the same degree are compared field by field (ISO/IEC 9075-2:2016(E),
-- # 8.2, <comparison predicate>, General Rules, 1.b.i).
/* setup */
CREATE TABLE t (x INT PRIMARY KEY, y INT);
INSERT INTO t (x, y) VALUES (1, 1), (1 + 1, 2), (3, NULL);
CREATE TABLE pairs (a INT, b INT);
INSERT INTO pairs (a, b) VALUES (1, 1), (2, NULL);

-- # 1) X = Y is TRUE when every field is equal, 3) FALSE when any field isn't.
VALUES ROW((1, 2) = (1, 2), (1, 2) = (1, 3), ROW(1, 2) = ROW(2, 2));
-- COL1: TRUE COL2: FALSE COL3: FALSE

VALUES ROW((1, 2) <> (1, 2), (1, 2) <> (1, 3), (1, 2) <> (2, 2));
-- COL1: FALSE COL2: TRUE COL3: TRUE

-- # 2) X < Y is TRUE when the first field that isn't equal is less.
VALUES ROW((1, 2) < (1, 3), (1, 2) < (2, 0), (1, 2) < (1, 2), (2, 0) < (1, 5));
-- COL1: TRUE COL2: TRUE COL3: FALSE COL4: FALSE

VALUES ROW((1, 3) > (1, 2), (2, 0) > (1, 5), (1, 2) > (1, 2), (1, 5) > (2, 0));
-- COL1: TRUE COL2: TRUE COL3: FALSE COL4: FALSE

VALUES ROW((1, 2) <= (1, 2), (1, 2) <= (1, 3), (1, 3) <= (1, 2));
-- COL1: TRUE COL2: TRUE COL3: FALSE

VALUES ROW((1, 2) >= (1, 2), (1, 3) >= (1, 2), (1, 2) >= (1, 3));
-- COL1: TRUE COL2: TRUE COL3: FALSE

VALUES ROW(('a', 'b', 3) < ('a', 'c', 1), (TRUE, 1.5) > (TRUE, 1.25));
-- COL1: TRUE COL2: TRUE

-- # A NULL field makes a comparison UNKNOWN only when the other fields don't
-- # decide it.
VALUES ROW((1, CAST(NULL AS INT)) = (1, 2), (1, CAST(NULL AS INT)) = (2, 2));
-- COL1: UNKNOWN COL2: FALSE

VALUES ROW((1, CAST(NULL AS INT)) <> (1, 2), (1, CAST(NULL AS INT)) <> (2, 2));
-- COL1: UNKNOWN COL2: TRUE

VALUES ROW((1, CAST(NULL AS INT)) < (2, 0), (1, CAST(NULL AS INT)) < (1, 5), (2, CAST(NULL AS INT)) < (1, 5));
-- COL1: TRUE COL2: UNKNOWN COL3: FALSE

VALUES ROW((1, CAST(NULL AS INT)) > (0, 0), (1, CAST(NULL AS INT)) > (1, 5), (0, CAST(NULL AS INT)) > (1, 5));
-- COL1: TRUE COL2: UNKNOWN COL3: FALSE

VALUES ROW((CAST(NULL AS INT), 1) <= (1, 1), (1, CAST(NULL AS INT)) <= (2, 1), (1, CAST(NULL AS INT)) >= (1, 1));
-- COL1: UNKNOWN COL2: TRUE COL3: UNKNOWN

-- # X = Y can be FALSE while X < Y is UNKNOWN, because a later field is
-- # different but an earlier one is NULL.
VALUES ROW((1, CAST(NULL AS INT), 3) = (1, 5, 4), (1, CAST(NULL AS INT), 3) < (1, 5, 4), (1, CAST(NULL AS INT), 3) <= (1, 5, 4));
-- COL1: FALSE COL2: UNKNOWN COL3: UNKNOWN

-- # A row of one field is the same as a value.
VALUES ROW(ROW(1) = 1, 2 > ROW(1), ROW(CAST(NULL AS INT)) = ROW(1));
-- COL1: TRUE COL2: TRUE COL3: UNKNOWN

-- # The fields can be any expression, including columns.
SELECT x, y FROM t WHERE (x, y) = (1 + 1, 2);
-- X: 2 Y: 2

SELECT x, y FROM t WHERE (x, y) > (1, 1);
-- X: 2 Y: 2
-- X: 3 Y: NULL

SELECT x, y FROM t WHERE (y, x) >= (1, 2);
-- X: 2 Y: 2

SELECT x FROM t WHERE x = ROW(3);
-- X: 3

SELECT x, (x, y) < (2, 5) AS lt FROM t;
-- X: 1 LT: TRUE
-- X: 2 LT: TRUE
-- X: 3 LT: FALSE

SELECT a, b FROM pairs JOIN t ON (a, b) = (x, y);
-- A: 1 B: 1

SELECT (COUNT(*), MAX(x)) = (3, 3) AS c FROM t;
-- C: TRUE

/* extensions V001-01 */
EXPLAIN SELECT * FROM t WHERE (x, y) <= ROW(2, 2);
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (X INTEGER NOT NULL, Y INTEGER)
-- EXPLAIN: WHERE ROW(X, Y) <= ROW(2, 2)
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.X INTEGER NOT NULL, ":memory:".PUBLIC.T.Y INTEGER)

-- # BETWEEN, IN and the quantified comparisons are defined with comparisons.
VALUES ROW((1, 2) BETWEEN (1, 1) AND (1, 3), (1, 2) BETWEEN (1, 3) AND (2, 0), (1, 2) NOT BETWEEN (0, 9) AND (1, 1));
-- COL1: TRUE COL2: FALSE COL3: TRUE

VALUES ROW((1, 2) BETWEEN SYMMETRIC (2, 0) AND (1, 1), (1, CAST(NULL AS INT)) BETWEEN (0, 1) AND (2, 1), (1, CAST(NULL AS INT)) BETWEEN (1, 1) AND (2, 1));
-- COL1: TRUE COL2: TRUE COL3: UNKNOWN

SELECT x FROM t WHERE (x, y) BETWEEN (1, 5) AND (3, 0);
-- X: 2

VALUES ROW((1, 2) IN ((3, 4), (1, 2)), (1, 2) IN ((3, 4)), (1, 2) NOT IN ((3, 4), (5, 6)));
-- COL1: TRUE COL2: FALSE COL3: TRUE

VALUES ROW((1, 2) IN ((1, CAST(NULL AS INT)), (3, 4)), (1, 2) IN ((2, CAST(NULL AS INT)), (3, 4)));
-- COL1: UNKNOWN COL2: FALSE

SELECT x, y FROM t WHERE (x, y) IN (SELECT a, b FROM pairs);
-- X: 1 Y: 1

SELECT x, y FROM t WHERE (x, y) NOT IN (SELECT a, b FROM pairs);
-- X: 3 Y: NULL

VALUES ROW((2, 2) = ANY (SELECT x, y FROM t), (3, 5) = SOME (SELECT x, y FROM t), (0, 0) < ALL (SELECT x, y FROM t));
-- COL1: TRUE COL2: UNKNOWN COL3: TRUE

VALUES ROW((3, 0) > ALL (SELECT a, b FROM pairs), (2, 0) > ALL (SELECT a, b FROM pairs), (1, 0) >= ALL (SELECT x, y FROM t WHERE x > 5));
-- COL1: TRUE COL2: UNKNOWN COL3: TRUE

SELECT (COUNT(*), MAX(x)) IN ((3, 3)) AS i, (COUNT(*), 1) BETWEEN (1, 1) AND (MAX(x), 1) AS b, (COUNT(*), 3) = ANY (SELECT x, x FROM t) AS q FROM t;
-- I: TRUE B: TRUE Q: TRUE

-- # A row with more than one value needs F641, and ROW needs T051.
/* flags */
SELECT x FROM t WHERE (x, y) = (1, 1) AND ROW(x) = 1;
-- flags: F641, T051
-- X: 1

-- # The rows must have the same degree (Syntax Rules, 1).
VALUES (1, 2) = (1, 2, 3);
-- error 42601: syntax error: cannot compare a row of degree 2 with a row of degree 3

VALUES (1, 2) < 1;
-- error 42601: syntax error: cannot compare a row of degree 2 with a row of degree 1

VALUES (1, 2) BETWEEN (1, 2) AND 3;
-- error 42601: syntax error: cannot compare a row of degree 2 with a row of degree 1

VALUES 1 IN (1, (1, 2));
-- error 42601: syntax error: cannot compare a row of degree 1 with a row of degree 2

VALUES (1, 2) IN (SELECT x FROM t);
-- error 42601: syntax error: subquery must return 2 columns

VALUES (1, 2) = ANY (SELECT x, y, x FROM t);
-- error 42601: syntax error: subquery must return 2 columns

VALUES 1 = ANY (SELECT x, y FROM t);
-- error 42601: syntax error: subquery must return only one column

-- # The corresponding fields must be comparable.
VALUES (1, 'a') = (1, 2);
-- error 42883: cannot compare CHARACTER(1) and SMALLINT

-- # NULL isn't a value in a row.
VALUES (1, NULL) = (1, 2);
-- error 42601: syntax error: unexpected NULL

-- # Only the predicates that compare can have a row.
VALUES (1, 2) LIKE 'a';
-- error 42601: syntax error: a row value cannot be used here
