-- # ABS has the declared type of its argument. FLOOR and CEIL have a scale of 0
-- # and one more digit for a fractional part. MOD has the type of the divisor.
EXPLAIN VALUES ROW(ABS(1.25), ABS(CAST(-5 AS DECIMAL(4, 1))), FLOOR(1.5), CEIL(CAST(9.5 AS NUMERIC(2, 1))), MOD(CAST(7 AS NUMERIC(10)), CAST(3 AS NUMERIC(2))));
-- EXPLAIN: VALUES (COL1 NUMERIC(3, 2), COL2 DECIMAL(4, 1), COL3 NUMERIC(2), COL4 NUMERIC(2), COL5 NUMERIC(2)) = ROW(ABS(1.25), ABS(CAST(-5 AS DECIMAL(4, 1))), FLOOR(1.5), CEILING(CAST(9.5 AS NUMERIC(2, 1))), MOD(CAST(7 AS NUMERIC(10)), CAST(3 AS NUMERIC(2))))

/* types */
VALUES ROW(ABS(-1.25), ABS(CAST(-5.5 AS DECIMAL(4, 1))), CEIL(CAST(9.5 AS NUMERIC(2, 1))));
-- COL1: 1.25 (NUMERIC(3, 2)) COL2: 5.5 (DECIMAL(4, 1)) COL3: 10 (NUMERIC(2))

/* types */
VALUES MOD(CAST(7 AS NUMERIC(10)), CAST(3 AS NUMERIC(2)));
-- COL1: 1 (NUMERIC(2))

-- # vsql also allows a scale for MOD. The result has the larger scale.
/* types */
VALUES MOD(CAST(7.25 AS NUMERIC(3, 2)), CAST(2 AS NUMERIC(1)));
-- COL1: 1.25 (NUMERIC(3, 2))

-- # Columns use their declared type.
CREATE TABLE t (x NUMERIC(5, 2));
INSERT INTO t (x) VALUES (-123.45);
SELECT ABS(x), FLOOR(x), CEIL(x) FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 123.45 COL2: -124 COL3: -123

/* types */
VALUES ABS(CAST(NULL AS NUMERIC(4, 1)));
-- COL1: NULL (NUMERIC(4, 1))
