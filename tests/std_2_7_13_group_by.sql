/* setup */
CREATE TABLE foo (x FLOAT, y VARCHAR(32));
INSERT INTO foo (x, y) VALUES (1.234, 'hello');
INSERT INTO foo (x, y) VALUES (12.34, 'hello');
INSERT INTO foo (x, y) VALUES (1.234, 'world');
INSERT INTO foo (x, y) VALUES (5.6, 'world');
INSERT INTO foo (x, y) VALUES (5.6, 'world');

-- # Each distinct value of the grouping column is one group
-- # (General Rules, 2.b). vsql sorts the rows to make the groups, so they come
-- # out in order.
/* extensions V001-01 */
EXPLAIN SELECT x FROM foo GROUP BY x;
-- EXPLAIN: TABLE ":memory:".PUBLIC.FOO (X DOUBLE PRECISION, Y CHARACTER VARYING(32))
-- EXPLAIN: ORDER BY X ASC
-- EXPLAIN: GROUP BY (":memory:".PUBLIC.FOO.X DOUBLE PRECISION)
-- EXPLAIN: EXPR (X DOUBLE PRECISION)

SELECT x FROM foo GROUP BY x;
-- X: 1.234e0
-- X: 5.6e0
-- X: 12.34e0

/* extensions V001-01 */
EXPLAIN SELECT x, count(*) FROM foo GROUP BY x;
-- EXPLAIN: TABLE ":memory:".PUBLIC.FOO (X DOUBLE PRECISION, Y CHARACTER VARYING(32))
-- EXPLAIN: ORDER BY X ASC
-- EXPLAIN: GROUP BY (":memory:".PUBLIC.FOO.X DOUBLE PRECISION, COUNT(*) INTEGER)
-- EXPLAIN: EXPR (X DOUBLE PRECISION, COL2 INTEGER)

SELECT x, count(*) FROM foo GROUP BY x;
-- X: 1.234e0 COL2: 2
-- X: 5.6e0 COL2: 2
-- X: 12.34e0 COL2: 1

/* extensions V001-01 */
EXPLAIN SELECT count(*), x FROM foo GROUP BY x;
-- EXPLAIN: TABLE ":memory:".PUBLIC.FOO (X DOUBLE PRECISION, Y CHARACTER VARYING(32))
-- EXPLAIN: ORDER BY X ASC
-- EXPLAIN: GROUP BY (":memory:".PUBLIC.FOO.X DOUBLE PRECISION, COUNT(*) INTEGER)
-- EXPLAIN: EXPR (COL1 INTEGER, X DOUBLE PRECISION)

SELECT count(*), x FROM foo GROUP BY x;
-- COL1: 2 X: 1.234e0
-- COL1: 2 X: 5.6e0
-- COL1: 1 X: 12.34e0

-- # With two grouping columns, each distinct pair is a group. The groups are
-- # sorted in the order of the GROUP BY, not of the select list.
/* extensions V001-01 */
EXPLAIN SELECT x, y FROM foo GROUP BY x, y;
-- EXPLAIN: TABLE ":memory:".PUBLIC.FOO (X DOUBLE PRECISION, Y CHARACTER VARYING(32))
-- EXPLAIN: ORDER BY X ASC, Y ASC
-- EXPLAIN: GROUP BY (":memory:".PUBLIC.FOO.X DOUBLE PRECISION, ":memory:".PUBLIC.FOO.Y CHARACTER VARYING(32))
-- EXPLAIN: EXPR (X DOUBLE PRECISION, Y CHARACTER VARYING(32))

SELECT x, y FROM foo GROUP BY x, y;
-- X: 1.234e0 Y: hello
-- X: 1.234e0 Y: world
-- X: 5.6e0 Y: world
-- X: 12.34e0 Y: hello

