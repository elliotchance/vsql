/* setup */
CREATE TABLE t1 (x INT);
INSERT INTO t1 (x) VALUES (0);

/* extensions V001-01 */
EXPLAIN SELECT 1 AS bob FROM t1;
-- EXPLAIN: TABLE ":memory:".PUBLIC.T1 (X INTEGER)
-- EXPLAIN: EXPR (BOB SMALLINT)

SELECT 1 AS bob FROM t1;
-- BOB: 1

/* extensions V001-01 */
EXPLAIN SELECT 1 AS "Bob" FROM t1;
-- EXPLAIN: TABLE ":memory:".PUBLIC.T1 (X INTEGER)
-- EXPLAIN: EXPR ("Bob" SMALLINT)

SELECT 1 AS "Bob" FROM t1;
-- Bob: 1

SELECT 'foo' || 'bar' AS Str FROM t1;
-- STR: foobar

SELECT 1 + 2 AS total1, 3 + 4 AS total2 FROM t1;
-- TOTAL1: 3 TOTAL2: 7

SELECT 1 + 2 total FROM t1;
-- TOTAL: 3
