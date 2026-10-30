/* setup */
CREATE TABLE PUBLIC.t1 (x INT, y VARCHAR(16));
INSERT INTO t1 (x, y) VALUES (123, 'hello');
INSERT INTO t1 (x, y) VALUES (456, 'world');

-- # A subquery in FROM (a derived table) must have a correlation name (7.6
-- # <table primary>).
SELECT * FROM (SELECT * FROM t1);
SELECT * FROM (VALUES 1);
SELECT * FROM t1 JOIN (SELECT x FROM t1) ON TRUE;
-- error 42601: syntax error: a subquery in FROM must have a correlation name, such as (SELECT ...) AS t
-- error 42601: syntax error: a subquery in FROM must have a correlation name, such as (SELECT ...) AS t
-- error 42601: syntax error: a subquery in FROM must have a correlation name, such as (SELECT ...) AS t

/* extensions V001-01 */
EXPLAIN SELECT * FROM (SELECT * FROM t1) AS s;
-- EXPLAIN: S:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.T1 (X INTEGER, Y CHARACTER VARYING(16))
-- EXPLAIN:   EXPR (":memory:".PUBLIC.T1.X INTEGER, ":memory:".PUBLIC.T1.Y CHARACTER VARYING(16))
-- EXPLAIN: TABLE S (X INTEGER, Y CHARACTER VARYING(16))
-- EXPLAIN: EXPR (S.X INTEGER, S.Y CHARACTER VARYING(16))

/* extensions V001-01 */
EXPLAIN SELECT * FROM (SELECT x FROM t1) AS s;
-- EXPLAIN: S:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.T1 (X INTEGER, Y CHARACTER VARYING(16))
-- EXPLAIN:   EXPR (X INTEGER)
-- EXPLAIN: TABLE S (X INTEGER)
-- EXPLAIN: EXPR (S.X INTEGER)

/* extensions V001-01 */
EXPLAIN SELECT x FROM (SELECT x FROM t1) AS s;
-- EXPLAIN: S:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.T1 (X INTEGER, Y CHARACTER VARYING(16))
-- EXPLAIN:   EXPR (X INTEGER)
-- EXPLAIN: TABLE S (X INTEGER)
-- EXPLAIN: EXPR (X INTEGER)

SELECT x FROM (SELECT x FROM t1) AS s;
-- X: 123
-- X: 456

SELECT * FROM (SELECT x FROM t1) AS s;
-- X: 123
-- X: 456

/* extensions V001-01 */
EXPLAIN SELECT x, y FROM (SELECT x, y FROM t1) AS s;
-- EXPLAIN: S:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.T1 (X INTEGER, Y CHARACTER VARYING(16))
-- EXPLAIN:   EXPR (X INTEGER, Y CHARACTER VARYING(16))
-- EXPLAIN: TABLE S (X INTEGER, Y CHARACTER VARYING(16))
-- EXPLAIN: EXPR (X INTEGER, Y CHARACTER VARYING(16))

SELECT x, y FROM (SELECT x, y FROM t1) AS s;
-- X: 123 Y: hello
-- X: 456 Y: world

/* extensions V001-01 */
EXPLAIN SELECT y FROM (SELECT x, y FROM t1) AS s;
-- EXPLAIN: S:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.T1 (X INTEGER, Y CHARACTER VARYING(16))
-- EXPLAIN:   EXPR (X INTEGER, Y CHARACTER VARYING(16))
-- EXPLAIN: TABLE S (X INTEGER, Y CHARACTER VARYING(16))
-- EXPLAIN: EXPR (Y CHARACTER VARYING(16))

SELECT y FROM (SELECT x, y FROM t1) AS s;
-- Y: hello
-- Y: world

SELECT x FROM (SELECT x FROM t1) AS s ORDER BY x DESC;
-- X: 456
-- X: 123

SELECT t.y, COUNT(*) FROM (SELECT y FROM t1) AS t GROUP BY t.y;
-- Y: hello COL2: 1
-- Y: world COL2: 1

/* extensions V001-01 */
EXPLAIN SELECT * FROM (SELECT x + char_length(y) FROM t1) AS s;
-- EXPLAIN: S:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.T1 (X INTEGER, Y CHARACTER VARYING(16))
-- EXPLAIN:   EXPR (COL1 INTEGER)
-- EXPLAIN: TABLE S (COL1 INTEGER)
-- EXPLAIN: EXPR (S.COL1 INTEGER)

SELECT * FROM (SELECT x + char_length(y) FROM t1) AS s;
-- COL1: 128
-- COL1: 461

/* extensions V001-01 */
EXPLAIN SELECT * FROM (SELECT x + char_length(y) AS foo FROM t1) AS s;
-- EXPLAIN: S:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.T1 (X INTEGER, Y CHARACTER VARYING(16))
-- EXPLAIN:   EXPR (FOO INTEGER)
-- EXPLAIN: TABLE S (FOO INTEGER)
-- EXPLAIN: EXPR (S.FOO INTEGER)

SELECT * FROM (SELECT x + char_length(y) AS foo FROM t1) AS s;
-- FOO: 128
-- FOO: 461

/* extensions V001-01 */
EXPLAIN SELECT foo AS bar FROM (SELECT x + char_length(y) AS foo FROM t1) AS s;
-- EXPLAIN: S:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.T1 (X INTEGER, Y CHARACTER VARYING(16))
-- EXPLAIN:   EXPR (FOO INTEGER)
-- EXPLAIN: TABLE S (FOO INTEGER)
-- EXPLAIN: EXPR (BAR INTEGER)

SELECT foo AS bar FROM (SELECT x + char_length(y) AS foo FROM t1) AS s;
-- BAR: 128
-- BAR: 461

CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
INSERT INTO t (x) VALUES (2);
SELECT * FROM (SELECT x FROM t) AS s WHERE x > 5;
SELECT * FROM (SELECT x FROM t) AS s WHERE 1 = 0;
SELECT * FROM (SELECT x FROM t) AS s WHERE x = 2;
SELECT * FROM (SELECT x FROM t) AS s WHERE s.x = 1;
SELECT x * 10 AS y FROM (SELECT x FROM t) AS s WHERE x > 1;
SELECT COUNT(*) FROM (SELECT x FROM t) AS s WHERE x > 1;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- X: 2
-- X: 1
-- Y: 20
-- COL1: 1

SELECT * FROM (VALUES 1, 2, 3) AS v (n) WHERE n >= 2;
-- N: 2
-- N: 3

CREATE TABLE t (a INT, b INT);
INSERT INTO t (a, b) VALUES (1, 2);
SELECT * FROM (SELECT a, b FROM t) AS x (c, d);
SELECT x.d, c FROM (SELECT * FROM t) AS x (c, d) WHERE d = 2;
SELECT * FROM (SELECT a + 1, b FROM t) AS x (c, d);
SELECT * FROM (SELECT a FROM t) AS x (c, d);
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- C: 1 D: 2
-- D: 2 C: 1
-- C: 2 D: 2
-- error 42601: syntax error: ROW provides the wrong number of columns for the correlation

/* extensions V001-01 */
CREATE TABLE t (a INT, b INT);
EXPLAIN SELECT * FROM (SELECT a, b FROM t) AS x (c, d);
-- msg: CREATE TABLE 1
-- EXPLAIN: X:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.T (A INTEGER, B INTEGER)
-- EXPLAIN:   EXPR (A INTEGER, B INTEGER)
-- EXPLAIN: TABLE X (C INTEGER, D INTEGER)
-- EXPLAIN: EXPR (X.C INTEGER, X.D INTEGER)
