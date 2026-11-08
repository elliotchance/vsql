/* setup */
CREATE TABLE a (id INT NOT NULL, x INT);
CREATE TABLE b (id INT NOT NULL, y INT);
CREATE TABLE c (id INT NOT NULL);
CREATE TABLE pk (id INT PRIMARY KEY);
INSERT INTO a (id, x) VALUES (1, 10);
INSERT INTO b (id, y) VALUES (2, 20);

-- # A result column that's just a reference to a NOT NULL column is NOT NULL
-- # too, however the column is named (Syntax Rules, 20). That includes a
-- # PRIMARY KEY column and a column renamed by a correlation name.
/* extensions V001-01 */
EXPLAIN SELECT id, x FROM a;
-- EXPLAIN: TABLE ":memory:".PUBLIC.A (ID INTEGER NOT NULL, X INTEGER)
-- EXPLAIN: EXPR (ID INTEGER NOT NULL, X INTEGER)

/* extensions V001-01 */
EXPLAIN SELECT * FROM a;
-- EXPLAIN: TABLE ":memory:".PUBLIC.A (ID INTEGER NOT NULL, X INTEGER)
-- EXPLAIN: EXPR (":memory:".PUBLIC.A.ID INTEGER NOT NULL, ":memory:".PUBLIC.A.X INTEGER)

/* extensions V001-01 */
EXPLAIN SELECT a.id AS p, public.a.id AS q FROM a;
-- EXPLAIN: TABLE ":memory:".PUBLIC.A (ID INTEGER NOT NULL, X INTEGER)
-- EXPLAIN: EXPR (P INTEGER NOT NULL, Q INTEGER NOT NULL)

/* extensions V001-01 */
EXPLAIN SELECT id FROM pk;
-- EXPLAIN: TABLE ":memory:".PUBLIC.PK (ID INTEGER NOT NULL)
-- EXPLAIN: EXPR (ID INTEGER NOT NULL)

/* extensions V001-01 */
EXPLAIN SELECT d.i FROM a AS d (i, j);
-- EXPLAIN: D:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.A (ID INTEGER NOT NULL, X INTEGER)
-- EXPLAIN: TABLE D (I INTEGER NOT NULL, J INTEGER)
-- EXPLAIN: EXPR (I INTEGER NOT NULL)

-- # Any other expression can be NULL, even one that never is, because vsql
-- # doesn't have T101 (Syntax Rules, 21). A column in parentheses isn't just a
-- # column reference.
/* extensions V001-01 */
EXPLAIN SELECT id + 1, (id), 1, COALESCE(id, 1) FROM a;
-- EXPLAIN: TABLE ":memory:".PUBLIC.A (ID INTEGER NOT NULL, X INTEGER)
-- EXPLAIN: EXPR (COL1 INTEGER, COL2 INTEGER, COL3 SMALLINT, COL4 INTEGER)

-- # A grouping column and a column of a derived table stay NOT NULL, but
-- # COUNT(*) is another expression.
/* extensions V001-01 */
EXPLAIN SELECT id, COUNT(*) FROM a GROUP BY id;
-- EXPLAIN: TABLE ":memory:".PUBLIC.A (ID INTEGER NOT NULL, X INTEGER)
-- EXPLAIN: ORDER BY ID ASC
-- EXPLAIN: GROUP BY (":memory:".PUBLIC.A.ID INTEGER NOT NULL, COUNT(*) INTEGER)
-- EXPLAIN: EXPR (ID INTEGER NOT NULL, COL2 INTEGER)

/* extensions V001-01 */
EXPLAIN SELECT i, x FROM (SELECT id AS i, x FROM a) AS d;
-- EXPLAIN: D:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.A (ID INTEGER NOT NULL, X INTEGER)
-- EXPLAIN:   EXPR (I INTEGER NOT NULL, X INTEGER)
-- EXPLAIN: TABLE D (I INTEGER NOT NULL, X INTEGER)
-- EXPLAIN: EXPR (I INTEGER NOT NULL, X INTEGER)

-- # A scalar subquery is NULL when it has no rows, so it can be NULL even when
-- # its column can't. A column of a UNION ALL can be NULL too, since vsql
-- # doesn't have T101 (7.17, Syntax Rules, 19.b.ii.1.A).
/* extensions V001-01 */
EXPLAIN SELECT (SELECT a.id FROM c) FROM a;
-- EXPLAIN: TABLE ":memory:".PUBLIC.A (ID INTEGER NOT NULL, X INTEGER)
-- EXPLAIN: EXPR (COL1 INTEGER)

/* extensions V001-01 */
EXPLAIN SELECT id FROM a UNION ALL SELECT id FROM b;
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.A (ID INTEGER NOT NULL, X INTEGER)
-- EXPLAIN:   EXPR (ID INTEGER NOT NULL)
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.B (ID INTEGER NOT NULL, Y INTEGER)
-- EXPLAIN:   EXPR (ID INTEGER NOT NULL)
-- EXPLAIN: UNION ALL (ID INTEGER)

