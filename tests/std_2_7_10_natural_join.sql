-- # ISO/IEC 9075-2:2023, 7.10, <joined table>, Syntax Rules, 10.b
/* setup */
CREATE TABLE t (x INTEGER, a INTEGER);
CREATE TABLE u (b INTEGER, x INTEGER);
INSERT INTO t (x, a) VALUES (1, 10);
INSERT INTO t (x, a) VALUES (2, 20);
INSERT INTO t (x, a) VALUES (NULL, 30);
INSERT INTO u (b, x) VALUES (100, 1);
INSERT INTO u (b, x) VALUES (300, 3);
INSERT INTO u (b, x) VALUES (400, NULL);

/* define v */
CREATE TABLE v (y INTEGER, x INTEGER, c INTEGER);
CREATE TABLE w (x INTEGER, d INTEGER, y INTEGER);
INSERT INTO v (y, x, c) VALUES (2, 1, 3);
INSERT INTO v (y, x, c) VALUES (5, 1, 6);
INSERT INTO v (y, x, c) VALUES (8, 7, 9);
INSERT INTO w (x, d, y) VALUES (1, 4, 2);
INSERT INTO w (x, d, y) VALUES (7, 5, 0);

/* define p */
CREATE TABLE p (k INTEGER);
CREATE TABLE q (m INTEGER);
INSERT INTO p (k) VALUES (1);
INSERT INTO p (k) VALUES (2);
INSERT INTO q (m) VALUES (5);

/* define nn */
CREATE TABLE n1 (k INTEGER NOT NULL, s VARCHAR(10));
CREATE TABLE n2 (k INTEGER NOT NULL, s INTEGER);

-- # The columns with the same name on both sides are joined on equality, like
-- # USING. The common column is first and only once, then the others of each
-- # side. A NULL doesn't match another NULL.
/* flags */
SELECT * FROM t NATURAL JOIN u;
-- flags: F405
-- X: 1 A: 10 B: 100

SELECT * FROM t NATURAL INNER JOIN u;
-- X: 1 A: 10 B: 100

SELECT * FROM t JOIN u USING (x);
-- X: 1 A: 10 B: 100

-- # An outer join keeps the rows that don't match. The common column is the
-- # value from whichever side isn't NULL.
SELECT * FROM t NATURAL LEFT JOIN u ORDER BY a;
-- X: 1 A: 10 B: 100
-- X: 2 A: 20 B: NULL
-- X: NULL A: 30 B: NULL

SELECT * FROM t NATURAL LEFT OUTER JOIN u ORDER BY a;
-- X: 1 A: 10 B: 100
-- X: 2 A: 20 B: NULL
-- X: NULL A: 30 B: NULL

SELECT * FROM t NATURAL RIGHT JOIN u ORDER BY b;
-- X: 1 A: 10 B: 100
-- X: 3 A: NULL B: 300
-- X: NULL A: NULL B: 400

SELECT * FROM t NATURAL RIGHT OUTER JOIN u ORDER BY b;
-- X: 1 A: 10 B: 100
-- X: 3 A: NULL B: 300
-- X: NULL A: NULL B: 400

-- # Every common column is joined on, in the order of the left side.
/* include v */
SELECT * FROM v NATURAL JOIN w;
-- Y: 2 X: 1 C: 3 D: 4

/* include v */
SELECT * FROM w NATURAL JOIN v;
-- X: 1 Y: 2 D: 4 C: 3

-- # A common column can only be referenced without a table name.
/* include v */
SELECT x, y, v.c, w.d FROM v NATURAL JOIN w;
-- X: 1 Y: 2 C: 3 D: 4

/* include v */
SELECT v.x FROM v NATURAL JOIN w;
-- error 42703: no such column: ":memory:".PUBLIC.V.X

/* include v */
SELECT v.* FROM v NATURAL JOIN w;
-- C: 3

-- # Without any common columns, every pair of rows is joined, like a CROSS
-- # JOIN.
/* include p */
SELECT * FROM p NATURAL JOIN q ORDER BY k;
-- K: 1 M: 5
-- K: 2 M: 5

/* include p */
SELECT * FROM p NATURAL LEFT JOIN q WHERE FALSE;

-- # When all columns are common, there's only the common columns.
/* include p */
SELECT * FROM p NATURAL JOIN p AS p2 ORDER BY k;
-- K: 1
-- K: 2

-- # Joins are from left to right. A later NATURAL join uses the columns of the
-- # join before it, including its common columns.
/* include v */
SELECT * FROM t NATURAL JOIN u NATURAL JOIN v ORDER BY y;
-- X: 1 A: 10 B: 100 Y: 2 C: 3
-- X: 1 A: 10 B: 100 Y: 5 C: 6

/* include v */
SELECT * FROM v NATURAL JOIN (t NATURAL JOIN u) ORDER BY y;
-- X: 1 Y: 2 C: 3 A: 10 B: 100
-- X: 1 Y: 5 C: 6 A: 10 B: 100

/* include v */
SELECT * FROM v NATURAL JOIN ((t NATURAL JOIN u)) WHERE y = 5;
-- X: 1 Y: 5 C: 6 A: 10 B: 100

SELECT * FROM t NATURAL JOIN (SELECT x, b * 2 AS b2 FROM u) AS d;
-- X: 1 A: 10 B2: 200

