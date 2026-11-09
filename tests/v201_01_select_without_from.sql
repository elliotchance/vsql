-- # V201-01: A SELECT without a FROM clause reads one row with no columns.

/* setup */
CREATE TABLE t (x INT NOT NULL, y VARCHAR(10));
INSERT INTO t (x, y) VALUES (1, 'a');
INSERT INTO t (x, y) VALUES (2, 'b');
CREATE SEQUENCE seq;

-- # Only a SELECT without a FROM is flagged, including with DISTINCT or ALL.
/* flags */
/* extensions V201-01 */
SELECT 1;
-- flags: V201-01
-- COL1: 1

/* flags */
/* extensions V201-01 */
SELECT DISTINCT 1;
-- flags: V201-01
-- COL1: 1

/* flags */
/* extensions V201-01 */
SELECT ALL 1;
-- flags: V201-01
-- COL1: 1

/* flags */
SELECT 1 FROM t;
-- flags:
-- COL1: 1
-- COL1: 1

/* flags */
SELECT DISTINCT x FROM t;
-- flags:
-- X: 1
-- X: 2

/* flags */
SELECT * FROM t WHERE x = 1;
-- flags:
-- X: 1 Y: a

-- # It returns the select list as one row, named and typed as usual.
/* types */
/* extensions V201-01 */
SELECT 1 + 2 AS x, 'a';
-- X: 3 (SMALLINT) COL2: a (CHARACTER(1))

/* extensions V201-01 */
SELECT 1, 2 AS b, 3;
-- COL1: 1 B: 2 COL3: 3

/* extensions V201-01 */
SELECT 1 x;
-- X: 1

/* types */
/* extensions V201-01 */
SELECT CURRENT_DATE IS NOT NULL AS x;
-- X: TRUE (BOOLEAN)

/* extensions V201-01 */
SELECT NEXT VALUE FOR seq;
-- COL1: 1

-- # There are no columns: * needs a FROM to parse, and a column reference or
-- # T.* is an unknown name. WHERE, GROUP BY and HAVING need a FROM too.
SELECT *;
-- error 42601: syntax error: unexpected $end at line 1, column 9 near "SELECT *", expecting FROM

SELECT DISTINCT *;
-- error 42601: syntax error: unexpected $end at line 1, column 18 near "SELECT DISTINCT *", expecting FROM

SELECT *, 1;
-- error 42601: syntax error: unexpected "," at line 1, column 9 near "SELECT *, 1", expecting FROM

/* extensions V201-01 */
SELECT t.*;
-- error 42P01: no such table: ":memory:".PUBLIC.T

/* extensions V201-01 */
SELECT x;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.X

/* extensions V201-01 */
SELECT COL1;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.COL1

/* extensions V201-01 */
SELECT t.x;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.T.X

SELECT 1 WHERE TRUE;
-- error 42601: syntax error: unexpected WHERE at line 1, column 10 near "SELECT 1 WHERE TRUE"

SELECT 1 GROUP BY x;
-- error 42601: syntax error: unexpected GROUP at line 1, column 10 near "SELECT 1 GROUP BY"

SELECT 1 HAVING TRUE;
-- error 42601: syntax error: unexpected HAVING at line 1, column 10 near "SELECT 1 HAVING TRUE"

-- # An aggregate sees the one row, so COUNT(*) is 1. In a subquery, COUNT(*)
-- # has no column reference, so it counts the subquery's own row (6.9, Syntax
-- # Rules, 6.a), but SUM(x) of an outer column is aggregated by the outer query
-- # (6.9, Syntax Rules, 6.b), the same as with a FROM.
/* extensions V201-01 */
SELECT COUNT(*);
-- COL1: 1

/* extensions V201-01 */
SELECT COUNT(*), SUM(5) AS s, MIN(2), MAX('a');
-- COL1: 1 S: 5 COL3: 2 COL4: a

/* extensions V201-01 */
SELECT x, (SELECT COUNT(*)) AS c FROM t;
-- X: 1 C: 1
-- X: 2 C: 1

SELECT x, (SELECT COUNT(*) FROM (VALUES 1) AS v) AS c FROM t;
-- X: 1 C: 1
-- X: 2 C: 1

/* extensions V201-01 */
SELECT (SELECT SUM(x)) AS s FROM t;
-- S: 3

SELECT (SELECT SUM(x) FROM (VALUES 1) AS v) AS s FROM t;
-- S: 3

/* extensions V201-01 */
SELECT COUNT(x);
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.X

-- # ORDER BY, FETCH and OFFSET apply to the one row, so OFFSET 1 skips it.
/* extensions V201-01 */
SELECT 1 AS a ORDER BY a;
-- A: 1

/* extensions V202-01 V201-01 */
SELECT 1 ORDER BY 1 + 1;
-- COL1: 1

/* extensions V201-01 */
SELECT 1 AS a ORDER BY b;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.B

