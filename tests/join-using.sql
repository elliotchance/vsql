-- # ISO/IEC 9075-2:2016(E), 7.10, <joined table>, Syntax Rules, 10
/* setup */
CREATE TABLE t (x INTEGER, a INTEGER);
CREATE TABLE u (x INTEGER, b INTEGER);
INSERT INTO t (x, a) VALUES (1, 10);
INSERT INTO t (x, a) VALUES (2, 20);
INSERT INTO t (x, a) VALUES (NULL, 30);
INSERT INTO u (x, b) VALUES (1, 100);
INSERT INTO u (x, b) VALUES (3, 300);
INSERT INTO u (x, b) VALUES (NULL, 400);
CREATE TABLE r (val INTEGER);
INSERT INTO r (val) VALUES (1);

-- # The common column is first, then the others of each side. A NULL doesn't
-- # match another NULL.
SELECT * FROM t JOIN u USING (x);
-- X: 1 A: 10 B: 100

SELECT * FROM t INNER JOIN u USING (x);
-- X: 1 A: 10 B: 100

SELECT * FROM t LEFT JOIN u USING (x) ORDER BY a;
-- X: 1 A: 10 B: 100
-- X: 2 A: 20 B: NULL
-- X: NULL A: 30 B: NULL

SELECT * FROM t LEFT OUTER JOIN u USING (x) WHERE b IS NULL ORDER BY a;
-- X: 2 A: 20 B: NULL
-- X: NULL A: 30 B: NULL

SELECT * FROM t RIGHT JOIN u USING (x) ORDER BY b;
-- X: 1 A: 10 B: 100
-- X: 3 A: NULL B: 300
-- X: NULL A: NULL B: 400

-- # An unqualified name is the common column, even from the side that's NULL.
SELECT x FROM t RIGHT JOIN u USING (x) WHERE x = 3;
-- X: 3

SELECT x FROM t LEFT JOIN u USING (x) WHERE x = 2;
-- X: 2

SELECT x AS y, x + 1 FROM t JOIN u USING (x);
-- Y: 1 COL2: 2

SELECT a FROM t JOIN u USING (x) ORDER BY x;
-- A: 10

SELECT x, COUNT(*) FROM t LEFT JOIN u USING (x) WHERE x IS NOT NULL GROUP BY x HAVING x > 1;
-- X: 2 COL2: 1

SELECT * FROM t JOIN u USING (x) GROUP BY x, a, b;
-- X: 1 A: 10 B: 100

SELECT DISTINCT x FROM t JOIN u USING (x);
-- X: 1

-- # A qualified name of a common column doesn't exist anymore, but the other
-- # columns of the table do.
SELECT t.x FROM t JOIN u USING (x);
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.T.X

SELECT u.x FROM t JOIN u USING (x);
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.U.X

SELECT * FROM t JOIN u USING (x) WHERE t.x = 1;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.T.X

SELECT * FROM t JOIN u USING (x) ORDER BY t.x;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.T.X

SELECT t.a, u.b FROM t JOIN u USING (x);
-- A: 10 B: 100

SELECT t.* FROM t JOIN u USING (x);
-- A: 10

SELECT u.*, x, t.* FROM t JOIN u USING (x);
-- B: 100 X: 1 A: 10

-- # Correlation names and derived tables.
SELECT * FROM t AS p JOIN t AS q USING (x, a);
-- X: 1 A: 10
-- X: 2 A: 20

SELECT p.a, q.b, x FROM t AS p JOIN u AS q USING (x);
-- A: 10 B: 100 X: 1

SELECT p.x FROM t AS p JOIN u AS q USING (x);
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.P.X

SELECT * FROM t AS p (c, d) JOIN u AS q (c, e) USING (c);
-- C: 1 D: 10 E: 100

SELECT * FROM (SELECT x, a FROM t) AS p JOIN u USING (x);
-- X: 1 A: 10 B: 100

