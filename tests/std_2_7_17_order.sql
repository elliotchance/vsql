/* setup */
CREATE TABLE foo (x FLOAT, y VARCHAR(32));
INSERT INTO foo (x, y) VALUES (1.234, 'hi');
INSERT INTO foo (x, y) VALUES (12.34, 'there');
INSERT INTO foo (x, y) VALUES (0.1234, 'hi');
INSERT INTO foo (x, y) VALUES (5.6, 'bar');

/* extensions V001-01 */
EXPLAIN SELECT * FROM foo ORDER BY x;
-- EXPLAIN: TABLE ":memory:".PUBLIC.FOO (X DOUBLE PRECISION, Y CHARACTER VARYING(32))
-- EXPLAIN: ORDER BY X ASC
-- EXPLAIN: EXPR (":memory:".PUBLIC.FOO.X DOUBLE PRECISION, ":memory:".PUBLIC.FOO.Y CHARACTER VARYING(32))

SELECT * FROM foo ORDER BY x;
-- X: 0.1234e0 Y: hi
-- X: 1.234e0 Y: hi
-- X: 5.6e0 Y: bar
-- X: 12.34e0 Y: there

/* extensions V001-01 */
EXPLAIN SELECT * FROM foo ORDER BY x ASC;
-- EXPLAIN: TABLE ":memory:".PUBLIC.FOO (X DOUBLE PRECISION, Y CHARACTER VARYING(32))
-- EXPLAIN: ORDER BY X ASC
-- EXPLAIN: EXPR (":memory:".PUBLIC.FOO.X DOUBLE PRECISION, ":memory:".PUBLIC.FOO.Y CHARACTER VARYING(32))

/* extensions V001-01 */
EXPLAIN SELECT * FROM foo ORDER BY x DESC;
-- EXPLAIN: TABLE ":memory:".PUBLIC.FOO (X DOUBLE PRECISION, Y CHARACTER VARYING(32))
-- EXPLAIN: ORDER BY X DESC
-- EXPLAIN: EXPR (":memory:".PUBLIC.FOO.X DOUBLE PRECISION, ":memory:".PUBLIC.FOO.Y CHARACTER VARYING(32))

SELECT * FROM foo ORDER BY x DESC;
-- X: 12.34e0 Y: there
-- X: 5.6e0 Y: bar
-- X: 1.234e0 Y: hi
-- X: 0.1234e0 Y: hi

SELECT * FROM foo ORDER BY y;
-- X: 5.6e0 Y: bar
-- X: 1.234e0 Y: hi
-- X: 0.1234e0 Y: hi
-- X: 12.34e0 Y: there

/* extensions V001-01 */
EXPLAIN SELECT * FROM foo ORDER BY y, x;
-- EXPLAIN: TABLE ":memory:".PUBLIC.FOO (X DOUBLE PRECISION, Y CHARACTER VARYING(32))
-- EXPLAIN: ORDER BY Y ASC, X ASC
-- EXPLAIN: EXPR (":memory:".PUBLIC.FOO.X DOUBLE PRECISION, ":memory:".PUBLIC.FOO.Y CHARACTER VARYING(32))

SELECT * FROM foo ORDER BY y, x;
-- X: 5.6e0 Y: bar
-- X: 0.1234e0 Y: hi
-- X: 1.234e0 Y: hi
-- X: 12.34e0 Y: there

SELECT * FROM foo ORDER BY y, x DESC;
-- X: 5.6e0 Y: bar
-- X: 1.234e0 Y: hi
-- X: 0.1234e0 Y: hi
-- X: 12.34e0 Y: there

SELECT * FROM foo ORDER BY x DESC, y;
-- X: 12.34e0 Y: there
-- X: 5.6e0 Y: bar
-- X: 1.234e0 Y: hi
-- X: 0.1234e0 Y: hi

/* extensions V001-01 */
EXPLAIN SELECT * FROM foo ORDER BY ABS(10 - x);
-- EXPLAIN: TABLE ":memory:".PUBLIC.FOO (X DOUBLE PRECISION, Y CHARACTER VARYING(32))
-- EXPLAIN: ORDER BY ABS(10 - X) ASC
-- EXPLAIN: EXPR (":memory:".PUBLIC.FOO.X DOUBLE PRECISION, ":memory:".PUBLIC.FOO.Y CHARACTER VARYING(32))

