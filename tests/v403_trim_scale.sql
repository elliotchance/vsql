-- # TRIM_SCALE and MIN_SCALE are vsql extensions (V403-22 and V403-23) from
-- # PostgreSQL. They remove or count the decimal places that a number needs.

/* setup */
CREATE TABLE t (n NUMERIC(10, 4), d DECIMAL(6, 2), f DECFLOAT, i INTEGER);
INSERT INTO t (n, d, f, i) VALUES (1.5, 4.00, 1.500, 10), (-0.0625, 0.25, 100, -3), (NULL, NULL, NULL, NULL);

-- # TRIM_SCALE of an exact number is a DECFLOAT(34) with only the decimal
-- # places that it needs, since every NUMERIC has the scale of its type. The
-- # zeros of a whole number are kept, and a zero is 0.
/* types */
VALUES ROW(TRIM_SCALE(8.4100), TRIM_SCALE(-12.000), TRIM_SCALE(100.0), TRIM_SCALE(0.000), TRIM_SCALE(-0.50), TRIM_SCALE(7));
-- COL1: 8.41 (DECFLOAT(34)) COL2: -12 (DECFLOAT(34)) COL3: 100 (DECFLOAT(34)) COL4: 0 (DECFLOAT(34)) COL5: -0.5 (DECFLOAT(34)) COL6: 7 (DECFLOAT(34))

-- # MIN_SCALE is the number of those decimal places, as an INTEGER.
/* types */
VALUES ROW(MIN_SCALE(8.4100), MIN_SCALE(-12.000), MIN_SCALE(100.0), MIN_SCALE(0.000), MIN_SCALE(-0.50), MIN_SCALE(7));
-- COL1: 2 (INTEGER) COL2: 0 (INTEGER) COL3: 0 (INTEGER) COL4: 0 (INTEGER) COL5: 1 (INTEGER) COL6: 0 (INTEGER)

-- # Any exact number or column can be used, and NULL is NULL.
/* types */
SELECT TRIM_SCALE(n), MIN_SCALE(n), TRIM_SCALE(d), MIN_SCALE(d), TRIM_SCALE(i), MIN_SCALE(i) FROM t;
-- COL1: 1.5 (DECFLOAT(34)) COL2: 1 (INTEGER) COL3: 4 (DECFLOAT(34)) COL4: 0 (INTEGER) COL5: 10 (DECFLOAT(34)) COL6: 0 (INTEGER)
-- COL1: -0.0625 (DECFLOAT(34)) COL2: 4 (INTEGER) COL3: 0.25 (DECFLOAT(34)) COL4: 2 (INTEGER) COL5: -3 (DECFLOAT(34)) COL6: 0 (INTEGER)
-- COL1: NULL (DECFLOAT(34)) COL2: NULL (INTEGER) COL3: NULL (DECFLOAT(34)) COL4: NULL (INTEGER) COL5: NULL (DECFLOAT(34)) COL6: NULL (INTEGER)

-- # It removes the zeros of a division or an average.
SELECT TRIM_SCALE(AVG(n)), TRIM_SCALE(SUM(d) / 8) FROM t;
-- warning 01003: null value eliminated in set function
-- COL1: 0.7187 COL2: 0.53

-- # The result keeps its decimal places in a row, a UNION, a CAST to a string
-- # and an expression. Stored in a NUMERIC column, it has the scale of the
-- # column again.
VALUES ROW(TRIM_SCALE(1.50), CAST(TRIM_SCALE(1.50) AS VARCHAR(10)), TRIM_SCALE(1.50) + 1);
SELECT TRIM_SCALE(n) FROM t WHERE n > 0 UNION ALL VALUES TRIM_SCALE(2.2500);
INSERT INTO t (n) VALUES (TRIM_SCALE(3.50));
SELECT n FROM t WHERE n > 3;
-- COL1: 1.5 COL2: 1.5 COL3: 2.5
-- COL1: 1.5
-- COL1: 2.25
-- msg: INSERT 1
-- N: 3.5000

-- # A DECFLOAT keeps its precision. A very small number has an exponent, like
-- # any other DECFLOAT.
/* types */
SELECT TRIM_SCALE(f), MIN_SCALE(f), TRIM_SCALE(CAST(-1.2300 AS DECFLOAT(16))), TRIM_SCALE(0.000000123000) FROM t WHERE f IS NOT NULL;
-- COL1: 1.5 (DECFLOAT(34)) COL2: 1 (INTEGER) COL3: -1.23 (DECFLOAT(16)) COL4: 1.23E-7 (DECFLOAT(34))
-- COL1: 100 (DECFLOAT(34)) COL2: 0 (INTEGER) COL3: -1.23 (DECFLOAT(16)) COL4: 1.23E-7 (DECFLOAT(34))

-- # The zeros of a DECFLOAT with an exponent are part of the whole number, so
-- # they're kept.
VALUES ROW(TRIM_SCALE(CAST(1.50E+3 AS DECFLOAT)), MIN_SCALE(CAST(1.50E+3 AS DECFLOAT)));
-- COL1: 1500 COL2: 0

-- # An exact number with more than 34 significant digits is rounded, like a
-- # CAST to a DECFLOAT. MIN_SCALE is exact.
VALUES ROW(TRIM_SCALE(1234567890123456789012345678901234567.50), MIN_SCALE(1234567890123456789012345678901234567.50));
-- COL1: 1.234567890123456789012345678901235E+36 COL2: 1

-- # A string isn't a number.
VALUES TRIM_SCALE('1.50');
VALUES MIN_SCALE('1.50');
-- error 42883: function does not exist: TRIM_SCALE(CHARACTER(4))
-- error 42883: function does not exist: MIN_SCALE(CHARACTER(4))

-- # The flagger.
/* flags */
SELECT TRIM_SCALE(n), MIN_SCALE(n) FROM t WHERE n > 0;
-- flags: V403-22, V403-23
-- COL1: 1.5 COL2: 1
