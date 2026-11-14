/* setup */
CREATE TABLE t (x INT, y VARCHAR(10));
INSERT INTO t (x, y) VALUES (1, NULL), (1, NULL), (NULL, NULL), (NULL, NULL), (2, 'a');

-- # NULLS DISTINCT is the same as no <unique null treatment>: a row with a
-- # NULL is never a duplicate. NULLS NOT DISTINCT makes a NULL the same as
-- # another NULL (F292, Conformance Rules, 2 and General Rules, 2.b and 2.c).
/* flags */
VALUES ROW(UNIQUE NULLS DISTINCT (SELECT x, y FROM t), UNIQUE NULLS NOT DISTINCT (SELECT x, y FROM t));
-- flags: F291, F292, F641, F661, T031, T051
-- COL1: TRUE COL2: FALSE

-- # Rows that are all NULL are duplicates too.
VALUES ROW(UNIQUE NULLS NOT DISTINCT (SELECT x, y FROM t WHERE x IS NULL), UNIQUE NULLS NOT DISTINCT (SELECT x, y FROM t WHERE x = 1), UNIQUE NULLS NOT DISTINCT (VALUES ROW(CAST(NULL AS INT), 1), ROW(CAST(NULL AS INT), 2)));
-- COL1: FALSE COL2: FALSE COL3: TRUE

VALUES UNIQUE NULLS NOT DISTINCT (VALUES ROW(1, CAST(NULL AS INT)), ROW(1, 2));
-- COL1: TRUE
