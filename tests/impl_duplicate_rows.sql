-- # Duplicate rows (for DISTINCT, UNION, EXCEPT and INTERSECT) are found without
-- # comparing each row with every other row, by grouping the rows that could be
-- # duplicates. Equal values of different types, and strings that only differ by
-- # spaces on the end, must still be found.

VALUES (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM (VALUES (1), (1.0), (CAST(1 AS DOUBLE PRECISION)), (2), (CAST(NULL AS INT)), (CAST(NULL AS INT))) AS t (x)) AS d);
-- COL1: 3

VALUES (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM (VALUES (CAST(0 AS DOUBLE PRECISION)), (CAST(-0.0 AS DOUBLE PRECISION)), (0.0)) AS t (x)) AS d);
-- COL1: 1

SELECT DISTINCT x FROM (VALUES ('a'), ('a  '), (CAST('a' AS CHAR(3))), ('b')) AS t (x);
-- X: a
-- X: b

SELECT DISTINCT x FROM (VALUES (TRUE), (FALSE), (TRUE), (CAST(NULL AS BOOLEAN))) AS t (x);
-- X: TRUE
-- X: FALSE
-- X: UNKNOWN

SELECT DISTINCT x FROM (VALUES (DATE '2024-01-01'), (DATE '2024-01-02'), (DATE '2024-01-01')) AS t (x);
-- X: 2024-01-01
-- X: 2024-01-02

VALUES 1, 2, 2, 3 EXCEPT ALL VALUES 2, 3.0, 4;
-- COL1: 1.0
-- COL1: 2.0

VALUES 'a', 'b ', 'b' INTERSECT ALL VALUES 'b', 'c';
-- COL1: b 

VALUES 1.5, 2 UNION VALUES 2.0, 3;
-- COL1: 1.5
-- COL1: 2.0
-- COL1: 3.0