SELECT * FROM (SELECT * FROM t JOIN u USING (x)) AS p;
-- X: 1 A: 10 B: 100

SELECT p.x FROM (SELECT * FROM t JOIN u USING (x)) AS p;
-- X: 1

-- # In a subquery, and from a subquery as an outer reference.
SELECT a FROM t WHERE x IN (SELECT x FROM t JOIN u USING (x));
-- A: 10

SELECT b FROM u WHERE EXISTS (SELECT * FROM t AS p JOIN t AS q USING (x, a) WHERE x = u.x);
-- B: 100

SELECT x, (SELECT COUNT(*) FROM r WHERE val = x) FROM t JOIN u USING (x);
-- X: 1 COL2: 1

SELECT (SELECT COUNT(*) FROM r WHERE val = t.x) FROM t JOIN u USING (x);
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.T.X

/* extensions V001-01 */
EXPLAIN SELECT * FROM t JOIN u USING (x);
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.T (X INTEGER, A INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.U (X INTEGER, B INTEGER)
-- EXPLAIN: INNER JOIN ON ":memory:".PUBLIC.T.X = ":memory:".PUBLIC.U.X ($USING2.X INTEGER NOT NULL, ":memory:".PUBLIC.T.A INTEGER, ":memory:".PUBLIC.U.B INTEGER)
-- EXPLAIN: EXPR ($USING2.X INTEGER NOT NULL, ":memory:".PUBLIC.T.A INTEGER, ":memory:".PUBLIC.U.B INTEGER)

/* extensions V001-01 */
EXPLAIN SELECT * FROM t WHERE EXISTS (SELECT * FROM u AS p JOIN u AS q USING (x, b));
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (X INTEGER, A INTEGER)
-- EXPLAIN: WHERE EXISTS (SELECT * FROM U AS P INNER JOIN U AS Q USING (X, B))
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.X INTEGER, ":memory:".PUBLIC.T.A INTEGER)

-- # ISO/IEC 9075-2:2016(E), 7.10, <joined table>, Syntax Rules, 10.c
SELECT * FROM t JOIN u USING (nope);
-- error 42703: no such column: NOPE

SELECT * FROM t JOIN u USING (a);
-- error 42703: no such column: A

SELECT * FROM t JOIN u USING (b);
-- error 42703: no such column: B

SELECT * FROM t JOIN u USING (x, x);
-- error 42601: syntax error: column X is specified more than once

SELECT * FROM t JOIN u USING ();
-- error 42601: syntax error: unexpected ")"

SELECT * FROM t JOIN u USING x;
-- error 42601: syntax error: unexpected identifier, expecting "("

SELECT * FROM (SELECT x, x FROM t) AS p JOIN u USING (x);
-- error 42702: ambiguous column: X

SELECT * FROM t JOIN (SELECT x, x FROM u) AS q USING (x);
-- error 42702: ambiguous column: X

/* setup */
CREATE TABLE v (x INTEGER, y INTEGER, c INTEGER);
CREATE TABLE w (y INTEGER, x INTEGER, d INTEGER);
CREATE TABLE z (x INTEGER, e INTEGER);
INSERT INTO v (x, y, c) VALUES (1, 2, 3);
INSERT INTO v (x, y, c) VALUES (1, 5, 6);
INSERT INTO v (x, y, c) VALUES (7, 8, 9);
INSERT INTO w (y, x, d) VALUES (2, 1, 4);
INSERT INTO w (y, x, d) VALUES (8, 0, 5);
INSERT INTO z (x, e) VALUES (1, 11);
INSERT INTO z (x, e) VALUES (0, 12);

-- # The common columns are in the order of the left side, not of the list. All
-- # of them must be equal.
SELECT * FROM v JOIN w USING (y, x);
-- X: 1 Y: 2 C: 3 D: 4

SELECT * FROM w JOIN v USING (x, y);
-- Y: 2 X: 1 D: 4 C: 3