/* extensions V001-01 */
EXPLAIN SELECT y, x FROM foo GROUP BY x, y;
-- EXPLAIN: TABLE ":memory:".PUBLIC.FOO (X DOUBLE PRECISION, Y CHARACTER VARYING(32))
-- EXPLAIN: ORDER BY X ASC, Y ASC
-- EXPLAIN: GROUP BY (":memory:".PUBLIC.FOO.X DOUBLE PRECISION, ":memory:".PUBLIC.FOO.Y CHARACTER VARYING(32))
-- EXPLAIN: EXPR (Y CHARACTER VARYING(32), X DOUBLE PRECISION)

SELECT y, x FROM foo GROUP BY x, y;
-- Y: hello X: 1.234e0
-- Y: world X: 1.234e0
-- Y: world X: 5.6e0
-- Y: hello X: 12.34e0

/* extensions V001-01 */
EXPLAIN SELECT x, y FROM foo GROUP BY y, x;
-- EXPLAIN: TABLE ":memory:".PUBLIC.FOO (X DOUBLE PRECISION, Y CHARACTER VARYING(32))
-- EXPLAIN: ORDER BY Y ASC, X ASC
-- EXPLAIN: GROUP BY (":memory:".PUBLIC.FOO.Y CHARACTER VARYING(32), ":memory:".PUBLIC.FOO.X DOUBLE PRECISION)
-- EXPLAIN: EXPR (X DOUBLE PRECISION, Y CHARACTER VARYING(32))

SELECT x, y FROM foo GROUP BY y, x;
-- X: 1.234e0 Y: hello
-- X: 12.34e0 Y: hello
-- X: 1.234e0 Y: world
-- X: 5.6e0 Y: world

-- # An expression can use a grouping column, since it has one value in each
-- # group (General Rules, 3.a).
/* extensions V001-01 */
EXPLAIN SELECT x + 1.0, x FROM foo GROUP BY x;
-- EXPLAIN: TABLE ":memory:".PUBLIC.FOO (X DOUBLE PRECISION, Y CHARACTER VARYING(32))
-- EXPLAIN: ORDER BY X ASC
-- EXPLAIN: GROUP BY (":memory:".PUBLIC.FOO.X DOUBLE PRECISION)
-- EXPLAIN: EXPR (COL1 DOUBLE PRECISION, X DOUBLE PRECISION)

SELECT x + 1e0, x FROM foo GROUP BY x;
-- COL1: 2.234e0 X: 1.234e0
-- COL1: 6.6e0 X: 5.6e0
-- COL1: 13.34e0 X: 12.34e0

-- # Each aggregate is computed over the rows of each group.
/* extensions V001-01 */
EXPLAIN SELECT x, count(x) FROM foo GROUP BY x;
-- EXPLAIN: TABLE ":memory:".PUBLIC.FOO (X DOUBLE PRECISION, Y CHARACTER VARYING(32))
-- EXPLAIN: ORDER BY X ASC
-- EXPLAIN: GROUP BY (":memory:".PUBLIC.FOO.X DOUBLE PRECISION, COUNT(X) INTEGER)
-- EXPLAIN: EXPR (X DOUBLE PRECISION, COL2 INTEGER)

SELECT x, count(x) FROM foo GROUP BY x;
-- X: 1.234e0 COL2: 2
-- X: 5.6e0 COL2: 2
-- X: 12.34e0 COL2: 1

/* extensions V001-01 */
EXPLAIN SELECT y, min(x) FROM foo GROUP BY y;
-- EXPLAIN: TABLE ":memory:".PUBLIC.FOO (X DOUBLE PRECISION, Y CHARACTER VARYING(32))
-- EXPLAIN: ORDER BY Y ASC
-- EXPLAIN: GROUP BY (":memory:".PUBLIC.FOO.Y CHARACTER VARYING(32), MIN(X) DOUBLE PRECISION)
-- EXPLAIN: EXPR (Y CHARACTER VARYING(32), COL2 DOUBLE PRECISION)

SELECT y, min(x) FROM foo GROUP BY y;
-- Y: hello COL2: 1.234e0
-- Y: world COL2: 1.234e0