SELECT * FROM foo ORDER BY ABS(10e0 - x);
-- X: 12.34e0 Y: there
-- X: 5.6e0 Y: bar
-- X: 1.234e0 Y: hi
-- X: 0.1234e0 Y: hi

SELECT * FROM foo ORDER BY ABS(10e0 - x) DESC;
-- X: 0.1234e0 Y: hi
-- X: 1.234e0 Y: hi
-- X: 5.6e0 Y: bar
-- X: 12.34e0 Y: there

SELECT * FROM foo
ORDER BY y, x
OFFSET 0 ROWS;
-- X: 5.6e0 Y: bar
-- X: 0.1234e0 Y: hi
-- X: 1.234e0 Y: hi
-- X: 12.34e0 Y: there

/* extensions V001-01 */
EXPLAIN SELECT * FROM foo
ORDER BY y, x
OFFSET 2 ROW;
-- EXPLAIN: TABLE ":memory:".PUBLIC.FOO (X DOUBLE PRECISION, Y CHARACTER VARYING(32))
-- EXPLAIN: ORDER BY Y ASC, X ASC
-- EXPLAIN: OFFSET 2 ROWS
-- EXPLAIN: EXPR (":memory:".PUBLIC.FOO.X DOUBLE PRECISION, ":memory:".PUBLIC.FOO.Y CHARACTER VARYING(32))

SELECT * FROM foo
ORDER BY y, x
OFFSET 2 ROW;
-- X: 1.234e0 Y: hi
-- X: 12.34e0 Y: there

SELECT * FROM foo
ORDER BY y, x
OFFSET 50 ROW;

SELECT * FROM foo
ORDER BY y, x
FETCH FIRST 2 ROWS ONLY;
-- X: 5.6e0 Y: bar
-- X: 0.1234e0 Y: hi

/* extensions V001-01 */
EXPLAIN SELECT * FROM foo
ORDER BY y, x
OFFSET 1 ROW
FETCH FIRST 2 ROWS ONLY;
-- EXPLAIN: TABLE ":memory:".PUBLIC.FOO (X DOUBLE PRECISION, Y CHARACTER VARYING(32))
-- EXPLAIN: ORDER BY Y ASC, X ASC
-- EXPLAIN: OFFSET 1 ROWS FETCH FIRST 2 ROWS ONLY
-- EXPLAIN: EXPR (":memory:".PUBLIC.FOO.X DOUBLE PRECISION, ":memory:".PUBLIC.FOO.Y CHARACTER VARYING(32))

SELECT * FROM foo
ORDER BY y, x
OFFSET 1 ROW
FETCH FIRST 2 ROWS ONLY;
-- X: 0.1234e0 Y: hi
-- X: 1.234e0 Y: hi

SELECT * FROM foo
ORDER BY y, x
OFFSET 10 ROWS
FETCH FIRST 2 ROWS ONLY;

SELECT * FROM foo
ORDER BY y, x
OFFSET 1 ROW
FETCH FIRST 2 ROWS ONLY;
-- X: 0.1234e0 Y: hi
-- X: 1.234e0 Y: hi

/* extensions V001-01 */
CREATE TABLE bar (x FLOAT, y VARCHAR(32));
EXPLAIN SELECT * FROM bar ORDER BY x;
-- msg: CREATE TABLE 1
-- EXPLAIN: TABLE ":memory:".PUBLIC.BAR (X DOUBLE PRECISION, Y CHARACTER VARYING(32))
-- EXPLAIN: ORDER BY X ASC
-- EXPLAIN: EXPR (":memory:".PUBLIC.BAR.X DOUBLE PRECISION, ":memory:".PUBLIC.BAR.Y CHARACTER VARYING(32))

CREATE TABLE bar (x FLOAT, y VARCHAR(32));
SELECT * FROM bar ORDER BY x;
-- msg: CREATE TABLE 1

-- # A sort key needs a column reference, and can't have a subquery or an
-- # aggregate function, unless it's a vsql extension.
/* flags */
SELECT y FROM foo ORDER BY y, UPPER(y) DESC;
-- flags:
-- Y: bar
-- Y: hi
-- Y: hi
-- Y: there