SELECT * FROM v LEFT JOIN w USING (x, y) ORDER BY c;
-- X: 1 Y: 2 C: 3 D: 4
-- X: 1 Y: 5 C: 6 D: NULL
-- X: 7 Y: 8 C: 9 D: NULL

-- # A column that's on both sides but not in the list isn't a common column.
SELECT * FROM v JOIN w USING (y) ORDER BY c;
-- Y: 2 X: 1 C: 3 X: 1 D: 4
-- Y: 8 X: 7 C: 9 X: 0 D: 5

SELECT x FROM v JOIN w USING (y);
-- error 42702: ambiguous column: X

SELECT v.x, w.x FROM v JOIN w USING (y) ORDER BY c;
-- X: 1 X: 1
-- X: 7 X: 0

-- # Chained joins use the common column of the join before.
SELECT * FROM v JOIN w USING (x, y) JOIN z USING (x);
-- X: 1 Y: 2 C: 3 D: 4 E: 11

SELECT * FROM t JOIN u USING (x) JOIN z USING (x);
-- X: 1 A: 10 B: 100 E: 11

SELECT * FROM t LEFT JOIN u USING (x) RIGHT JOIN z USING (x) ORDER BY x;
-- X: 0 A: NULL B: NULL E: 12
-- X: 1 A: 10 B: 100 E: 11

SELECT x FROM t RIGHT JOIN u USING (x) LEFT JOIN z USING (x) WHERE b = 300;
-- X: 3

SELECT * FROM t JOIN u USING (x) JOIN z ON b = 100 AND e = 11;
-- X: 1 A: 10 B: 100 X: 1 E: 11

SELECT * FROM t JOIN u USING (x) JOIN r ON x = val;
-- X: 1 A: 10 B: 100 VAL: 1

SELECT * FROM t JOIN u USING (x) JOIN z ON x = z.x;
-- error 42702: ambiguous column: X

SELECT * FROM t JOIN u USING (x) JOIN z ON t.x = z.x;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.T.X

SELECT * FROM t JOIN u ON t.x = u.x JOIN z USING (x);
-- error 42702: ambiguous column: X

SELECT * FROM t JOIN u USING (x) JOIN v ON TRUE JOIN z USING (e);
-- error 42703: no such column: E

SELECT * FROM z JOIN (t JOIN u USING (x)) USING (x);
-- X: 1 E: 11 A: 10 B: 100

SELECT * FROM t JOIN (u LEFT JOIN z USING (x)) USING (x);
-- X: 1 A: 10 B: 100 E: 11

SELECT e, b, x FROM z LEFT JOIN (t JOIN u USING (x)) ON e = 12 ORDER BY e;
-- error 42702: ambiguous column: X

SELECT e, b FROM z LEFT JOIN (t JOIN u USING (x)) ON e = 12 ORDER BY e;
-- E: 11 B: NULL
-- E: 12 B: 100

-- # The columns in the middle of a join are in their own place.
SELECT * FROM z JOIN (t JOIN u USING (x)) ON TRUE WHERE e = 11;
-- X: 1 E: 11 X: 1 A: 10 B: 100

-- # The tables of a USING join with nothing else leave only the common column.
/* setup */
CREATE TABLE only1 (k INTEGER);
CREATE TABLE only2 (k INTEGER);
INSERT INTO only1 (k) VALUES (1);
INSERT INTO only1 (k) VALUES (2);
INSERT INTO only2 (k) VALUES (2);

SELECT * FROM only1 JOIN only2 USING (k);
-- K: 2

SELECT * FROM only1 LEFT JOIN only2 USING (k) ORDER BY k;
-- K: 1
-- K: 2

SELECT only2.* FROM only1 LEFT JOIN only2 USING (k);
-- error 42601: syntax error: the select list has no columns

