-- # ERF, ERFC, GAMMA and LGAMMA are vsql extensions (V403-14 to V403-17), the
-- # error and gamma functions of PostgreSQL.

/* setup */
CREATE TABLE t (x INT, n NUMERIC(5, 3), d DOUBLE PRECISION);
INSERT INTO t (x, n, d) VALUES (5, 0.5, 1e0), (-3, -2.5, -0.5e0), (NULL, NULL, NULL);

-- # ERF is between -1 and 1, and ERFC is 1 - ERF, between 0 and 2.
/* types */
VALUES ROW(ERF(0), ERF(1), ERF(-1), ERF(0.5), ERF(1e300), ERF(-1e300));
-- COL1: 0e0 (DOUBLE PRECISION) COL2: 0.84270079295e0 (DOUBLE PRECISION) COL3: -0.84270079295e0 (DOUBLE PRECISION) COL4: 0.520499877813e0 (DOUBLE PRECISION) COL5: 1e0 (DOUBLE PRECISION) COL6: -1e0 (DOUBLE PRECISION)

/* types */
VALUES ROW(ERFC(0), ERFC(1), ERFC(-1), ERFC(10), ERFC(30), ERFC(-1e300));
-- COL1: 1e0 (DOUBLE PRECISION) COL2: 0.15729920705e0 (DOUBLE PRECISION) COL3: 1.84270079295e0 (DOUBLE PRECISION) COL4: 2.08848758376e-45 (DOUBLE PRECISION) COL5: 0e0 (DOUBLE PRECISION) COL6: 2e0 (DOUBLE PRECISION)

-- # GAMMA(n) is the factorial of n - 1, and GAMMA(0.5) is the square root of π.
/* types */
VALUES ROW(GAMMA(1), GAMMA(5), GAMMA(0.5), SQRT(PI()), GAMMA(171));
-- COL1: 1e0 (DOUBLE PRECISION) COL2: 24e0 (DOUBLE PRECISION) COL3: 1.772453850906e0 (DOUBLE PRECISION) COL4: 1.772453850906e0 (DOUBLE PRECISION) COL5: 7.25741561531e+306 (DOUBLE PRECISION)

-- # A negative number that isn't an integer is fine, and the result changes
-- # sign between each pair of integers. A result that is too small is 0.
VALUES ROW(GAMMA(-0.5), GAMMA(-1.5), GAMMA(-2.5), GAMMA(-200.5), GAMMA(-201.5));
-- COL1: -3.544907701811e0 COL2: 2.363271801207e0 COL3: -0.945308720483e0 COL4: 0e0 COL5: 0e0

-- # 0 and the negative integers aren't defined.
VALUES GAMMA(0);
-- error 22003: numeric value out of range

VALUES GAMMA(-0e0);
-- error 22003: numeric value out of range

VALUES GAMMA(-1);
-- error 22003: numeric value out of range

VALUES GAMMA(-3.0);
-- error 22003: numeric value out of range

VALUES GAMMA(-1e300);
-- error 22003: numeric value out of range

-- # A result that is too large.
VALUES GAMMA(172);
-- error 22003: numeric value out of range

VALUES GAMMA(1e300);
-- error 22003: numeric value out of range

VALUES GAMMA(1e-320);
-- error 22003: numeric value out of range

VALUES GAMMA(-1e-320);
-- error 22003: numeric value out of range

-- # LGAMMA is the logarithm of the absolute value of GAMMA, so it can be used
-- # where GAMMA is too large.
/* types */
VALUES ROW(LGAMMA(1), LGAMMA(2), LGAMMA(3), LGAMMA(0.5), LGAMMA(-0.5), LGAMMA(100), LGAMMA(1e-320), LGAMMA(2.55e305));
-- COL1: 0e0 (DOUBLE PRECISION) COL2: 0e0 (DOUBLE PRECISION) COL3: 0.69314718056e0 (DOUBLE PRECISION) COL4: 0.572364942925e0 (DOUBLE PRECISION) COL5: 1.265512123485e0 (DOUBLE PRECISION) COL6: 359.134205369575e0 (DOUBLE PRECISION) COL7: 736.827240890974e0 (DOUBLE PRECISION) COL8: 1.79067259414e+308 (DOUBLE PRECISION)

VALUES LGAMMA(0);
-- error 22003: numeric value out of range

VALUES LGAMMA(-2);
-- error 22003: numeric value out of range

VALUES LGAMMA(2.6e305);
-- error 22003: numeric value out of range

-- # Any number is converted to a DOUBLE PRECISION.
/* types */
VALUES ROW(GAMMA(CAST(4 AS SMALLINT)), GAMMA(CAST(4 AS BIGINT)), ERF(CAST(0.5 AS DECIMAL(3, 1))), LGAMMA(CAST(3 AS REAL)), ERFC(CAST(1 AS INTEGER)));
-- COL1: 6e0 (DOUBLE PRECISION) COL2: 6e0 (DOUBLE PRECISION) COL3: 0.520499877813e0 (DOUBLE PRECISION) COL4: 0.69314718056e0 (DOUBLE PRECISION) COL5: 0.15729920705e0 (DOUBLE PRECISION)

-- # NULL is NULL.
/* types */
VALUES ROW(ERF(CAST(NULL AS DOUBLE PRECISION)), ERFC(CAST(NULL AS INTEGER)), GAMMA(CAST(NULL AS NUMERIC)), LGAMMA(CAST(NULL AS REAL)));
-- COL1: NULL (DOUBLE PRECISION) COL2: NULL (DOUBLE PRECISION) COL3: NULL (DOUBLE PRECISION) COL4: NULL (DOUBLE PRECISION)

-- # With columns.
SELECT x, ERF(n), ERFC(d), GAMMA(x), LGAMMA(n) FROM t WHERE x > 0 OR x IS NULL;
-- X: 5 COL2: 0.520499877813e0 COL3: 0.15729920705e0 COL4: 24e0 COL5: 0.572364942925e0
-- X: NULL COL2: NULL COL3: NULL COL4: NULL COL5: NULL

SELECT GAMMA(x) FROM t;
-- error 22003: numeric value out of range

-- # A string isn't a number.
VALUES ERF('1');
-- error 42883: function does not exist: ERF(CHARACTER(1))

-- # None of the names are reserved.
CREATE TABLE erf (erf INT, erfc INT, gamma INT, lgamma INT);
INSERT INTO erf (erf, erfc, gamma, lgamma) VALUES (1, 2, 3, 4);
SELECT erf, erfc, gamma, lgamma FROM erf;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- ERF: 1 ERFC: 2 GAMMA: 3 LGAMMA: 4

-- # The flagger.
/* flags */
SELECT ERF(d), ERFC(d), GAMMA(d), LGAMMA(d) FROM t WHERE d > 0;
-- flags: V403-14, V403-15, V403-16, V403-17
-- COL1: 0.84270079295e0 COL2: 0.15729920705e0 COL3: 1e0 COL4: 0e0
