/* setup */
CREATE TABLE t (a INT, b VARCHAR(10), c DOUBLE PRECISION);
INSERT INTO t (a, b, c) VALUES (1, 'x', 1.5);
INSERT INTO t (a, b, c) VALUES (2, 'y', 2.5);
INSERT INTO t (a, b, c) VALUES (1, 'x', 3.5);
INSERT INTO t (a, b, c) VALUES (NULL, 'y', NULL);
INSERT INTO t (a, b, c) VALUES (NULL, NULL, NULL);
INSERT INTO t (a, b, c) VALUES (2, NULL, 1.5);
INSERT INTO t (a, b, c) VALUES (NULL, NULL, 3.5);

SELECT DISTINCT a FROM t;
-- A: 1
-- A: 2
-- A: NULL

SELECT ALL a FROM t;
-- A: 1
-- A: 2
-- A: 1
-- A: NULL
-- A: NULL
-- A: 2
-- A: NULL

SELECT DISTINCT a, b FROM t;
-- A: 1 B: x
-- A: 2 B: y
-- A: NULL B: y
-- A: NULL B: NULL
-- A: 2 B: NULL

SELECT DISTINCT * FROM t;
-- A: 1 B: x C: 1.5e0
-- A: 2 B: y C: 2.5e0
-- A: 1 B: x C: 3.5e0
-- A: NULL B: y C: NULL
-- A: NULL B: NULL C: NULL
-- A: 2 B: NULL C: 1.5e0
-- A: NULL B: NULL C: 3.5e0

SELECT DISTINCT t.* FROM t;
-- A: 1 B: x C: 1.5e0
-- A: 2 B: y C: 2.5e0
-- A: 1 B: x C: 3.5e0
-- A: NULL B: y C: NULL
-- A: NULL B: NULL C: NULL
-- A: 2 B: NULL C: 1.5e0
-- A: NULL B: NULL C: 3.5e0

SELECT DISTINCT b FROM t ORDER BY b;
-- B: NULL
-- B: x
-- B: y

SELECT DISTINCT a, b FROM t ORDER BY b DESC, a;
-- A: NULL B: y
-- A: 2 B: y
-- A: 1 B: x
-- A: NULL B: NULL
-- A: 2 B: NULL

SELECT DISTINCT a FROM t ORDER BY a FETCH FIRST 2 ROWS ONLY;
-- A: NULL
-- A: 1

SELECT DISTINCT a FROM t ORDER BY a OFFSET 1 ROW;
-- A: 1
-- A: 2

SELECT DISTINCT a * 2 AS d FROM t ORDER BY a * 2;
-- D: NULL
-- D: 2
-- D: 4

SELECT DISTINCT a + 1 FROM t ORDER BY a;
-- error 42P10: column A must be in the select list to be used in ORDER BY with SELECT DISTINCT

SELECT DISTINCT t.a FROM t ORDER BY a;
-- A: NULL
-- A: 1
-- A: 2

SELECT DISTINCT a FROM t ORDER BY t.a DESC;
-- A: 2
-- A: 1
-- A: NULL

SELECT DISTINCT * FROM t ORDER BY c, a;
-- A: NULL B: y C: NULL
-- A: NULL B: NULL C: NULL
-- A: 1 B: x C: 1.5e0
-- A: 2 B: NULL C: 1.5e0
-- A: 2 B: y C: 2.5e0
-- A: NULL B: NULL C: 3.5e0
-- A: 1 B: x C: 3.5e0

SELECT DISTINCT t.* FROM t ORDER BY c DESC, a;
-- A: NULL B: NULL C: 3.5e0
-- A: 1 B: x C: 3.5e0
-- A: 2 B: y C: 2.5e0
-- A: 1 B: x C: 1.5e0
-- A: 2 B: NULL C: 1.5e0
-- A: NULL B: y C: NULL
-- A: NULL B: NULL C: NULL

SELECT DISTINCT a FROM t ORDER BY b;
-- error 42P10: column B must be in the select list to be used in ORDER BY with SELECT DISTINCT

SELECT DISTINCT a * 2 FROM t ORDER BY a;
-- error 42P10: column A must be in the select list to be used in ORDER BY with SELECT DISTINCT

