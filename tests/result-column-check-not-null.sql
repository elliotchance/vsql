/* setup */
CREATE TABLE t (a INT CHECK (a IS NOT NULL), b INT, c INT, d INT, e INT, f INT, CHECK (t.b IS NOT NULL), CHECK (c IS NOT NULL) DEFERRABLE, CHECK (d IS NOT NULL OR e IS NOT NULL), CHECK (f IS NULL));
CREATE TABLE p (id INT PRIMARY KEY, x INT CHECK (x IS NOT NULL), y INT);
CREATE TABLE "q r" ("s t" INT CHECK ("s t" IS NOT NULL));
INSERT INTO t (a, b, c, d, e, f) VALUES (1, 2, 3, 4, 5, NULL);
INSERT INTO p (id, x, y) VALUES (1, 2, NULL);

-- # Only an enforced, not deferrable CHECK that's exactly "c IS NOT NULL" makes a
-- # column known not nullable.

/* extensions V001-01 */
EXPLAIN SELECT * FROM t;
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (A INTEGER NOT NULL, B INTEGER NOT NULL, C INTEGER, D INTEGER, E INTEGER, F INTEGER)
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.A INTEGER NOT NULL, ":memory:".PUBLIC.T.B INTEGER NOT NULL, ":memory:".PUBLIC.T.C INTEGER, ":memory:".PUBLIC.T.D INTEGER, ":memory:".PUBLIC.T.E INTEGER, ":memory:".PUBLIC.T.F INTEGER)

/* extensions V001-01 */
EXPLAIN SELECT t.* FROM t;
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (A INTEGER NOT NULL, B INTEGER NOT NULL, C INTEGER, D INTEGER, E INTEGER, F INTEGER)
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.A INTEGER NOT NULL, ":memory:".PUBLIC.T.B INTEGER NOT NULL, ":memory:".PUBLIC.T.C INTEGER, ":memory:".PUBLIC.T.D INTEGER, ":memory:".PUBLIC.T.E INTEGER, ":memory:".PUBLIC.T.F INTEGER)

/* extensions V001-01 */
EXPLAIN SELECT * FROM "q r";
-- EXPLAIN: TABLE ":memory:".PUBLIC."q r" ("s t" INTEGER NOT NULL)
-- EXPLAIN: EXPR (":memory:".PUBLIC."q r"."s t" INTEGER NOT NULL)

-- # A primary key lookup.

/* extensions V001-01 */
EXPLAIN SELECT * FROM p WHERE id = 1;
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.P (ID INTEGER NOT NULL, X INTEGER NOT NULL, Y INTEGER) RANGE ID = 1
-- EXPLAIN: WHERE ID = 1
-- EXPLAIN: EXPR (":memory:".PUBLIC.P.ID INTEGER NOT NULL, ":memory:".PUBLIC.P.X INTEGER NOT NULL, ":memory:".PUBLIC.P.Y INTEGER)

-- # A correlation name, with and without the primary key lookup.

/* extensions V001-01 */
EXPLAIN SELECT * FROM p AS d (i, j, k);
-- EXPLAIN: D:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.P (ID INTEGER NOT NULL, X INTEGER NOT NULL, Y INTEGER)
-- EXPLAIN: TABLE D (I INTEGER NOT NULL, J INTEGER NOT NULL, K INTEGER)
-- EXPLAIN: EXPR (D.I INTEGER NOT NULL, D.J INTEGER NOT NULL, D.K INTEGER)

/* extensions V001-01 */
EXPLAIN SELECT * FROM p AS d (i, j, k) WHERE i = 1;
-- EXPLAIN: D:
-- EXPLAIN:   PRIMARY KEY ":memory:".PUBLIC.P (ID INTEGER NOT NULL, X INTEGER NOT NULL, Y INTEGER) RANGE I = 1
-- EXPLAIN: TABLE D (I INTEGER NOT NULL, J INTEGER NOT NULL, K INTEGER)
-- EXPLAIN: WHERE I = 1
-- EXPLAIN: EXPR (D.I INTEGER NOT NULL, D.J INTEGER NOT NULL, D.K INTEGER)

-- # Both sides of an INNER JOIN.

/* extensions V001-01 */
EXPLAIN SELECT * FROM p INNER JOIN "q r" ON id = "s t";
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.P (ID INTEGER NOT NULL, X INTEGER NOT NULL, Y INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE ":memory:".PUBLIC."q r" ("s t" INTEGER NOT NULL)
-- EXPLAIN: INNER JOIN ON ID = "s t" (":memory:".PUBLIC.P.ID INTEGER NOT NULL, ":memory:".PUBLIC.P.X INTEGER NOT NULL, ":memory:".PUBLIC.P.Y INTEGER, ":memory:".PUBLIC."q r"."s t" INTEGER NOT NULL)
-- EXPLAIN: EXPR (":memory:".PUBLIC.P.ID INTEGER NOT NULL, ":memory:".PUBLIC.P.X INTEGER NOT NULL, ":memory:".PUBLIC.P.Y INTEGER, ":memory:".PUBLIC."q r"."s t" INTEGER NOT NULL)

-- # A derived table, and the rows are still read correctly because the column is
-- # stored as a column that can be NULL.

SELECT * FROM (SELECT * FROM t) AS d;
-- A: 1 B: 2 C: 3 D: 4 E: 5 F: NULL

SELECT * FROM t;
-- A: 1 B: 2 C: 3 D: 4 E: 5 F: NULL

SELECT * FROM p WHERE id = 1;
-- ID: 1 X: 2 Y: NULL