-- # An INNER JOIN keeps NOT NULL. An outer join keeps it only on the side that
-- # it preserves, since the other side is NULL for a row without a match, and
-- # that carries through nested joins, WHERE and ORDER BY. The standard has no
-- # outer join column known not null (7.10, Syntax Rules, 14.a), so keeping
-- # the preserved side is vsql's own rule (7.10, Syntax Rules, 15.c).
/* extensions V001-01 */
EXPLAIN SELECT a.id AS p, b.id AS q, y FROM a INNER JOIN b ON a.id = b.id;
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.A (ID INTEGER NOT NULL, X INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.B (ID INTEGER NOT NULL, Y INTEGER)
-- EXPLAIN: INNER JOIN ON A.ID = B.ID (":memory:".PUBLIC.A.ID INTEGER NOT NULL, ":memory:".PUBLIC.A.X INTEGER, ":memory:".PUBLIC.B.ID INTEGER NOT NULL, ":memory:".PUBLIC.B.Y INTEGER)
-- EXPLAIN: EXPR (P INTEGER NOT NULL, Q INTEGER NOT NULL, Y INTEGER)

/* extensions V001-01 */
EXPLAIN SELECT * FROM a LEFT JOIN b ON a.id = b.id;
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.A (ID INTEGER NOT NULL, X INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.B (ID INTEGER NOT NULL, Y INTEGER)
-- EXPLAIN: LEFT JOIN ON A.ID = B.ID (":memory:".PUBLIC.A.ID INTEGER NOT NULL, ":memory:".PUBLIC.A.X INTEGER, ":memory:".PUBLIC.B.ID INTEGER, ":memory:".PUBLIC.B.Y INTEGER)
-- EXPLAIN: EXPR (":memory:".PUBLIC.A.ID INTEGER NOT NULL, ":memory:".PUBLIC.A.X INTEGER, ":memory:".PUBLIC.B.ID INTEGER, ":memory:".PUBLIC.B.Y INTEGER)

/* extensions V001-01 */
EXPLAIN SELECT a.id AS p, b.id AS q FROM a LEFT JOIN b ON a.id = b.id;
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.A (ID INTEGER NOT NULL, X INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.B (ID INTEGER NOT NULL, Y INTEGER)
-- EXPLAIN: LEFT JOIN ON A.ID = B.ID (":memory:".PUBLIC.A.ID INTEGER NOT NULL, ":memory:".PUBLIC.A.X INTEGER, ":memory:".PUBLIC.B.ID INTEGER, ":memory:".PUBLIC.B.Y INTEGER)
-- EXPLAIN: EXPR (P INTEGER NOT NULL, Q INTEGER)

/* extensions V001-01 */
EXPLAIN SELECT a.id AS p, b.* FROM a RIGHT JOIN b ON a.id = b.id;
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.A (ID INTEGER NOT NULL, X INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.B (ID INTEGER NOT NULL, Y INTEGER)
-- EXPLAIN: RIGHT JOIN ON A.ID = B.ID (":memory:".PUBLIC.A.ID INTEGER, ":memory:".PUBLIC.A.X INTEGER, ":memory:".PUBLIC.B.ID INTEGER NOT NULL, ":memory:".PUBLIC.B.Y INTEGER)
-- EXPLAIN: EXPR (P INTEGER, ":memory:".PUBLIC.B.ID INTEGER NOT NULL, ":memory:".PUBLIC.B.Y INTEGER)

/* extensions V001-01 */
EXPLAIN SELECT a.id AS p, b.id AS q, c.id AS r FROM a LEFT JOIN b ON a.id = b.id INNER JOIN c ON a.id = c.id;
-- EXPLAIN: $1:
-- EXPLAIN:   $1:
-- EXPLAIN:     TABLE ":memory:".PUBLIC.A (ID INTEGER NOT NULL, X INTEGER)
-- EXPLAIN:   $2:
-- EXPLAIN:     TABLE ":memory:".PUBLIC.B (ID INTEGER NOT NULL, Y INTEGER)
-- EXPLAIN:   LEFT JOIN ON A.ID = B.ID (":memory:".PUBLIC.A.ID INTEGER NOT NULL, ":memory:".PUBLIC.A.X INTEGER, ":memory:".PUBLIC.B.ID INTEGER, ":memory:".PUBLIC.B.Y INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.C (ID INTEGER NOT NULL)
-- EXPLAIN: INNER JOIN ON A.ID = C.ID (":memory:".PUBLIC.A.ID INTEGER NOT NULL, ":memory:".PUBLIC.A.X INTEGER, ":memory:".PUBLIC.B.ID INTEGER, ":memory:".PUBLIC.B.Y INTEGER, ":memory:".PUBLIC.C.ID INTEGER NOT NULL)
-- EXPLAIN: EXPR (P INTEGER NOT NULL, Q INTEGER, R INTEGER NOT NULL)

/* extensions V001-01 */
EXPLAIN SELECT a.id AS p, b.id AS q, c.id AS r FROM a INNER JOIN b ON a.id = b.id RIGHT JOIN c ON a.id = c.id;
-- EXPLAIN: $1:
-- EXPLAIN:   $1:
-- EXPLAIN:     TABLE ":memory:".PUBLIC.A (ID INTEGER NOT NULL, X INTEGER)
-- EXPLAIN:   $2:
-- EXPLAIN:     TABLE ":memory:".PUBLIC.B (ID INTEGER NOT NULL, Y INTEGER)
-- EXPLAIN:   INNER JOIN ON A.ID = B.ID (":memory:".PUBLIC.A.ID INTEGER NOT NULL, ":memory:".PUBLIC.A.X INTEGER, ":memory:".PUBLIC.B.ID INTEGER NOT NULL, ":memory:".PUBLIC.B.Y INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.C (ID INTEGER NOT NULL)
-- EXPLAIN: RIGHT JOIN ON A.ID = C.ID (":memory:".PUBLIC.A.ID INTEGER, ":memory:".PUBLIC.A.X INTEGER, ":memory:".PUBLIC.B.ID INTEGER, ":memory:".PUBLIC.B.Y INTEGER, ":memory:".PUBLIC.C.ID INTEGER NOT NULL)
-- EXPLAIN: EXPR (P INTEGER, Q INTEGER, R INTEGER NOT NULL)

/* extensions V001-01 */
EXPLAIN SELECT a.id AS p, b.id AS q, c.id AS r FROM a LEFT JOIN (b INNER JOIN c ON b.id = c.id) ON a.id = b.id;
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.A (ID INTEGER NOT NULL, X INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   $1:
-- EXPLAIN:     TABLE ":memory:".PUBLIC.B (ID INTEGER NOT NULL, Y INTEGER)
-- EXPLAIN:   $2:
-- EXPLAIN:     TABLE ":memory:".PUBLIC.C (ID INTEGER NOT NULL)
-- EXPLAIN:   INNER JOIN ON B.ID = C.ID (":memory:".PUBLIC.B.ID INTEGER NOT NULL, ":memory:".PUBLIC.B.Y INTEGER, ":memory:".PUBLIC.C.ID INTEGER NOT NULL)
-- EXPLAIN: LEFT JOIN ON A.ID = B.ID (":memory:".PUBLIC.A.ID INTEGER NOT NULL, ":memory:".PUBLIC.A.X INTEGER, ":memory:".PUBLIC.B.ID INTEGER, ":memory:".PUBLIC.B.Y INTEGER, ":memory:".PUBLIC.C.ID INTEGER)
-- EXPLAIN: EXPR (P INTEGER NOT NULL, Q INTEGER, R INTEGER)

/* extensions V001-01 */
EXPLAIN SELECT a.id AS p, d.i FROM a LEFT JOIN (SELECT id AS i FROM b) AS d ON a.id = d.i;
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.A (ID INTEGER NOT NULL, X INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   D:
-- EXPLAIN:     TABLE ":memory:".PUBLIC.B (ID INTEGER NOT NULL, Y INTEGER)
-- EXPLAIN:     EXPR (I INTEGER NOT NULL)
-- EXPLAIN:   TABLE D (I INTEGER NOT NULL)
-- EXPLAIN: LEFT JOIN ON A.ID = D.I (":memory:".PUBLIC.A.ID INTEGER NOT NULL, ":memory:".PUBLIC.A.X INTEGER, D.I INTEGER)
-- EXPLAIN: EXPR (P INTEGER NOT NULL, I INTEGER)

/* extensions V001-01 */
EXPLAIN SELECT a.id AS p, b.id AS q FROM a LEFT JOIN b ON a.id = b.id WHERE a.id > 0 ORDER BY a.id;
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.A (ID INTEGER NOT NULL, X INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.B (ID INTEGER NOT NULL, Y INTEGER)
-- EXPLAIN: LEFT JOIN ON A.ID = B.ID (":memory:".PUBLIC.A.ID INTEGER NOT NULL, ":memory:".PUBLIC.A.X INTEGER, ":memory:".PUBLIC.B.ID INTEGER, ":memory:".PUBLIC.B.Y INTEGER)
-- EXPLAIN: WHERE A.ID > 0
-- EXPLAIN: ORDER BY A.ID ASC
-- EXPLAIN: EXPR (P INTEGER NOT NULL, Q INTEGER)

-- # The NULLs that an outer join puts in a NOT NULL column.
SELECT a.id AS p, b.id AS q FROM a LEFT JOIN b ON a.id = b.id;
-- P: 1 Q: NULL

SELECT a.id AS p, b.id AS q FROM a RIGHT JOIN b ON a.id = b.id;
-- P: NULL Q: 2