-- # ISO/IEC 9075-2:2016(E), 7.10, <joined table>, Syntax Rules, 10.e and 10.j
/* setup */
CREATE TABLE types1 (n INTEGER, s VARCHAR(10), f INTEGER, c CHARACTER(5), m SMALLINT);
CREATE TABLE types2 (n VARCHAR(10), s INTEGER, f BIGINT, c VARCHAR(10), m DOUBLE PRECISION);
INSERT INTO types1 (n, s, f, c, m) VALUES (1, 'a', 1, 'abc', 2);
INSERT INTO types2 (n, s, f, c, m) VALUES ('1', 1, 1, 'abc', 2.5e0);
INSERT INTO types2 (n, s, f, c, m) VALUES ('1', 1, 5000000000, 'abc', 2e0);

SELECT * FROM types1 JOIN types2 USING (n);
-- error 42804: data type mismatch in USING column N: expected INTEGER but got CHARACTER VARYING(10)

SELECT * FROM types1 JOIN types2 USING (s);
-- error 42804: data type mismatch in USING column S: expected CHARACTER VARYING(10) but got INTEGER

SELECT f FROM types1 RIGHT JOIN types2 USING (f) ORDER BY f;
-- F: 1
-- F: 5000000000

SELECT c FROM types1 JOIN types2 USING (c);
-- C: abc
-- C: abc

SELECT m FROM types1 JOIN types2 USING (m);
-- M: 2e0

SELECT f FROM types1 JOIN types2 USING (f) WHERE f = 1 OR f > 100;
-- F: 1

SELECT CAST(f AS BIGINT) FROM types1 RIGHT JOIN types2 USING (f) WHERE f > 100;
-- COL1: 5000000000

-- # ISO/IEC 9075-2:2016(E), 7.10, <joined table>, Syntax Rules, 15.c
/* setup */
CREATE TABLE nn1 (k INTEGER NOT NULL, c INTEGER NOT NULL);
CREATE TABLE nn2 (k INTEGER NOT NULL, c INTEGER NOT NULL);
CREATE TABLE nn3 (k INTEGER NOT NULL);
CREATE TABLE nu (k INTEGER, d INTEGER);

