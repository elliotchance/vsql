-- # A CHARACTER LARGE OBJECT or BINARY LARGE OBJECT can be an operand of an
-- # equality operation, such as = or <>, IN, IS DISTINCT FROM and NULLIF (9.11,
-- # Syntax Rules, 1), which is Feature T042 (9.11, Conformance Rules, 2).
CREATE TABLE t (c CLOB, b BLOB);
INSERT INTO t VALUES ('abc', X'0102'), ('x', X'');
SELECT c = 'abc', c <> CAST('abc' AS CLOB), b = X'0102', b IN (X'', X'03'), b IS DISTINCT FROM X'0102', NULLIF(c, 'x') FROM t;
SELECT c FROM t WHERE (c, b) = ('x', X'');
SELECT c FROM t WHERE b = ANY (SELECT b FROM t WHERE c = 'abc');
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- COL1: TRUE COL2: FALSE COL3: TRUE COL4: FALSE COL5: FALSE COL6: abc
-- COL1: FALSE COL2: TRUE COL3: FALSE COL4: TRUE COL5: TRUE COL6: NULL
-- C: x
-- C: abc

-- # A long value is compared like any other.
CREATE TABLE t (id INT, c CLOB, b BLOB);
INSERT INTO t VALUES (1, 'abcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghij', X'0102030405060708090A0102030405060708090A0102030405060708090A0102030405060708090A0102030405060708090A0102030405060708090A0102030405060708090A0102030405060708090A');
SELECT a.c = b.c, a.b = b.b, a.c = 'abc' FROM t a, t b;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: TRUE COL2: TRUE COL3: FALSE

/* flags */
VALUES CAST('abc' AS CLOB) = 'abc';
-- flags: F641, F661, T042, T046
-- COL1: TRUE

/* flags */
VALUES NULLIF(CAST(X'01' AS BLOB), X'02');
-- flags: F641, F661, T021, T042, T045
-- COL1: 01