/* extensions V201-01 */
SELECT 1 FETCH FIRST 1 ROW ONLY;
-- COL1: 1

/* extensions V201-01 */
SELECT 1 OFFSET 1 ROW;

-- # It can be used anywhere a query can: in a set operation, as a derived
-- # table, or as a subquery in WHERE, IN, EXISTS or a value, including one that
-- # only refers to the columns of the outer query.
/* extensions V201-01 */
SELECT 1 UNION SELECT 2;
-- COL1: 1
-- COL1: 2

/* extensions V201-01 */
SELECT 1 UNION ALL SELECT 1;
-- COL1: 1
-- COL1: 1

/* extensions V201-01 */
SELECT 1 EXCEPT SELECT 1;

/* extensions V202-01 V201-01 */
SELECT x FROM t UNION SELECT 3 ORDER BY 1;
-- X: 1
-- X: 2
-- X: 3

/* extensions V201-01 */
(SELECT 1) UNION (SELECT 2 FETCH FIRST 1 ROW ONLY);
-- COL1: 1
-- COL1: 2

/* extensions V201-01 */
SELECT * FROM (SELECT 1 AS a, 'b') AS d;
-- A: 1 COL2: b

/* extensions V201-01 */
SELECT d.b + 1 FROM (SELECT 1) AS d (b);
-- COL1: 2

/* extensions V201-01 */
SELECT x FROM t JOIN (SELECT 2 AS z) AS d ON x = z;
-- X: 2

/* extensions V201-01 */
SELECT * FROM t WHERE x = (SELECT 1);
-- X: 1 Y: a

/* extensions V201-01 */
SELECT * FROM t WHERE x IN (SELECT 2);
-- X: 2 Y: b

/* extensions V201-01 */
SELECT x FROM t WHERE EXISTS (SELECT 1) ORDER BY x FETCH FIRST 1 ROW ONLY;
-- X: 1

/* extensions V201-01 */
SELECT (SELECT 1 + 1);
-- COL1: 2

/* extensions V201-01 */
SELECT x, (SELECT x + 1) AS z FROM t;
-- X: 1 Z: 2
-- X: 2 Z: 3

/* extensions V201-01 */
SELECT y FROM t WHERE (SELECT x) = 2;
-- Y: b

/* extensions V201-01 */
VALUES (SELECT 7);
-- COL1: 7

/* extensions V201-01 V202-01 V202-02 */
SELECT DISTINCT (SELECT 1) AS z FROM t ORDER BY (SELECT 1);
-- Z: 1

-- # And in INSERT and UPDATE, as the source or as a value.
/* extensions V201-01 */
INSERT INTO t (x, y) SELECT 3, 'c';
SELECT * FROM t WHERE x = 3;
-- msg: INSERT 1
-- X: 3 Y: c

/* extensions V201-01 */
INSERT INTO t (x, y) VALUES ((SELECT 3), 'c');
SELECT * FROM t WHERE x = 3;
-- msg: INSERT 1
-- X: 3 Y: c

/* extensions V201-01 */
UPDATE t SET y = (SELECT 'z') WHERE x = 1;
SELECT y FROM t WHERE x = 1;
-- msg: UPDATE 1
-- Y: z

-- # EXPLAIN shows the one row as SINGLE ROW.
/* extensions V001-01 V201-01 */
EXPLAIN SELECT 1;
-- EXPLAIN: SINGLE ROW
-- EXPLAIN: EXPR (COL1 SMALLINT)

/* extensions V001-01 V201-01 */
EXPLAIN SELECT COUNT(*) AS c;
-- EXPLAIN: SINGLE ROW
-- EXPLAIN: GROUP BY (COUNT(*) INTEGER)
-- EXPLAIN: EXPR (C INTEGER)

/* extensions V001-01 V202-01 V201-01 */
EXPLAIN SELECT 1 AS a ORDER BY 1 + 1 FETCH FIRST 1 ROW ONLY;
-- EXPLAIN: SINGLE ROW
-- EXPLAIN: ORDER BY 1 + 1 ASC
-- EXPLAIN: FETCH FIRST 1 ROWS ONLY
-- EXPLAIN: EXPR (A SMALLINT)

-- # A cursor can read it, but it isn't updatable since there's no table.
/* extensions V108-01 V109-01 V110-01 V201-01 */
DECLARE c CURSOR WITH HOLD FOR SELECT 1;
OPEN c;
FETCH NEXT FROM c;
-- msg: DECLARE CURSOR
-- msg: OPEN
-- COL1: 1

/* extensions V108-01 V201-01 */
DECLARE c CURSOR WITH HOLD FOR SELECT 1 FOR UPDATE;
-- error 42601: syntax error: cursor C is not updatable

-- # V201-01 is only listed once, however many SELECTs have no FROM.
/* flags */
/* extensions V201-01 */
SELECT 1 AS "SELECT" UNION SELECT (SELECT 2);
-- flags: V201-01
-- SELECT: 1
-- SELECT: 2