/* extensions V202-01 */
/* flags */
SELECT y FROM foo ORDER BY y, 1;
-- flags: V202-01
-- Y: bar
-- Y: hi
-- Y: hi
-- Y: there

/* extensions V202-01 */
/* flags */
VALUES 3, 1 ORDER BY 1;
-- flags: F641, F661, V202-01
-- COL1: 3
-- COL1: 1

/* extensions V202-01 */
/* flags */
SELECT y FROM foo ORDER BY ?;
-- flags: B031, V202-01
-- error 42P02: parameter does not exist: ?1

/* extensions V202-02 */
/* flags */
SELECT y FROM foo ORDER BY (SELECT y FROM foo ORDER BY y FETCH FIRST 1 ROW ONLY);
-- flags: F850, F851, F857, F858, V202-02
-- Y: hi
-- Y: there
-- Y: hi
-- Y: bar

/* extensions V202-01 V202-02 */
/* flags */
SELECT y FROM foo ORDER BY (SELECT 1 FROM foo FETCH FIRST 1 ROW ONLY), y;
-- flags: F857, F858, V202-01, V202-02
-- Y: bar
-- Y: hi
-- Y: hi
-- Y: there

/* extensions V202-02 */
/* flags */
SELECT y FROM foo ORDER BY y IN (SELECT y FROM foo);
-- flags: T031, V202-02
-- Y: hi
-- Y: there
-- Y: hi
-- Y: bar

/* extensions V202-01 V202-03 */
/* flags */
SELECT COUNT(*) FROM foo ORDER BY COUNT(*);
-- flags: V202-01, V202-03
-- COL1: 4

/* extensions V202-03 */
/* flags */
SELECT COUNT(y) FROM foo ORDER BY COUNT(y) + 1;
-- flags: F441, V202-03
-- COL1: 4

-- # A sort key can't be the name of more than one column of the result (#804).
/* extensions V202-01 */
CREATE TABLE t (a INT, b INT);
INSERT INTO t (a, b) VALUES (1, 2);
SELECT a, b AS a FROM t ORDER BY a;
SELECT t.a, t.b AS a FROM t UNION SELECT a, b FROM t ORDER BY a;
SELECT a, b AS a FROM t ORDER BY t.a;
SELECT a, b AS a FROM t ORDER BY b;
SELECT a, b AS a FROM t ORDER BY 'A';
SELECT a, b AS a FROM t ORDER BY 1.5 + 1.5 + 1.5 + 1.5;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 42702: ambiguous column: A
-- error 42702: ambiguous column: A
-- A: 1 A: 2
-- A: 1 A: 2
-- A: 1 A: 2
-- A: 1 A: 2

-- # A sort key of a grouped query can only use grouping columns, otherwise the
-- # order depends on which row of the group is used.
CREATE TABLE g (x INTEGER, y INTEGER);
INSERT INTO g (x, y) VALUES (1, 2), (2, 1), (1, 0);
SELECT x FROM g GROUP BY x ORDER BY y;
SELECT x FROM g GROUP BY x ORDER BY g.y;
SELECT x FROM g GROUP BY x HAVING x > 0 ORDER BY y + 1;
SELECT COUNT(*) FROM g ORDER BY y;
SELECT COUNT(*) FROM g HAVING COUNT(*) > 0 ORDER BY x;
SELECT 1 FROM g HAVING COUNT(*) > 0 ORDER BY x;
SELECT x FROM g GROUP BY x ORDER BY x DESC;
SELECT x FROM g GROUP BY x ORDER BY g.x + 1 DESC;
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- error 42803: column Y must be in the GROUP BY clause or used in an aggregate function
-- error 42803: column G.Y must be in the GROUP BY clause or used in an aggregate function
-- error 42803: column Y must be in the GROUP BY clause or used in an aggregate function
-- error 42803: column Y must be in the GROUP BY clause or used in an aggregate function
-- error 42803: column X must be in the GROUP BY clause or used in an aggregate function
-- error 42803: column X must be in the GROUP BY clause or used in an aggregate function
-- X: 2
-- X: 1
-- X: 2
-- X: 1
