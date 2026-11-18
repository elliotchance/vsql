-- # A CHARACTER LARGE OBJECT or BINARY LARGE OBJECT can't be an operand of a
-- # grouping operation (Part 2, 9.12, Syntax Rules, 3): GROUP BY, an aggregate
-- # function with DISTINCT, SELECT DISTINCT, UNION (but not UNION ALL), EXCEPT,
-- # INTERSECT or UNIQUE.
/* setup */
CREATE TABLE t (a INT, c CLOB, b BLOB, v VARCHAR(10));
INSERT INTO t VALUES (1, 'x', X'01', 'x');

SELECT c FROM t GROUP BY c;
-- error 42601: syntax error: column C in GROUP BY cannot be a CHARACTER LARGE OBJECT

SELECT b, COUNT(*) FROM t GROUP BY a, b;
-- error 42601: syntax error: column B in GROUP BY cannot be a BINARY LARGE OBJECT

SELECT COUNT(DISTINCT c) FROM t;
-- error 42601: syntax error: DISTINCT argument of COUNT cannot be a CHARACTER LARGE OBJECT

SELECT LISTAGG(DISTINCT c, ',') WITHIN GROUP (ORDER BY a) FROM t;
-- error 42601: syntax error: DISTINCT argument of LISTAGG cannot be a CHARACTER LARGE OBJECT

SELECT DISTINCT a, b FROM t;
-- error 42601: syntax error: column 2 of SELECT DISTINCT cannot be a BINARY LARGE OBJECT

SELECT DISTINCT * FROM t;
-- error 42601: syntax error: column 2 of SELECT DISTINCT cannot be a CHARACTER LARGE OBJECT

SELECT c FROM t UNION SELECT c FROM t;
-- error 42601: syntax error: column 1 of UNION cannot be a CHARACTER LARGE OBJECT

SELECT a, b FROM t EXCEPT ALL SELECT a, b FROM t;
-- error 42601: syntax error: column 2 of EXCEPT cannot be a BINARY LARGE OBJECT

SELECT c FROM t INTERSECT SELECT v FROM t;
-- error 42601: syntax error: column 1 of INTERSECT cannot be a CHARACTER LARGE OBJECT

SELECT a FROM t WHERE UNIQUE (SELECT b FROM t);
-- error 42601: syntax error: column 1 of UNIQUE cannot be a BINARY LARGE OBJECT

-- # UNION ALL keeps every row, so it isn't a grouping operation, and a large
-- # object can be anywhere else in a grouped or distinct query.
SELECT c, b FROM t UNION ALL SELECT c, b FROM t;
-- C: x B: 01
-- C: x B: 01

SELECT a, COUNT(c), MAX(v) FROM t GROUP BY a;
-- A: 1 COL2: 1 COL3: x

SELECT DISTINCT a, v FROM t;
-- A: 1 V: x
