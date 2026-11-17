/* setup */
CREATE TABLE t (a INT);
INSERT INTO t (a) VALUES (123);

-- # A subquery in VALUES is a scalar subquery (F471).
VALUES (SELECT a FROM t FETCH FIRST 1 ROW ONLY);
VALUES (VALUES 1);
-- COL1: 123
-- COL1: 1

VALUES 1, (SELECT a FROM t);
-- COL1: 1
-- COL1: 123

SELECT * FROM (VALUES (SELECT a FROM t)) AS x (a);
-- A: 123

/* extensions V001-01 */
EXPLAIN VALUES (SELECT a FROM t);
-- EXPLAIN: VALUES (COL1 INTEGER) = ROW((SELECT A FROM T))

-- # A subquery of more than one column is a row subquery (F641), so it's a row.
VALUES (SELECT a, a FROM t);
-- COL1: 123 COL2: 123

-- # A scalar subquery can be one field of a ROW, and a subquery in FROM is a
-- # derived table.
VALUES ROW((SELECT a FROM t), 2);
SELECT * FROM (SELECT a FROM t) AS x;
-- COL1: 123 COL2: 2
-- A: 123