/* extensions V001-01 */
EXPLAIN SELECT y, max(x) AS largest FROM foo GROUP BY y;
-- EXPLAIN: TABLE ":memory:".PUBLIC.FOO (X DOUBLE PRECISION, Y CHARACTER VARYING(32))
-- EXPLAIN: ORDER BY Y ASC
-- EXPLAIN: GROUP BY (":memory:".PUBLIC.FOO.Y CHARACTER VARYING(32), MAX(X) DOUBLE PRECISION)
-- EXPLAIN: EXPR (Y CHARACTER VARYING(32), LARGEST DOUBLE PRECISION)

SELECT y, max(x) AS largest FROM foo GROUP BY y;
-- Y: hello LARGEST: 12.34e0
-- Y: world LARGEST: 5.6e0

SELECT y, sum(x) FROM foo GROUP BY y;
-- Y: hello COL2: 13.574e0
-- Y: world COL2: 12.434e0

SELECT y, avg(x) FROM foo GROUP BY y;
-- Y: hello COL2: 6.787e0
-- Y: world COL2: 4.144666666667e0

-- # WHERE removes rows before they're grouped (General Rules, 1).
/* extensions V001-01 */
EXPLAIN SELECT y, avg(x) FROM foo WHERE y = 'hello' GROUP BY y;
-- EXPLAIN: TABLE ":memory:".PUBLIC.FOO (X DOUBLE PRECISION, Y CHARACTER VARYING(32))
-- EXPLAIN: WHERE Y = 'hello'
-- EXPLAIN: ORDER BY Y ASC
-- EXPLAIN: GROUP BY (":memory:".PUBLIC.FOO.Y CHARACTER VARYING(32), AVG(X) DOUBLE PRECISION)
-- EXPLAIN: EXPR (Y CHARACTER VARYING(32), COL2 DOUBLE PRECISION)

SELECT y, avg(x) FROM foo WHERE y = 'hello' GROUP BY y;
-- Y: hello COL2: 6.787e0

-- # An aggregate without a GROUP BY makes the whole table one group, so there's
-- # one row (7.16, Syntax Rules, 16). The argument can be an expression.
/* extensions V001-01 */
EXPLAIN SELECT count(*) FROM foo;
-- EXPLAIN: TABLE ":memory:".PUBLIC.FOO (X DOUBLE PRECISION, Y CHARACTER VARYING(32))
-- EXPLAIN: GROUP BY (COUNT(*) INTEGER)
-- EXPLAIN: EXPR (COL1 INTEGER)

SELECT count(*) FROM foo;
-- COL1: 5

SELECT count(x) FROM foo;
-- COL1: 5

SELECT min(x) FROM foo;
-- COL1: 1.234e0

SELECT max(x) FROM foo;
-- COL1: 12.34e0

SELECT avg(x) FROM foo;
-- COL1: 5.2016e0

SELECT sum(x) FROM foo;
-- COL1: 26.008e0

/* extensions V001-01 */
EXPLAIN SELECT min(x), max(x) FROM foo;
-- EXPLAIN: TABLE ":memory:".PUBLIC.FOO (X DOUBLE PRECISION, Y CHARACTER VARYING(32))
-- EXPLAIN: GROUP BY (MIN(X) DOUBLE PRECISION, MAX(X) DOUBLE PRECISION)
-- EXPLAIN: EXPR (COL1 DOUBLE PRECISION, COL2 DOUBLE PRECISION)

SELECT min(x), max(x) FROM foo;
-- COL1: 1.234e0 COL2: 12.34e0

/* extensions V001-01 */
EXPLAIN SELECT avg(x * 2e0) FROM foo;
-- EXPLAIN: TABLE ":memory:".PUBLIC.FOO (X DOUBLE PRECISION, Y CHARACTER VARYING(32))
-- EXPLAIN: GROUP BY (AVG(X * 2e0) DOUBLE PRECISION)
-- EXPLAIN: EXPR (COL1 DOUBLE PRECISION)

SELECT avg(x * 2e0) FROM foo;
-- COL1: 10.4032e0