/* extensions V001-01 */
EXPLAIN SELECT nu.d FROM nu JOIN nn1 USING (k);
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.NU (K INTEGER, D INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.NN1 (K INTEGER NOT NULL, C INTEGER NOT NULL)
-- EXPLAIN: INNER JOIN ON ":memory:".PUBLIC.NU.K = ":memory:".PUBLIC.NN1.K ($USING2.K INTEGER NOT NULL, ":memory:".PUBLIC.NU.D INTEGER, ":memory:".PUBLIC.NN1.C INTEGER NOT NULL)
-- EXPLAIN: EXPR (D INTEGER)

/* extensions V001-01 */
EXPLAIN SELECT nu.d FROM nu LEFT JOIN nn1 USING (k);
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.NU (K INTEGER, D INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.NN1 (K INTEGER NOT NULL, C INTEGER NOT NULL)
-- EXPLAIN: LEFT JOIN ON ":memory:".PUBLIC.NU.K = ":memory:".PUBLIC.NN1.K ($USING2.K INTEGER, ":memory:".PUBLIC.NU.D INTEGER, ":memory:".PUBLIC.NN1.C INTEGER)
-- EXPLAIN: EXPR (D INTEGER)

/* extensions V001-01 */
EXPLAIN SELECT nu.d FROM nn1 LEFT JOIN nu USING (k);
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.NN1 (K INTEGER NOT NULL, C INTEGER NOT NULL)
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.NU (K INTEGER, D INTEGER)
-- EXPLAIN: LEFT JOIN ON ":memory:".PUBLIC.NN1.K = ":memory:".PUBLIC.NU.K ($USING2.K INTEGER NOT NULL, ":memory:".PUBLIC.NN1.C INTEGER NOT NULL, ":memory:".PUBLIC.NU.D INTEGER)
-- EXPLAIN: EXPR (D INTEGER)

/* extensions V001-01 */
EXPLAIN SELECT nu.d FROM nu RIGHT JOIN nn1 USING (k);
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.NU (K INTEGER, D INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.NN1 (K INTEGER NOT NULL, C INTEGER NOT NULL)
-- EXPLAIN: RIGHT JOIN ON ":memory:".PUBLIC.NU.K = ":memory:".PUBLIC.NN1.K ($USING2.K INTEGER NOT NULL, ":memory:".PUBLIC.NU.D INTEGER, ":memory:".PUBLIC.NN1.C INTEGER NOT NULL)
-- EXPLAIN: EXPR (D INTEGER)

/* extensions V001-01 */
EXPLAIN SELECT nu.d FROM nn1 RIGHT JOIN nu USING (k);
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.NN1 (K INTEGER NOT NULL, C INTEGER NOT NULL)
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.NU (K INTEGER, D INTEGER)
-- EXPLAIN: RIGHT JOIN ON ":memory:".PUBLIC.NN1.K = ":memory:".PUBLIC.NU.K ($USING2.K INTEGER, ":memory:".PUBLIC.NN1.C INTEGER, ":memory:".PUBLIC.NU.D INTEGER)
-- EXPLAIN: EXPR (D INTEGER)

-- # The left side of a USING can already be NULL because of the join before.
/* extensions V001-01 */
EXPLAIN SELECT nu.d FROM nu LEFT JOIN nn1 ON nu.k = nn1.k LEFT JOIN nn3 ON nn1.k = nn3.k;
-- EXPLAIN: $1:
-- EXPLAIN:   $1:
-- EXPLAIN:     TABLE ":memory:".PUBLIC.NU (K INTEGER, D INTEGER)
-- EXPLAIN:   $2:
-- EXPLAIN:     TABLE ":memory:".PUBLIC.NN1 (K INTEGER NOT NULL, C INTEGER NOT NULL)
-- EXPLAIN:   LEFT JOIN ON NU.K = NN1.K (":memory:".PUBLIC.NU.K INTEGER, ":memory:".PUBLIC.NU.D INTEGER, ":memory:".PUBLIC.NN1.K INTEGER, ":memory:".PUBLIC.NN1.C INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.NN3 (K INTEGER NOT NULL)
-- EXPLAIN: LEFT JOIN ON NN1.K = NN3.K (":memory:".PUBLIC.NU.K INTEGER, ":memory:".PUBLIC.NU.D INTEGER, ":memory:".PUBLIC.NN1.K INTEGER, ":memory:".PUBLIC.NN1.C INTEGER, ":memory:".PUBLIC.NN3.K INTEGER)
-- EXPLAIN: EXPR (D INTEGER)

/* extensions V001-01 */
EXPLAIN SELECT nu.d FROM nu LEFT JOIN nn1 ON nu.k = nn1.k LEFT JOIN nn2 USING (c);
-- EXPLAIN: $1:
-- EXPLAIN:   $1:
-- EXPLAIN:     TABLE ":memory:".PUBLIC.NU (K INTEGER, D INTEGER)
-- EXPLAIN:   $2:
-- EXPLAIN:     TABLE ":memory:".PUBLIC.NN1 (K INTEGER NOT NULL, C INTEGER NOT NULL)
-- EXPLAIN:   LEFT JOIN ON NU.K = NN1.K (":memory:".PUBLIC.NU.K INTEGER, ":memory:".PUBLIC.NU.D INTEGER, ":memory:".PUBLIC.NN1.K INTEGER, ":memory:".PUBLIC.NN1.C INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.NN2 (K INTEGER NOT NULL, C INTEGER NOT NULL)
-- EXPLAIN: LEFT JOIN ON ":memory:".PUBLIC.NN1.C = ":memory:".PUBLIC.NN2.C ($USING3.C INTEGER, ":memory:".PUBLIC.NU.K INTEGER, ":memory:".PUBLIC.NU.D INTEGER, ":memory:".PUBLIC.NN1.K INTEGER, ":memory:".PUBLIC.NN2.K INTEGER)
-- EXPLAIN: EXPR (D INTEGER)