SELECT * FROM t NATURAL JOIN (VALUES (1, 'one'), (2, 'two')) AS d (x, name) ORDER BY x;
-- X: 1 A: 10 NAME: one
-- X: 2 A: 20 NAME: two

-- # A column name that's on both sides must be the name of only one column on
-- # each side.
SELECT * FROM (t JOIN u ON TRUE) NATURAL JOIN t AS t2;
-- error 42702: ambiguous column: X

SELECT * FROM t AS t2 NATURAL JOIN (t JOIN u ON TRUE);
-- error 42702: ambiguous column: X

-- # A name that's more than once on one side but not on the other isn't a
-- # common column.
/* include p */
SELECT k, t.x, u.x AS x2 FROM (t JOIN u ON t.x = u.x) NATURAL JOIN p;
-- K: 1 X: 1 X2: 1
-- K: 2 X: 1 X2: 1

-- # The common columns must be comparable.
/* include nn */
SELECT * FROM n1 NATURAL JOIN n2;
-- error 42804: data type mismatch in USING column S: expected CHARACTER VARYING(10) but got INTEGER

-- # A common column of an inner join is known not null. It's whatever the
-- # preserved side's column is in an outer join.
/* include nn */
/* extensions V001-01 */
EXPLAIN SELECT * FROM n1 NATURAL JOIN (SELECT k FROM n2) AS d;
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.N1 (K INTEGER NOT NULL, S CHARACTER VARYING(10))
-- EXPLAIN: $2:
-- EXPLAIN:   D:
-- EXPLAIN:     TABLE ":memory:".PUBLIC.N2 (K INTEGER NOT NULL, S INTEGER)
-- EXPLAIN:     EXPR (K INTEGER NOT NULL)
-- EXPLAIN:   TABLE D (K INTEGER NOT NULL)
-- EXPLAIN: INNER JOIN ON ":memory:".PUBLIC.N1.K = D.K ($USING2.K INTEGER NOT NULL, ":memory:".PUBLIC.N1.S CHARACTER VARYING(10))
-- EXPLAIN: EXPR ($USING2.K INTEGER NOT NULL, ":memory:".PUBLIC.N1.S CHARACTER VARYING(10))

/* include nn */
/* extensions V001-01 */
EXPLAIN SELECT * FROM (SELECT CAST(k AS INTEGER) AS k FROM n2) AS d NATURAL LEFT JOIN n1;
-- EXPLAIN: $1:
-- EXPLAIN:   D:
-- EXPLAIN:     TABLE ":memory:".PUBLIC.N2 (K INTEGER NOT NULL, S INTEGER)
-- EXPLAIN:     EXPR (K INTEGER)
-- EXPLAIN:   TABLE D (K INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.N1 (K INTEGER NOT NULL, S CHARACTER VARYING(10))
-- EXPLAIN: LEFT JOIN ON D.K = ":memory:".PUBLIC.N1.K ($USING2.K INTEGER, ":memory:".PUBLIC.N1.S CHARACTER VARYING(10))
-- EXPLAIN: EXPR ($USING2.K INTEGER, ":memory:".PUBLIC.N1.S CHARACTER VARYING(10))

/* include nn */
/* extensions V001-01 */
EXPLAIN SELECT * FROM n1 NATURAL LEFT JOIN (SELECT CAST(k AS INTEGER) AS k FROM n2) AS d;
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.N1 (K INTEGER NOT NULL, S CHARACTER VARYING(10))
-- EXPLAIN: $2:
-- EXPLAIN:   D:
-- EXPLAIN:     TABLE ":memory:".PUBLIC.N2 (K INTEGER NOT NULL, S INTEGER)
-- EXPLAIN:     EXPR (K INTEGER)
-- EXPLAIN:   TABLE D (K INTEGER)
-- EXPLAIN: LEFT JOIN ON ":memory:".PUBLIC.N1.K = D.K ($USING2.K INTEGER NOT NULL, ":memory:".PUBLIC.N1.S CHARACTER VARYING(10))
-- EXPLAIN: EXPR ($USING2.K INTEGER NOT NULL, ":memory:".PUBLIC.N1.S CHARACTER VARYING(10))

-- # The same table can't be used twice without a correlation name.
SELECT * FROM t NATURAL JOIN t;
-- error 42601: syntax error: table name ":memory:".PUBLIC.T specified more than once

-- # NATURAL has no ON or USING.
SELECT * FROM t NATURAL JOIN u ON TRUE;
-- error 42601: syntax error: unexpected ON at line 1, column 32 near "NATURAL JOIN u ON TRUE"

SELECT * FROM t NATURAL JOIN u USING (x);
-- error 42601: syntax error: unexpected USING at line 1, column 32 near "NATURAL JOIN u USING ("; hint: USING is a reserved word, so it must be quoted to be used as a name, such as "USING" (see https://vsql.readthedocs.io/en/latest/keywords.html)

-- # A NATURAL join in a subquery.
/* include p */
/* extensions V001-01 */
EXPLAIN SELECT * FROM t WHERE EXISTS (SELECT * FROM p NATURAL LEFT JOIN q);
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (X INTEGER, A INTEGER)
-- EXPLAIN: WHERE EXISTS (SELECT * FROM P NATURAL LEFT JOIN Q)
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.X INTEGER, ":memory:".PUBLIC.T.A INTEGER)
