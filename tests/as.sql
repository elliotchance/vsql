/* setup */
CREATE TABLE t1 (x INT);
INSERT INTO t1 (x) VALUES (0);

SELECT 1 AS bob FROM t1;
-- BOB: 1

SELECT 1 AS "Bob" FROM t1;
-- Bob: 1

SELECT 'foo' || 'bar' AS Str FROM t1;
-- STR: foobar

SELECT 1 + 2 AS total1, 3 + 4 AS total2 FROM t1;
-- TOTAL1: 3 TOTAL2: 7
