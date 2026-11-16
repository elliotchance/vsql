-- # F262 Extended CASE expression: a <when operand> can also be an IS [NOT]
-- # DISTINCT FROM or an OVERLAPS, with the case operand on the left (Syntax
-- # Rules, 2.i).
/* setup */
CREATE TABLE t (x INT, d1 DATE, d2 DATE);
INSERT INTO t (x, d1, d2) VALUES (1, DATE '2020-01-01', DATE '2020-01-31'), (2, DATE '2020-03-01', DATE '2020-03-31'), (NULL, NULL, NULL);

-- # <distinct predicate part 2>: unlike =, a NULL isn't distinct from a NULL.
SELECT x, CASE x WHEN IS DISTINCT FROM 1 THEN 'not 1' ELSE '1' END, CASE x WHEN IS NOT DISTINCT FROM CAST(NULL AS INT) THEN 'null' ELSE 'not null' END FROM t;
-- X: 1 COL2: 1     COL3: not null
-- X: 2 COL2: not 1 COL3: not null
-- X: NULL COL2: not 1 COL3: null

VALUES CASE (1, 2) WHEN IS NOT DISTINCT FROM (1, 3) THEN 'a' WHEN IS DISTINCT FROM (1, 3) THEN 'b' END;
-- COL1: b

-- # <overlaps predicate part 2>: the case operand is a period.
SELECT x, CASE (d1, d2) WHEN OVERLAPS (DATE '2020-01-15', DATE '2020-02-15') THEN 'jan' WHEN OVERLAPS (DATE '2020-03-15', DATE '2020-03-16') THEN 'mar' ELSE 'none' END FROM t;
-- X: 1 COL2: jan
-- X: 2 COL2: mar
-- X: NULL COL2: none

VALUES CASE (DATE '2020-01-01', DATE '2020-02-01') WHEN OVERLAPS (DATE '2020-05-01', DATE '2020-06-01'), OVERLAPS (DATE '2020-01-15', DATE '2020-01-16') THEN 'yes' END;
-- COL1: yes

-- # Either every <when operand> is an OVERLAPS (the case operand is an
-- # <overlaps predicate part 1>), or none of them are (it's a <row value
-- # predicand>) (Syntax Rules, 2.c).
VALUES CASE (DATE '2020-01-01', DATE '2020-02-01') WHEN OVERLAPS (DATE '2020-01-15', DATE '2020-03-01') THEN 'a' WHEN (DATE '2020-01-01', DATE '2020-02-01') THEN 'b' END;
VALUES CASE (DATE '2020-01-01', DATE '2020-02-01') WHEN IS NULL, OVERLAPS (DATE '2020-01-15', DATE '2020-03-01') THEN 'a' END;
-- error 42601: syntax error: either every WHEN operand of a CASE is OVERLAPS, or none of them are
-- error 42601: syntax error: either every WHEN operand of a CASE is OVERLAPS, or none of them are

-- # The predicates have the same rules as on their own.
VALUES CASE DATE '2020-01-01' WHEN OVERLAPS (DATE '2020-01-15', DATE '2020-03-01') THEN 'a' END;
VALUES CASE 1 WHEN IS DISTINCT FROM (1, 2) THEN 'a' END;
VALUES CASE 1 WHEN IS DISTINCT FROM 'a' THEN 'a' END;
-- error 42601: syntax error: OVERLAPS needs a row of degree 2, not 1
-- error 42601: syntax error: cannot compare a row of degree 1 with a row of degree 2
-- error 42883: cannot compare INTEGER and CHARACTER(1)

-- # They need F262, and the features of the predicate: T151 for DISTINCT (and
-- # T152 with NOT), and F053 for OVERLAPS (Syntax Rules, 2.k).
/* flags */
SELECT CASE x WHEN IS DISTINCT FROM 2 THEN 'a' END FROM t WHERE x = 1;
-- flags: F262, T151
-- COL1: a

/* flags */
SELECT CASE x WHEN IS NOT DISTINCT FROM 2 THEN 'a' END FROM t WHERE x = 2;
-- flags: F262, T151, T152
-- COL1: a

/* flags */
SELECT CASE (d1, d2) WHEN OVERLAPS (d2, d1) THEN 'a' END FROM t WHERE x = 1;
-- flags: F053, F262, F641
-- COL1: a
