/* setup */
CREATE TABLE foo (x FLOAT);
INSERT INTO foo (x) VALUES (NULL);
INSERT INTO foo (x) VALUES (123);
INSERT INTO foo (x) VALUES (NULL);
INSERT INTO foo (x) VALUES (456);

SELECT x FROM foo GROUP BY x;
-- X: NULL
-- X: 123e0
-- X: 456e0

SELECT x, count(*) FROM foo GROUP BY x;
-- X: NULL COL2: 2
-- X: 123e0 COL2: 1
-- X: 456e0 COL2: 1

SELECT x, count(x) FROM foo GROUP BY x;
-- X: NULL COL2: 0
-- X: 123e0 COL2: 1
-- X: 456e0 COL2: 1

SELECT count(*) FROM foo;
-- COL1: 4

SELECT count(x) FROM foo;
-- COL1: 2

SELECT count(*) FROM foo WHERE x IS NOT NULL;
-- COL1: 2

SELECT count(x) FROM foo WHERE x IS NOT NULL;
-- COL1: 2

SELECT x, min(x) FROM foo GROUP BY x;
-- X: NULL COL2: NULL
-- X: 123e0 COL2: 123e0
-- X: 456e0 COL2: 456e0

SELECT min(x) FROM foo;
-- COL1: NULL

SELECT min(x) FROM foo WHERE x IS NOT NULL;
-- COL1: 123e0

SELECT x, max(x) FROM foo GROUP BY x;
-- X: NULL COL2: NULL
-- X: 123e0 COL2: 123e0
-- X: 456e0 COL2: 456e0

SELECT max(x) FROM foo;
-- COL1: NULL

SELECT max(x) FROM foo WHERE x IS NOT NULL;
-- COL1: 456e0

SELECT x, avg(x) FROM foo GROUP BY x;
-- X: NULL COL2: NULL
-- X: 123e0 COL2: 123e0
-- X: 456e0 COL2: 456e0

SELECT avg(x) FROM foo;
-- COL1: NULL

SELECT avg(x) FROM foo WHERE x IS NOT NULL;
-- COL1: 289.5e0

SELECT x, sum(x) FROM foo GROUP BY x;
-- X: NULL COL2: NULL
-- X: 123e0 COL2: 123e0
-- X: 456e0 COL2: 456e0

SELECT sum(x) FROM foo;
-- COL1: NULL

SELECT sum(x) FROM foo WHERE x IS NOT NULL;
-- COL1: 579e0
