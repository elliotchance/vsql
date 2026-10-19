CREATE TABLE t1 (e INT, x INT);
INSERT INTO t1 (e, x) VALUES (1, 2);
SELECT e, t1.e, x AS e FROM t1;
UPDATE t1 SET e = e + 1;
SELECT * FROM t1 WHERE e = 2;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- E: 1 E: 1 E: 2
-- msg: UPDATE 1
-- E: 2 X: 2

CREATE TABLE e (a INT);
INSERT INTO e (a) VALUES (1e1);
SELECT a, 2E1, 3e-1, 4e+1 FROM e;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- A: 10 COL2: 20e0 COL3: 0.3e0 COL4: 40e0

/* types */
VALUES ROW(1.E2, .5e2, 1.5E-1, 1.e+1);
-- COL1: 100e0 (DOUBLE PRECISION) COL2: 50e0 (DOUBLE PRECISION) COL3: 0.15e0 (DOUBLE PRECISION) COL4: 10e0 (DOUBLE PRECISION)

VALUES 1.e;
-- error 42601: syntax error: unexpected identifier
