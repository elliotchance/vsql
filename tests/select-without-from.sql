-- # V008-01: A SELECT without a FROM clause reads one row with no columns.

/* setup */
CREATE TABLE t (x INT NOT NULL, y VARCHAR(10));
INSERT INTO t (x, y) VALUES (1, 'a');
INSERT INTO t (x, y) VALUES (2, 'b');
CREATE SEQUENCE seq;

/* flags */
/* extensions V008-01 */
SELECT 1;
-- flags: V008-01
-- COL1: 1

/* flags */
/* extensions V008-01 */
SELECT DISTINCT 1;
-- flags: V008-01
-- COL1: 1

/* flags */
/* extensions V008-01 */
SELECT ALL 1;
-- flags: V008-01
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

/* types */
/* extensions V008-01 */
SELECT 1 + 2 AS x, 'a';
-- X: 3 (SMALLINT) COL2: a (CHARACTER(1))

/* extensions V008-01 */
SELECT 1, 2 AS b, 3;
-- COL1: 1 B: 2 COL3: 3

/* extensions V008-01 */
SELECT 1 x;
-- X: 1

/* types */
/* extensions V008-01 */
SELECT CURRENT_DATE IS NOT NULL AS x;
-- X: TRUE (BOOLEAN)

/* extensions V008-01 */
SELECT NEXT VALUE FOR seq;
-- COL1: 1

SELECT *;
-- error 42601: syntax error: unexpected $end, expecting FROM

SELECT DISTINCT *;
-- error 42601: syntax error: unexpected $end, expecting FROM

SELECT *, 1;
-- error 42601: syntax error: unexpected ",", expecting FROM

/* extensions V008-01 */
SELECT t.*;
-- error 42P01: no such table: ":memory:".PUBLIC.T

/* extensions V008-01 */
SELECT x;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.X

/* extensions V008-01 */
SELECT COL1;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.COL1

/* extensions V008-01 */
SELECT t.x;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.T.X

SELECT 1 WHERE TRUE;
-- error 42601: syntax error: unexpected WHERE

SELECT 1 GROUP BY x;
-- error 42601: syntax error: unexpected GROUP

SELECT 1 HAVING TRUE;
-- error 42601: syntax error: unexpected HAVING

/* extensions V008-01 */
SELECT COUNT(*);
-- COL1: 1

/* extensions V008-01 */
SELECT COUNT(*), SUM(5) AS s, MIN(2), MAX('a');
-- COL1: 1 S: 5 COL3: 2 COL4: a

/* extensions V008-01 */
SELECT x, (SELECT COUNT(*)) AS c FROM t;
-- X: 1 C: 1
-- X: 2 C: 1

SELECT x, (SELECT COUNT(*) FROM (VALUES 1) AS v) AS c FROM t;
-- X: 1 C: 1
-- X: 2 C: 1

/* extensions V008-01 */
SELECT (SELECT SUM(x)) AS s FROM t;
-- S: 3

SELECT (SELECT SUM(x) FROM (VALUES 1) AS v) AS s FROM t;
-- S: 3

/* extensions V008-01 */
SELECT COUNT(x);
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.X

/* extensions V008-01 */
SELECT 1 AS a ORDER BY a;
-- A: 1

/* extensions V006-02 V008-01 */
SELECT 1 ORDER BY 1 + 1;
-- COL1: 1

/* extensions V008-01 */
SELECT 1 AS a ORDER BY b;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.B

/* extensions V008-01 */
SELECT 1 FETCH FIRST 1 ROW ONLY;
-- COL1: 1

/* extensions V008-01 */
SELECT 1 OFFSET 1 ROW;

/* extensions V008-01 */
SELECT 1 UNION SELECT 2;
-- COL1: 1
-- COL1: 2

/* extensions V008-01 */
SELECT 1 UNION ALL SELECT 1;
-- COL1: 1
-- COL1: 1

/* extensions V008-01 */
SELECT 1 EXCEPT SELECT 1;

