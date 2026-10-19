/* setup */
CREATE TABLE t (a INT);
INSERT INTO t (a) VALUES (123);

VALUES (SELECT a FROM t FETCH FIRST 1 ROW ONLY);
-- error 42601: syntax error: subqueries are not supported in VALUES

VALUES (VALUES 1);
-- error 42601: syntax error: subqueries are not supported in VALUES

VALUES 1, (SELECT a FROM t);
-- error 42601: syntax error: subqueries are not supported in VALUES

SELECT * FROM (VALUES (SELECT a FROM t)) AS x (a);
-- error 42601: syntax error: subqueries are not supported in VALUES

EXPLAIN VALUES (SELECT a FROM t);
-- error 42601: syntax error: subqueries are not supported in VALUES

SELECT * FROM (SELECT a FROM t) AS x;
-- A: 123
