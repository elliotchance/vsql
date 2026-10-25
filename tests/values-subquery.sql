/* setup */
CREATE TABLE t (a INT);
INSERT INTO t (a) VALUES (123);

-- # A subquery in VALUES is a scalar subquery (F471).
VALUES (SELECT a FROM t FETCH FIRST 1 ROW ONLY);
-- COL1: 123

VALUES (VALUES 1);
-- COL1: 1

VALUES 1, (SELECT a FROM t);
-- COL1: 1
-- COL1: 123

SELECT * FROM (VALUES (SELECT a FROM t)) AS x (a);
-- A: 123

EXPLAIN VALUES (SELECT a FROM t);
-- EXPLAIN: VALUES (COL1 INTEGER) = ROW((SELECT A FROM T))

-- # A row subquery (F641) isn't supported yet.
VALUES (SELECT a, a FROM t);
-- error 42601: syntax error: subquery must return only one column

VALUES ROW((SELECT a FROM t), 2);
-- COL1: 123 COL2: 2

SELECT * FROM (SELECT a FROM t) AS x;
-- A: 123