/* extensions V006-02 V008-01 */
SELECT x FROM t UNION SELECT 3 ORDER BY 1;
-- X: 1
-- X: 2
-- X: 3

/* extensions V008-01 */
(SELECT 1) UNION (SELECT 2 FETCH FIRST 1 ROW ONLY);
-- COL1: 1
-- COL1: 2

/* extensions V008-01 */
SELECT * FROM (SELECT 1 AS a, 'b') AS d;
-- A: 1 COL2: b

/* extensions V008-01 */
SELECT d.b + 1 FROM (SELECT 1) AS d (b);
-- COL1: 2

/* extensions V008-01 */
SELECT x FROM t JOIN (SELECT 2 AS z) AS d ON x = z;
-- X: 2

/* extensions V008-01 */
SELECT * FROM t WHERE x = (SELECT 1);
-- X: 1 Y: a

/* extensions V008-01 */
SELECT * FROM t WHERE x IN (SELECT 2);
-- X: 2 Y: b

/* extensions V008-01 */
SELECT x FROM t WHERE EXISTS (SELECT 1) ORDER BY x FETCH FIRST 1 ROW ONLY;
-- X: 1

/* extensions V008-01 */
SELECT (SELECT 1 + 1);
-- COL1: 2

/* extensions V008-01 */
SELECT x, (SELECT x + 1) AS z FROM t;
-- X: 1 Z: 2
-- X: 2 Z: 3

/* extensions V008-01 */
SELECT y FROM t WHERE (SELECT x) = 2;
-- Y: b

/* extensions V008-01 */
VALUES (SELECT 7);
-- COL1: 7

/* extensions V006-02 V006-03 V008-01 */
SELECT DISTINCT (SELECT 1) AS z FROM t ORDER BY (SELECT 1);
-- Z: 1

INSERT INTO t (x, y) SELECT 3, 'c';
-- error 42601: syntax error: unexpected SELECT, expecting OVERRIDING or VALUES

/* extensions V008-01 */
INSERT INTO t (x, y) VALUES ((SELECT 3), 'c');
SELECT * FROM t WHERE x = 3;
-- msg: INSERT 1
-- X: 3 Y: c

/* extensions V008-01 */
UPDATE t SET y = (SELECT 'z') WHERE x = 1;
SELECT y FROM t WHERE x = 1;
-- msg: UPDATE 1
-- Y: z

/* extensions V001-01 V008-01 */
EXPLAIN SELECT 1;
-- EXPLAIN: SINGLE ROW
-- EXPLAIN: EXPR (COL1 SMALLINT)

/* extensions V001-01 V008-01 */
EXPLAIN SELECT COUNT(*) AS c;
-- EXPLAIN: SINGLE ROW
-- EXPLAIN: GROUP BY (COUNT(*) INTEGER)
-- EXPLAIN: EXPR (C INTEGER)

/* extensions V001-01 V006-02 V008-01 */
EXPLAIN SELECT 1 AS a ORDER BY 1 + 1 FETCH FIRST 1 ROW ONLY;
-- EXPLAIN: SINGLE ROW
-- EXPLAIN: ORDER BY 1 + 1 ASC
-- EXPLAIN: FETCH FIRST 1 ROWS ONLY
-- EXPLAIN: EXPR (A SMALLINT)

/* extensions V004-01 V004-02 V004-03 V008-01 */
DECLARE c CURSOR WITH HOLD FOR SELECT 1;
OPEN c;
FETCH NEXT FROM c;
-- msg: DECLARE CURSOR
-- msg: OPEN
-- COL1: 1

/* extensions V004-01 V008-01 */
DECLARE c CURSOR WITH HOLD FOR SELECT 1 FOR UPDATE;
-- error 42601: syntax error: cursor C is not updatable

/* flags */
/* extensions V008-01 */
SELECT 1 AS "SELECT" UNION SELECT (SELECT 2);
-- flags: V008-01
-- SELECT: 1
-- SELECT: 2
