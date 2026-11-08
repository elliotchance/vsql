/* setup */
CREATE TABLE foo (x FLOAT);
INSERT INTO foo (x) VALUES (NULL);
INSERT INTO foo (x) VALUES (123);
INSERT INTO foo (x) VALUES (NULL);
INSERT INTO foo (x) VALUES (456);

-- # NULLs aren't distinct from each other, so all the NULLs make one group
-- # (General Rules, 2.b).
SELECT x FROM foo GROUP BY x;
-- X: NULL
-- X: 123e0
-- X: 456e0

-- # COUNT(*) counts every row, NULLs included.
SELECT x, count(*) FROM foo GROUP BY x;
-- X: NULL COL2: 2
-- X: 123e0 COL2: 1
-- X: 456e0 COL2: 1

-- # The other aggregates skip NULLs, with a warning when any are skipped
-- # (10.9, General Rules, 7.a). Nothing is left in the NULL group, so COUNT is
-- # 0 and the others are NULL (10.9, General Rules, 7.d.ii).
SELECT x, count(x) FROM foo GROUP BY x;
-- warning 01003: null value eliminated in set function
-- X: NULL COL2: 0
-- X: 123e0 COL2: 1
-- X: 456e0 COL2: 1

SELECT count(*) FROM foo;
-- COL1: 4

SELECT count(x) FROM foo;
-- warning 01003: null value eliminated in set function
-- COL1: 2

SELECT count(*) FROM foo WHERE x IS NOT NULL;
-- COL1: 2

SELECT count(x) FROM foo WHERE x IS NOT NULL;
-- COL1: 2

SELECT x, min(x) FROM foo GROUP BY x;
-- warning 01003: null value eliminated in set function
-- X: NULL COL2: NULL
-- X: 123e0 COL2: 123e0
-- X: 456e0 COL2: 456e0

SELECT min(x) FROM foo;
-- warning 01003: null value eliminated in set function
-- COL1: 123e0

SELECT min(x) FROM foo WHERE x IS NOT NULL;
-- COL1: 123e0

SELECT x, max(x) FROM foo GROUP BY x;
-- warning 01003: null value eliminated in set function
-- X: NULL COL2: NULL
-- X: 123e0 COL2: 123e0
-- X: 456e0 COL2: 456e0

SELECT max(x) FROM foo;
-- warning 01003: null value eliminated in set function
-- COL1: 456e0

SELECT max(x) FROM foo WHERE x IS NOT NULL;
-- COL1: 456e0

SELECT x, avg(x) FROM foo GROUP BY x;
-- warning 01003: null value eliminated in set function
-- X: NULL COL2: NULL
-- X: 123e0 COL2: 123e0
-- X: 456e0 COL2: 456e0

SELECT avg(x) FROM foo;
-- warning 01003: null value eliminated in set function
-- COL1: 289.5e0

SELECT avg(x) FROM foo WHERE x IS NOT NULL;
-- COL1: 289.5e0

SELECT x, sum(x) FROM foo GROUP BY x;
-- warning 01003: null value eliminated in set function
-- X: NULL COL2: NULL
-- X: 123e0 COL2: 123e0
-- X: 456e0 COL2: 456e0

SELECT sum(x) FROM foo;
-- warning 01003: null value eliminated in set function
-- COL1: 579e0

SELECT sum(x) FROM foo WHERE x IS NOT NULL;
-- COL1: 579e0

SELECT min(x), max(x), avg(x), sum(x) FROM foo WHERE x IS NULL;
-- warning 01003: null value eliminated in set function
-- COL1: NULL COL2: NULL COL3: NULL COL4: NULL
