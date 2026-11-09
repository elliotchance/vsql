-- # E on its own is a regular identifier, not an exponent, so it works as a
-- # table, column or alias name. A digit followed by E and an exponent is an
-- # approximate numeric literal (5.3, Syntax Rules, 24 allows a lower case e),
-- # and 1e1 can be stored in an INT column as 10.
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

-- # The mantissa can have a decimal point at either end or none. vsql makes
-- # approximate literals DOUBLE PRECISION (5.3, Syntax Rules, 23). An E with
-- # no exponent after it isn't an exponent, so 1.e is the literal 1. followed
-- # by the identifier e, which needs a separator before it (Syntax Rules, 7).
/* types */
VALUES ROW(1.E2, .5e2, 1.5E-1, 1.e+1);
-- COL1: 100e0 (DOUBLE PRECISION) COL2: 50e0 (DOUBLE PRECISION) COL3: 0.15e0 (DOUBLE PRECISION) COL4: 10e0 (DOUBLE PRECISION)

VALUES 1.e;
-- error 42601: syntax error: unexpected identifier at line 1, column 10 near "VALUES 1.e"
