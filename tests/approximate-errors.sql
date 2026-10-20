-- # Infinity and NaN aren't SQL values, so a result that's too large for the
-- # type is out of range, and functions check their arguments.
VALUES CAST(1e300 AS REAL);
-- error 22003: numeric value out of range

CREATE TABLE t (r REAL);
INSERT INTO t (r) VALUES (1e300);
-- msg: CREATE TABLE 1
-- error 22003: numeric value out of range

VALUES 1e400;
-- error 22003: numeric value out of range

VALUES ROW(1e-400, CAST(1e-50 AS REAL));
-- COL1: 0e0 COL2: 0e0

VALUES 1e308 * 10e0;
-- error 22003: numeric value out of range

VALUES CAST(3e38 AS REAL) * CAST(2e0 AS REAL);
-- error 22003: numeric value out of range

VALUES EXP(1000e0);
-- error 22003: numeric value out of range

VALUES POWER(10e0, 400e0);
-- error 22003: numeric value out of range

VALUES SQRT(-1e0);
-- error 2201F: invalid argument for power function

VALUES LN(0e0);
-- error 2201E: invalid argument for natural logarithm

VALUES LN(-1e0);
-- error 2201E: invalid argument for natural logarithm

VALUES LOG10(0e0);
-- error 22003: numeric value out of range

VALUES LOG10(-5e0);
-- error 22003: numeric value out of range

VALUES POWER(0e0, -1e0);
-- error 2201F: invalid argument for power function

VALUES POWER(-8e0, 0.5e0);
-- error 2201F: invalid argument for power function

VALUES ROW(POWER(-2e0, 3e0), POWER(-2e0, 2e0), POWER(0e0, 0e0), POWER(0e0, 2e0));
-- COL1: -8e0 COL2: 4e0 COL3: 1e0 COL4: 0e0

VALUES ASIN(2e0);
-- error 22003: numeric value out of range

VALUES ACOS(-2e0);
-- error 22003: numeric value out of range

VALUES ROW(ASIN(1e0), ACOS(-1e0));
-- COL1: 1.570796326795e0 COL2: 3.14159265359e0
