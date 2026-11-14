-- # Two values are distinct when they aren't equal (General Rules, 1.c.i).
VALUES ROW(1 IS DISTINCT FROM 1, 1 IS DISTINCT FROM 2);
-- COL1: FALSE COL2: TRUE

VALUES ROW(1 IS NOT DISTINCT FROM 1, 1 IS NOT DISTINCT FROM 2);
-- COL1: TRUE COL2: FALSE

-- # Two NULLs aren't distinct (General Rules, 1.a), and a NULL is distinct
-- # from any other value (General Rules, 1.b). So the result is never UNKNOWN.
VALUES CAST(NULL AS INT) IS DISTINCT FROM CAST(NULL AS INT);
-- COL1: FALSE

VALUES CAST(NULL AS INT) IS NOT DISTINCT FROM CAST(NULL AS INT);
-- COL1: TRUE

VALUES ROW(CAST(NULL AS INT) IS DISTINCT FROM 1, 1 IS DISTINCT FROM CAST(NULL AS INT));
-- COL1: TRUE COL2: TRUE

VALUES ROW(CAST(NULL AS INT) IS NOT DISTINCT FROM 1, 1 IS NOT DISTINCT FROM CAST(NULL AS INT));
-- COL1: FALSE COL2: FALSE

VALUES (CAST(NULL AS INT) IS DISTINCT FROM 1) IS UNKNOWN;
-- COL1: FALSE

-- # IS NOT DISTINCT FROM is the same as NOT (... IS DISTINCT FROM ...)
-- # (Syntax Rules, 6).
VALUES ROW(NOT 1 IS DISTINCT FROM 2, NOT CAST(NULL AS INT) IS DISTINCT FROM 1);
-- COL1: FALSE COL2: FALSE

-- # Values are equal by the rules of each type: numbers by their value,
-- # strings padded with spaces, datetimes by their instant and booleans.
VALUES ROW(1 IS DISTINCT FROM 1.0, 1.5 IS DISTINCT FROM CAST(1.5 AS DOUBLE PRECISION), 2 IS DISTINCT FROM 2.5);
-- COL1: FALSE COL2: FALSE COL3: TRUE

VALUES ROW('a' IS DISTINCT FROM 'a  ', 'a' IS DISTINCT FROM 'A', 'a' IS NOT DISTINCT FROM CAST('a' AS CHAR(5)));
-- COL1: FALSE COL2: TRUE COL3: TRUE

VALUES ROW(DATE '2024-01-02' IS DISTINCT FROM DATE '2024-01-02', DATE '2024-01-02' IS DISTINCT FROM DATE '2024-01-03');
-- COL1: FALSE COL2: TRUE

VALUES TIMESTAMP '2024-01-02 03:04:05+01:00' IS NOT DISTINCT FROM TIMESTAMP '2024-01-02 02:04:05+00:00';
-- COL1: TRUE

VALUES ROW(TRUE IS DISTINCT FROM TRUE, TRUE IS DISTINCT FROM FALSE, (1 = 1) IS NOT DISTINCT FROM TRUE);
-- COL1: FALSE COL2: TRUE COL3: TRUE

-- # Rows are distinct when any of their fields are (General Rules, 1.c.iv),
-- # including fields that are NULL.
VALUES ROW((1, 2) IS DISTINCT FROM (1, 2), (1, 2) IS DISTINCT FROM (1, 3), (1, 2) IS DISTINCT FROM (2, 2));
-- COL1: FALSE COL2: TRUE COL3: TRUE

VALUES ROW((1, CAST(NULL AS INT)) IS DISTINCT FROM (1, CAST(NULL AS INT)), (1, CAST(NULL AS INT)) IS NOT DISTINCT FROM (1, CAST(NULL AS INT)));
-- COL1: FALSE COL2: TRUE

VALUES ROW((1, CAST(NULL AS INT)) IS DISTINCT FROM (1, 2), (CAST(NULL AS INT), 2) IS NOT DISTINCT FROM (1, 2));
-- COL1: TRUE COL2: FALSE

VALUES ROW(ROW(1) IS DISTINCT FROM 1, ROW(1, 'a') IS NOT DISTINCT FROM ROW(1, 'a'));
-- COL1: FALSE COL2: TRUE

-- # In a WHERE, NULLs match each other.
CREATE TABLE t (x INT, y INT);
INSERT INTO t (x, y) VALUES (1, 1);
INSERT INTO t (x, y) VALUES (1, 2);
INSERT INTO t (x, y) VALUES (1, NULL);
INSERT INTO t (x, y) VALUES (NULL, NULL);
VALUES 'distinct';
SELECT * FROM t WHERE x IS DISTINCT FROM y;
VALUES 'not distinct';
SELECT * FROM t WHERE x IS NOT DISTINCT FROM y;
VALUES 'rows';
SELECT * FROM t WHERE (x, y) IS NOT DISTINCT FROM (1, CAST(NULL AS INT));
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- COL1: distinct
-- X: 1 Y: 2
-- X: 1 Y: NULL
-- COL1: not distinct
-- X: 1 Y: 1
-- X: NULL Y: NULL
-- COL1: rows
-- X: 1 Y: NULL

-- # Either side can be an aggregate.
CREATE TABLE t (x INT);
SELECT COUNT(*) IS DISTINCT FROM 0, 0 IS NOT DISTINCT FROM MAX(x) FROM t;
-- msg: CREATE TABLE 1
-- COL1: FALSE COL2: FALSE

-- # The predicate is kept when it's shown.
/* extensions V001-01 */
EXPLAIN VALUES ROW(1 IS DISTINCT FROM 2, (1, 2) IS NOT DISTINCT FROM (1, 2));
-- EXPLAIN: VALUES (COL1 BOOLEAN, COL2 BOOLEAN) = ROW(1 IS DISTINCT FROM 2, ROW(1, 2) IS NOT DISTINCT FROM ROW(1, 2))

-- # The rows must have the same degree (Syntax Rules, 1), and the respective
-- # fields must be comparable (Syntax Rules, 3).
VALUES (1, 2) IS DISTINCT FROM (1, 2, 3);
-- error 42601: syntax error: cannot compare a row of degree 2 with a row of degree 3

VALUES 1 IS NOT DISTINCT FROM (1, 2);
-- error 42601: syntax error: cannot compare a row of degree 1 with a row of degree 2

VALUES 'a' IS DISTINCT FROM 1;
-- error 42883: cannot compare CHARACTER(1) and SMALLINT

VALUES (1, 'a') IS NOT DISTINCT FROM (1, 2);
-- error 42883: cannot compare CHARACTER(1) and SMALLINT

-- # A parameter that's NULL is distinct from any value but NULL, whatever its
-- # type.
/* params NULL VARCHAR NULL INT */
VALUES ROW(1 IS DISTINCT FROM ?, CAST(NULL AS INT) IS NOT DISTINCT FROM ?);
-- sql: VALUES ROW(1 IS DISTINCT FROM CAST(NULL AS CHARACTER VARYING), CAST(NULL AS INT) IS NOT DISTINCT FROM CAST(NULL AS INTEGER))
-- COL1: TRUE COL2: TRUE

-- # It's flagged with T151, and with negation also T152 (Conformance Rules,
-- # 1 and 2).
/* setup */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);

/* flags */
SELECT x FROM t WHERE x IS DISTINCT FROM 2;
-- flags: T151
-- X: 1

/* flags */
SELECT x FROM t WHERE x IS NOT DISTINCT FROM 1;
-- flags: T151, T152
-- X: 1