SELECT DISTINCT a FROM t ORDER BY ABS(c);
-- error 42P10: column C must be in the select list to be used in ORDER BY with SELECT DISTINCT

SELECT DISTINCT a FROM t WHERE c > 2;
-- A: 2
-- A: 1
-- A: NULL

EXPLAIN SELECT DISTINCT a FROM t ORDER BY a;
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (A INTEGER, B CHARACTER VARYING(10), C DOUBLE PRECISION)
-- EXPLAIN: DISTINCT
-- EXPLAIN: ORDER BY A ASC
-- EXPLAIN: EXPR (A INTEGER)

SELECT DISTINCT a, COUNT(*) FROM t GROUP BY a;
-- A: NULL COL2: 3
-- A: 1 COL2: 2
-- A: 2 COL2: 2

SELECT DISTINCT COUNT(*) FROM t GROUP BY a;
-- COL1: 3
-- COL1: 2

SELECT DISTINCT COUNT(*) FROM t GROUP BY a ORDER BY COUNT(*);
-- COL1: 2
-- COL1: 3

SELECT DISTINCT COUNT(*) FROM t GROUP BY a ORDER BY a;
-- error 42P10: column A must be in the select list to be used in ORDER BY with SELECT DISTINCT

SELECT DISTINCT 1 FROM t;
-- COL1: 1

SELECT DISTINCT b = 'x' FROM t;
-- COL1: TRUE
-- COL1: FALSE
-- COL1: UNKNOWN

SELECT DISTINCT a FROM t WHERE a > 100;

SELECT * FROM (SELECT DISTINCT a FROM t) AS s;
-- A: 1
-- A: 2
-- A: NULL

SELECT COUNT(*) FROM (SELECT DISTINCT b FROM t) AS s;
-- COL1: 3

CREATE TABLE n (x NUMERIC(5, 2), y CHAR(3));
INSERT INTO n (x, y) VALUES (1.5, 'a');
INSERT INTO n (x, y) VALUES (1.50, 'a  ');
INSERT INTO n (x, y) VALUES (1.25, 'b');
SELECT DISTINCT x FROM n;
SELECT DISTINCT y FROM n;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- X: 1.50
-- X: 1.25
-- Y: a
-- Y: b

CREATE SEQUENCE s;
SELECT DISTINCT NEXT VALUE FOR s FROM t;
SELECT ALL NEXT VALUE FOR s FROM t FETCH FIRST 1 ROW ONLY;
-- msg: CREATE SEQUENCE 1
-- error 42601: syntax error: NEXT VALUE FOR cannot be used in SELECT DISTINCT
-- COL1: 1

SELECT DISTINCT DISTINCT a FROM t;
-- error 42601: syntax error: unexpected DISTINCT

CREATE TABLE u (a INT, d INT);
INSERT INTO u (a, d) VALUES (1, 10);
INSERT INTO u (a, d) VALUES (1, 20);
INSERT INTO u (a, d) VALUES (2, 10);
SELECT DISTINCT t.a, u.d FROM t JOIN u ON t.a = u.a ORDER BY u.d, t.a;
SELECT DISTINCT u.* FROM t JOIN u ON t.a = u.a ORDER BY d DESC, u.a;
SELECT DISTINCT u.* FROM t JOIN u ON t.a = u.a ORDER BY t.b;
SELECT DISTINCT d FROM t JOIN u ON t.a = u.a ORDER BY u.a;
SELECT DISTINCT d FROM t JOIN u ON t.a = u.a ORDER BY a;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- A: 1 D: 10
-- A: 2 D: 10
-- A: 1 D: 20
-- A: 1 D: 20
-- A: 1 D: 10
-- A: 2 D: 10
-- error 42P10: column T.B must be in the select list to be used in ORDER BY with SELECT DISTINCT
-- error 42P10: column U.A must be in the select list to be used in ORDER BY with SELECT DISTINCT
-- error 42702: ambiguous column: A

-- # Only a SELECT DISTINCT limits the ORDER BY.
VALUES 3, 1, 2 ORDER BY 1;
-- COL1: 3
-- COL1: 1
-- COL1: 2
