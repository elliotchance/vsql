/* setup */
CREATE TABLE t (a INT, b VARCHAR(10));
INSERT INTO t (a, b) VALUES (2, 'x');
INSERT INTO t (a, b) VALUES (1, 'y');

-- # "TABLE t" is the same as "SELECT * FROM t".
TABLE t;
-- A: 2 B: x
-- A: 1 B: y

TABLE PUBLIC.t ORDER BY a OFFSET 1 ROW FETCH FIRST 1 ROW ONLY;
-- A: 2 B: x

SELECT * FROM (TABLE t) AS x (c, d) WHERE c = 1;
-- C: 1 D: y

VALUES (SELECT COUNT(*) FROM (TABLE t) AS x);
-- COL1: 2

TABLE t UNION ALL TABLE t ORDER BY a FETCH FIRST 3 ROWS ONLY;
-- A: 1 B: y
-- A: 1 B: y
-- A: 2 B: x

TABLE t EXCEPT TABLE t;

-- # EXPLAIN shows a scan of the whole table, as for SELECT * FROM t.
/* extensions V001-01 */
EXPLAIN TABLE t;
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (A INTEGER, B CHARACTER VARYING(10))
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.A INTEGER, ":memory:".PUBLIC.T.B CHARACTER VARYING(10))

-- # A table that doesn't exist is an error, the same as in a FROM clause.
TABLE missing;
-- error 42P01: no such table: ":memory:".PUBLIC.MISSING

-- # An explicit table needs F661 (Conformance Rules, 6).
/* flags */
TABLE t;
-- flags: F661
-- A: 2 B: x
-- A: 1 B: y
