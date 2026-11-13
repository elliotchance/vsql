/* setup */
CREATE TABLE t1 (x INT, y VARCHAR(10));
CREATE TABLE t2 (x INT);
INSERT INTO t1 (x, y) VALUES (1, 'a'), (2, 'a'), (3, NULL), (3, NULL);

-- # UNIQUE is TRUE when no two rows of the subquery are equal (F291).
VALUES UNIQUE (SELECT x FROM t1 WHERE x < 3);
-- COL1: TRUE

VALUES UNIQUE (SELECT x, y FROM t1 WHERE x < 3);
-- COL1: TRUE

-- # It's FALSE when there are duplicate rows.
VALUES UNIQUE (SELECT y FROM t1 WHERE x < 3);
-- COL1: FALSE

VALUES UNIQUE (VALUES ROW(1, 'a'), ROW(2, 'b'), ROW(1, 'a'));
-- COL1: FALSE

VALUES UNIQUE (VALUES ROW(1, 'a'), ROW(1, 'b'), ROW(2, 'a'));
-- COL1: TRUE

-- # It's TRUE (never UNKNOWN) when there are no rows.
VALUES UNIQUE (SELECT * FROM t2);
-- COL1: TRUE

VALUES NOT UNIQUE (SELECT * FROM t2);
-- COL1: FALSE

-- # A row that contains a NULL is never a duplicate, so NULLs don't make it
-- # FALSE (or UNKNOWN), even when every value of the rows is the same.
VALUES UNIQUE (SELECT x, y FROM t1);
-- COL1: TRUE

VALUES UNIQUE (SELECT y FROM t1 WHERE x = 3);
-- COL1: TRUE

VALUES UNIQUE (SELECT x FROM t1 WHERE x = 3);
-- COL1: FALSE

VALUES NOT UNIQUE (SELECT x FROM t1 WHERE x = 3);
-- COL1: TRUE

VALUES UNIQUE (SELECT x FROM t1 WHERE x = 3 FETCH FIRST 1 ROW ONLY);
-- COL1: TRUE

-- # Values are equal when = is TRUE for them, so 1.5 and 1.50 are duplicates.
VALUES UNIQUE (VALUES 1.5, 1.50);
-- COL1: FALSE

VALUES UNIQUE (VALUES 1, 1.5);
-- COL1: TRUE

-- # Strings are compared as if the shorter one is padded with spaces.
VALUES UNIQUE (VALUES 'a', 'a ');
-- COL1: FALSE

VALUES UNIQUE (VALUES 'a', 'a b');
-- COL1: TRUE

-- # The subquery can use DISTINCT and set operations.
VALUES UNIQUE (SELECT DISTINCT y FROM t1);
-- COL1: TRUE

VALUES UNIQUE (SELECT x FROM t1 WHERE x < 3 UNION ALL VALUES 2);
-- COL1: FALSE

VALUES UNIQUE (SELECT x FROM t1 WHERE x < 3 UNION VALUES 2);
-- COL1: TRUE

-- # A correlated subquery is evaluated for each row.
SELECT x, y, UNIQUE (SELECT y FROM t1 AS b WHERE b.x <= a.x) AS u FROM t1 AS a;
-- X: 1 Y: a U: TRUE
-- X: 2 Y: a U: FALSE
-- X: 3 Y: NULL U: FALSE
-- X: 3 Y: NULL U: FALSE

SELECT * FROM t1 AS a WHERE UNIQUE (SELECT x FROM t1 AS b WHERE b.x = a.x);
-- X: 1 Y: a
-- X: 2 Y: a

SELECT * FROM t1 AS a WHERE NOT UNIQUE (SELECT x FROM t1 AS b WHERE b.x = a.x);
-- X: 3 Y: NULL
-- X: 3 Y: NULL

-- # Errors in the subquery are found even when there are no rows to test.
SELECT * FROM t2 WHERE UNIQUE (SELECT * FROM t3);
-- error 42P01: no such table: ":memory:".PUBLIC.T3

SELECT * FROM t2 WHERE UNIQUE (SELECT foo FROM t1);
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.FOO

-- # A subquery can't be used in a CHECK constraint (F671).
CREATE TABLE t3 (x INT CHECK (UNIQUE (SELECT * FROM t1)));
-- error 42601: syntax error: a subquery cannot be used in a CHECK constraint

-- # UNIQUE isn't Core SQL.
/* flags */
SELECT x FROM t1 WHERE UNIQUE (SELECT x FROM t2);
-- flags: F291
-- X: 1
-- X: 2
-- X: 3
-- X: 3

/* extensions V001-01 */
EXPLAIN SELECT * FROM t1 WHERE NOT UNIQUE (SELECT x FROM t2 WHERE x > 1);
-- EXPLAIN: TABLE ":memory:".PUBLIC.T1 (X INTEGER, Y CHARACTER VARYING(10))
-- EXPLAIN: WHERE NOT UNIQUE (SELECT X FROM T2 WHERE X > 1)
-- EXPLAIN: EXPR (":memory:".PUBLIC.T1.X INTEGER, ":memory:".PUBLIC.T1.Y CHARACTER VARYING(10))
