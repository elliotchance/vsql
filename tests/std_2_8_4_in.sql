-- # IN is = ANY over the list (SR 5), and NOT IN is NOT (... IN ...) (SR 4).
VALUES 3 IN (1, 2, 3);
-- COL1: TRUE

VALUES 4 IN (1, 2, 3);
-- COL1: FALSE

VALUES 3 NOT IN (1, 2, 3);
-- COL1: FALSE

VALUES 4 NOT IN (1, 2, 3);
-- COL1: TRUE

-- # A list of one value.
VALUES 1 IN (1);
-- COL1: TRUE

VALUES 2 IN (1);
-- COL1: FALSE

VALUES 1 NOT IN (1);
-- COL1: FALSE

VALUES 2 NOT IN (1);
-- COL1: TRUE

-- # The value and the list can be expressions.
VALUES 3 IN (1 + 2);
-- COL1: TRUE

VALUES 1 + 2 IN (2, 5 - 2);
-- COL1: TRUE

-- # Values are compared like =, so numbers of different types can be equal and
-- # trailing spaces don't matter.
VALUES 2.5 IN (1, 2.5);
-- COL1: TRUE

VALUES 2 IN (1.5, 2.0);
-- COL1: TRUE

VALUES 'b' IN ('a', 'b');
-- COL1: TRUE

VALUES 'b ' IN ('a', 'b');
-- COL1: TRUE

VALUES 'c' IN ('a', 'b');
-- COL1: FALSE

VALUES TRUE IN (FALSE);
-- COL1: FALSE

VALUES DATE '2022-06-30' IN (DATE '2022-06-29', DATE '2022-06-30');
-- COL1: TRUE

-- # A NULL in the list makes the result UNKNOWN unless another value is equal,
-- # wherever it is in the list. A NULL value is always UNKNOWN.
VALUES 1 IN (2, CAST(NULL AS INTEGER));
-- COL1: UNKNOWN

VALUES 1 IN (1, CAST(NULL AS INTEGER));
-- COL1: TRUE

VALUES 1 IN (CAST(NULL AS INTEGER), 1);
-- COL1: TRUE

VALUES 1 NOT IN (2, CAST(NULL AS INTEGER));
-- COL1: UNKNOWN

VALUES 1 NOT IN (1, CAST(NULL AS INTEGER));
-- COL1: FALSE

VALUES CAST(NULL AS INTEGER) IN (1, 2);
-- COL1: UNKNOWN

VALUES CAST(NULL AS INTEGER) NOT IN (1, 2);
-- COL1: UNKNOWN

-- # The values must be comparable. They're only checked when they're compared
-- # (see 8.2, Syntax Rules, 3 in the standard index), so a NULL value isn't an
-- # error.
VALUES 1 IN ('a');
-- error 42883: cannot compare SMALLINT and CHARACTER(1)

VALUES 1 IN (1, 'a');
-- error 42883: cannot compare SMALLINT and CHARACTER(1)

VALUES CAST(NULL AS INTEGER) IN (1, 'a');
-- error 42883: cannot compare INTEGER and CHARACTER(1)

-- # The result is a boolean that can be used like any other.
VALUES (3 IN (1, 2, 3)) = TRUE;
-- COL1: TRUE

VALUES 3 IN (1, 2, 3) AND 4 NOT IN (1, 2, 3);
-- COL1: TRUE

-- # NOT IN is kept when the predicate is shown.
/* extensions V001-01 */
EXPLAIN VALUES 3 NOT IN (1, 2);
-- EXPLAIN: VALUES (COL1 BOOLEAN) = ROW(3 NOT IN (1, 2))

-- # Columns, in the value or the list. A row is only selected when the result
-- # is TRUE, so a NULL in a NOT IN list selects nothing.
/* setup */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
INSERT INTO t (x) VALUES (2);
INSERT INTO t (x) VALUES (3);
INSERT INTO t (x) VALUES (NULL);

SELECT x FROM t WHERE x IN (1, 3);
-- X: 1
-- X: 3

SELECT x FROM t WHERE x NOT IN (1, 3);
-- X: 2

SELECT x FROM t WHERE x NOT IN (1, CAST(NULL AS INTEGER));

SELECT x FROM t WHERE 2 IN (x);
-- X: 2

SELECT x, x IN (2, x + 1) FROM t;
-- X: 1 COL2: FALSE
-- X: 2 COL2: TRUE
-- X: 3 COL2: FALSE
-- X: NULL COL2: UNKNOWN

-- # Aggregate functions in the value or the list.
SELECT 4 IN (COUNT(*), 1) FROM t;
-- COL1: TRUE

SELECT 1 IN (MIN(x)) FROM t;
-- warning 01003: null value eliminated in set function
-- COL1: TRUE

SELECT MAX(x) IN (2, 3) FROM t;
-- warning 01003: null value eliminated in set function
-- COL1: TRUE

/* extensions V001-01 */
EXPLAIN SELECT * FROM t WHERE x IN (1, 3);
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (X INTEGER)
-- EXPLAIN: WHERE X IN (1, 3)
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.X INTEGER)
