VALUES MOD(5.0, 0.0);
-- error 22012: division by zero

VALUES MOD(5.0, 0);
-- error 22012: division by zero

VALUES MOD(5e0, 0e0);
-- error 22012: division by zero

VALUES MOD(0.0, 5.0);
-- COL1: 0

VALUES MOD(0e0, 5e0);
-- COL1: 0e0

VALUES 5.0 / 0.0;
-- error 22012: division by zero

VALUES CAST(5 AS DECIMAL(3, 1)) / CAST(0 AS DECIMAL(3, 1));
-- error 22012: division by zero

-- # Zero NUMERIC and DECIMAL values are stored and read back correctly.

CREATE TABLE t (n NUMERIC(5, 2), d DECIMAL(5, 2));
INSERT INTO t (n, d) VALUES (0, 0);
INSERT INTO t (n, d) VALUES (0.00, -0.0);
SELECT n, d, n + 1.5, d - 1.5 FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- N: 0 D: 0 COL3: 1.5 COL4: -1.5
-- N: 0 D: 0 COL3: 1.5 COL4: -1.5
