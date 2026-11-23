-- # SUM, AVG and the variance and standard deviation of a DECFLOAT are a
-- # DECFLOAT with the same precision (Syntax Rules, 7.g.v and 7.h.i). The sums
-- # are exact, so only the result is rounded.
/* setup */
CREATE TABLE t (x DECFLOAT(16), y DECFLOAT);
INSERT INTO t VALUES (1.5, 1), (2.25, 2), (3, 2), (NULL, NULL);

/* types */
SELECT SUM(x), AVG(x), MIN(x), MAX(x), COUNT(x) FROM t;
-- warning 01003: null value eliminated in set function
-- COL1: 6.75 (DECFLOAT(16)) COL2: 2.25 (DECFLOAT(16)) COL3: 1.5 (DECFLOAT(16)) COL4: 3 (DECFLOAT(16)) COL5: 3 (INTEGER)

/* types */
SELECT STDDEV_POP(x), STDDEV_SAMP(x), VAR_POP(x), VAR_SAMP(x) FROM t;
-- warning 01003: null value eliminated in set function
-- COL1: 0.6123724356957945 (DECFLOAT(16)) COL2: 0.75 (DECFLOAT(16)) COL3: 0.3750 (DECFLOAT(16)) COL4: 0.5625 (DECFLOAT(16))

/* types */
SELECT AVG(y), SUM(DISTINCT y), STDDEV_POP(y) FROM t;
-- warning 01003: null value eliminated in set function
-- COL1: 1.666666666666666666666666666666667 (DECFLOAT(34)) COL2: 3 (DECFLOAT(34)) COL3: 0.4714045207910316829338962414032327 (DECFLOAT(34))

-- # A sample of one value has no variance, and no values are NULL.
/* types */
SELECT VAR_SAMP(x), STDDEV_SAMP(x), SUM(x), AVG(x) FROM t WHERE y = 1;
SELECT SUM(x), AVG(x), VAR_POP(x) FROM t WHERE y > 5;
-- COL1: NULL (DECFLOAT(16)) COL2: NULL (DECFLOAT(16)) COL3: 1.5 (DECFLOAT(16)) COL4: 1.5 (DECFLOAT(16))
-- COL1: NULL (DECFLOAT(16)) COL2: NULL (DECFLOAT(16)) COL3: NULL (DECFLOAT(16))

-- # The sum is exact before it's rounded, so the order doesn't matter.
CREATE TABLE u (x DECFLOAT(16));
INSERT INTO u VALUES (CAST('1E+16' AS DECFLOAT)), (0.5), (0.5), (-1E+16);
SELECT SUM(x) FROM u;
-- msg: CREATE TABLE 1
-- msg: INSERT 4
-- COL1: 1.0

-- # A sum out of range is an error.
CREATE TABLE u (x DECFLOAT(16));
INSERT INTO u VALUES (CAST('9E384' AS DECFLOAT(16))), (CAST('9E384' AS DECFLOAT(16)));
SELECT SUM(x) FROM u;
SELECT AVG(x) FROM u;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- error 22003: numeric value out of range
-- COL1: 9E+384
