-- # Binary strings are compared octet by octet (8.2, General Rules, 5). When
-- # one is the start of the other, the shorter one is less, even if the rest is
-- # all X'00' (8.2, General Rules, 5.c is implementation-defined).
VALUES (X'01' = X'01', X'01' < X'02', X'0102' > X'01FF', X'01' < X'0100', X'' < X'00', X'FF' > X'0FFF');
-- COL1: TRUE COL2: TRUE COL3: FALSE COL4: TRUE COL5: TRUE COL6: TRUE

VALUES (X'01' <> X'0100', X'0100' >= X'01', X'01' <= X'01', X'01' = X'0100');
-- COL1: TRUE COL2: TRUE COL3: TRUE COL4: FALSE

-- # A BINARY is padded with X'00', so it's only equal to a value of the same
-- # length.
CREATE TABLE t (a BINARY(3), b VARBINARY(3));
INSERT INTO t VALUES (X'01', X'010000'), (X'02', X'02');
SELECT a = b, a > b, a BETWEEN X'01' AND X'0101', a IN (X'010000', X'02') FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- COL1: TRUE COL2: FALSE COL3: TRUE COL4: TRUE
-- COL1: FALSE COL2: TRUE COL3: FALSE COL4: FALSE

-- # A binary string is only comparable with another binary string.
VALUES X'01' = '01';
-- error 42883: cannot compare BINARY(1) and CHARACTER(2)

VALUES X'01' = 1;
-- error 42883: cannot compare BINARY(1) and INTEGER

-- # The result is NULL if either is NULL.
/* types */
VALUES X'01' = CAST(NULL AS VARBINARY(1));
-- COL1: UNKNOWN (BOOLEAN)

-- # A binary string can be in a WHERE, CASE, NULLIF, GREATEST and LEAST, and
-- # IS DISTINCT FROM.
CREATE TABLE t (a VARBINARY(3) PRIMARY KEY, b VARBINARY(3));
INSERT INTO t VALUES (X'01', X'01'), (X'0100', NULL), (X'02', X'03');
SELECT a FROM t WHERE a > X'01';
SELECT a FROM t WHERE a = X'0100';
SELECT CASE a WHEN X'02' THEN 2 ELSE 0 END, NULLIF(a, b), GREATEST(a, X'0101'), LEAST(a, X'0101'), a IS DISTINCT FROM b FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- A: 0100
-- A: 02
-- A: 0100
-- COL1: 0 COL2: NULL COL3: 0101 COL4: 01 COL5: FALSE
-- COL1: 0 COL2: 0100 COL3: 0101 COL4: 0100 COL5: TRUE
-- COL1: 2 COL2: 02 COL3: 02 COL4: 0101 COL5: TRUE

-- # A BINARY LARGE OBJECT can only be compared for equality (see
-- # std_2_8_2_lob_comparison.sql).
VALUES CAST(X'01' AS BLOB) = X'01';
-- COL1: TRUE