-- # OFFSET and FETCH apply to the groups. An ORDER BY sorts the groups again
-- # after they're made.
/* extensions V001-01 */
EXPLAIN SELECT x FROM foo GROUP BY x FETCH FIRST 2 ROWS ONLY;
-- EXPLAIN: TABLE ":memory:".PUBLIC.FOO (X DOUBLE PRECISION, Y CHARACTER VARYING(32))
-- EXPLAIN: ORDER BY X ASC
-- EXPLAIN: GROUP BY (":memory:".PUBLIC.FOO.X DOUBLE PRECISION)
-- EXPLAIN: FETCH FIRST 2 ROWS ONLY
-- EXPLAIN: EXPR (X DOUBLE PRECISION)

SELECT x FROM foo GROUP BY x FETCH FIRST 2 ROWS ONLY;
-- X: 1.234e0
-- X: 5.6e0

/* extensions V001-01 */
EXPLAIN SELECT x FROM foo GROUP BY x 
OFFSET 1 ROW
FETCH FIRST 2 ROWS ONLY;
-- EXPLAIN: TABLE ":memory:".PUBLIC.FOO (X DOUBLE PRECISION, Y CHARACTER VARYING(32))
-- EXPLAIN: ORDER BY X ASC
-- EXPLAIN: GROUP BY (":memory:".PUBLIC.FOO.X DOUBLE PRECISION)
-- EXPLAIN: OFFSET 1 ROWS FETCH FIRST 2 ROWS ONLY
-- EXPLAIN: EXPR (X DOUBLE PRECISION)

SELECT x FROM foo GROUP BY x 
OFFSET 1 ROW
FETCH FIRST 2 ROWS ONLY;
-- X: 5.6e0
-- X: 12.34e0

/* extensions V001-01 */
EXPLAIN SELECT x FROM foo GROUP BY x ORDER BY x DESC FETCH FIRST 2 ROWS ONLY;
-- EXPLAIN: TABLE ":memory:".PUBLIC.FOO (X DOUBLE PRECISION, Y CHARACTER VARYING(32))
-- EXPLAIN: ORDER BY X ASC
-- EXPLAIN: GROUP BY (":memory:".PUBLIC.FOO.X DOUBLE PRECISION)
-- EXPLAIN: ORDER BY X DESC
-- EXPLAIN: FETCH FIRST 2 ROWS ONLY
-- EXPLAIN: EXPR (X DOUBLE PRECISION)

SELECT x FROM foo GROUP BY x ORDER BY x DESC FETCH FIRST 2 ROWS ONLY;
-- X: 12.34e0
-- X: 5.6e0

/* extensions V001-01 */
EXPLAIN SELECT x FROM foo
GROUP BY x
ORDER BY x DESC
OFFSET 1 ROW
FETCH FIRST 2 ROWS ONLY;
-- EXPLAIN: TABLE ":memory:".PUBLIC.FOO (X DOUBLE PRECISION, Y CHARACTER VARYING(32))
-- EXPLAIN: ORDER BY X ASC
-- EXPLAIN: GROUP BY (":memory:".PUBLIC.FOO.X DOUBLE PRECISION)
-- EXPLAIN: ORDER BY X DESC
-- EXPLAIN: OFFSET 1 ROWS FETCH FIRST 2 ROWS ONLY
-- EXPLAIN: EXPR (X DOUBLE PRECISION)

SELECT x FROM foo
GROUP BY x
ORDER BY x DESC
OFFSET 1 ROW
FETCH FIRST 2 ROWS ONLY;
-- X: 5.6e0
-- X: 1.234e0

-- # Aggregates can be used in expressions, but one can't be inside another
-- # (6.9, Syntax Rules, 1).
/* extensions V001-01 */
EXPLAIN SELECT y, min(x) * avg(x) FROM foo GROUP BY y;
-- EXPLAIN: TABLE ":memory:".PUBLIC.FOO (X DOUBLE PRECISION, Y CHARACTER VARYING(32))
-- EXPLAIN: ORDER BY Y ASC
-- EXPLAIN: GROUP BY (":memory:".PUBLIC.FOO.Y CHARACTER VARYING(32), MIN(X) * AVG(X) DOUBLE PRECISION)
-- EXPLAIN: EXPR (Y CHARACTER VARYING(32), COL2 DOUBLE PRECISION)

SELECT y, min(x) * avg(x) FROM foo GROUP BY y;
-- Y: hello COL2: 8.375158e0
-- Y: world COL2: 5.114518666667e0

SELECT count(*) + 1, max(x) - min(x) FROM foo;
-- COL1: 6 COL2: 11.106e0

SELECT sum(min(x)) FROM foo;
-- error 42601: syntax error: nested set function: SUM(MIN(X))

-- # Without a GROUP BY the whole table is one group, even when it's empty.
CREATE TABLE t2 (x FLOAT);
SELECT count(*), count(x), min(x), max(x), avg(x), sum(x) FROM t2;
-- msg: CREATE TABLE 1
-- COL1: 0 COL2: 0 COL3: NULL COL4: NULL COL5: NULL COL6: NULL

-- # With a GROUP BY, an empty table has no groups, so there are no rows
-- # (7.16, General Rules, 1.b.i).
CREATE TABLE t2 (x FLOAT);
SELECT x, count(*) FROM t2 GROUP BY x;
-- msg: CREATE TABLE 1

-- # Without a GROUP BY, a WHERE that removes every row still leaves one group.
SELECT count(*), sum(x) FROM foo WHERE x > 100e0;
-- COL1: 0 COL2: NULL

SELECT count(*) + 1 FROM foo WHERE x > 100e0;
-- COL1: 1

-- # A column that isn't grouped can only be used in an aggregate, qualified or
-- # not, and even without a GROUP BY when there's an aggregate
-- # (7.16, Syntax Rules, 17). A grouping column can be used in an expression.
CREATE TABLE t (a INT, b VARCHAR(10));
INSERT INTO t (a, b) VALUES (1, 'x'), (2, 'y'), (2, 'z');
SELECT b, COUNT(*) FROM t GROUP BY a;
SELECT t.b, COUNT(*) FROM t GROUP BY a;
SELECT a, COUNT(*) FROM t;
SELECT a + 1, COUNT(b) FROM t GROUP BY t.a;
SELECT t.a, COUNT(*) FROM t GROUP BY a;
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- error 42803: column B must be in the GROUP BY clause or used in an aggregate function
-- error 42803: column T.B must be in the GROUP BY clause or used in an aggregate function
-- error 42803: column A must be in the GROUP BY clause or used in an aggregate function
-- COL1: 2 COL2: 1
-- COL1: 3 COL2: 2
-- A: 1 COL2: 1
-- A: 2 COL2: 2

-- # Only the column named in the GROUP BY is grouped: U.A isn't, even though
-- # ON makes it equal to T.A, because vsql doesn't support functional
-- # dependencies (7.16, Conformance Rules, 3). A column of a derived table can
-- # be grouped by its plain name and selected with the correlation name.
CREATE TABLE t (a INT, b INT);
CREATE TABLE u (a INT, c INT);
INSERT INTO t (a, b) VALUES (1, 2);
INSERT INTO u (a, c) VALUES (1, 3);
SELECT t.a, COUNT(*) FROM t JOIN u ON t.a = u.a GROUP BY t.a;
SELECT u.a, COUNT(*) FROM t JOIN u ON t.a = u.a GROUP BY t.a;
SELECT x.a, COUNT(*) FROM (SELECT a, b FROM t) AS x GROUP BY a;
SELECT x.b FROM (SELECT a, b FROM t) AS x GROUP BY x.a;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- A: 1 COL2: 1
-- error 42803: column U.A must be in the GROUP BY clause or used in an aggregate function
-- A: 1 COL2: 1
-- error 42803: column X.B must be in the GROUP BY clause or used in an aggregate function

-- # A new row only changes the aggregate of its own group.
INSERT INTO foo (x, y) VALUES (0.5, 'hello');
SELECT y, min(x) FROM foo GROUP BY y;
-- msg: INSERT 1
-- Y: hello COL2: 0.5e0
-- Y: world COL2: 1.234e0
