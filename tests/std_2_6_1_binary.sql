-- # A binary string literal is a BINARY with the number of octets in it (5.3,
-- # Syntax Rules, 10), shown as two hexadecimal digits for each octet. The X
-- # can be lower case, and so can the digits.
/* types */
VALUES X'0A1b';
-- COL1: 0A1B (BINARY(2))

/* types */
VALUES x'';
-- COL1:  (BINARY(0))

-- # Each octet must be two hexadecimal digits, and there can't be a space
-- # before the quote.
VALUES X'ABC';
-- error 42601: syntax error: X'ABC' is not a valid binary string literal

VALUES X'0G';
-- error 42601: syntax error: X'0G' is not a valid binary string literal

-- # BINARY, BINARY VARYING (or VARBINARY) and BINARY LARGE OBJECT (or BLOB)
-- # are stored as the octets. A BINARY is padded with X'00', and a BINARY
-- # without a length has a length of 1 (6.1, Syntax Rules, 5).
/* types */
CREATE TABLE t (a BINARY, b BINARY(3), c BINARY VARYING(3), d VARBINARY(4), e BINARY LARGE OBJECT, f BLOB(5));
INSERT INTO t VALUES (X'01', X'0102', X'0102', X'01020304', X'00', X'');
INSERT INTO t (a) VALUES (NULL);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- A: 01 (BINARY(1)) B: 010200 (BINARY(3)) C: 0102 (BINARY VARYING(3)) D: 01020304 (BINARY VARYING(4)) E: 00 (BINARY LARGE OBJECT) F:  (BINARY LARGE OBJECT(5))
-- A: NULL (BINARY(1)) B: NULL (BINARY(3)) C: NULL (BINARY VARYING(3)) D: NULL (BINARY VARYING(4)) E: NULL (BINARY LARGE OBJECT) F: NULL (BINARY LARGE OBJECT(5))

-- # A value that's too long is truncated if the extra octets are all X'00',
-- # otherwise it's 22001 (9.2, General Rules, 3.b).
CREATE TABLE t (a BINARY(2), b VARBINARY(2), c BLOB(2));
INSERT INTO t VALUES (X'010000', X'010200', X'01020000');
SELECT * FROM t;
INSERT INTO t (a) VALUES (X'010203');
INSERT INTO t (b) VALUES (X'000001');
INSERT INTO t (c) VALUES (X'01020304');
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- A: 0100 B: 0102 C: 0102
-- error 22001: string data right truncation for BINARY(2)
-- error 22001: string data right truncation for BINARY VARYING(2)
-- error 22001: string data right truncation for BINARY LARGE OBJECT(2)

-- # A binary string can only be stored in a binary string type.
CREATE TABLE t (a VARBINARY(10), b VARCHAR(10));
INSERT INTO t (a) VALUES ('ab');
INSERT INTO t (b) VALUES (X'0102');
INSERT INTO t (a) VALUES (12);
-- msg: CREATE TABLE 1
-- error 42846: cannot coerce CHARACTER(2) to BINARY VARYING(10)
-- error 42846: cannot coerce BINARY(2) to CHARACTER VARYING(10)
-- error 42846: cannot coerce SMALLINT to BINARY VARYING(10)

-- # The length must be at least 1, and a BINARY or BINARY VARYING can't be
-- # longer than 10485760 octets.
CREATE TABLE t (a BINARY(0));
-- error 42601: syntax error: BINARY length must be greater than 0

CREATE TABLE t (a VARBINARY(10485761));
-- error 42601: syntax error: BINARY VARYING length must not be greater than 10485760

CREATE TABLE t (a BINARY VARYING);
-- error 42601: syntax error: unexpected ")" at line 1, column 33 near "a BINARY VARYING)", expecting "("

-- # A binary string can be a PRIMARY KEY, and X'00' is ordered before any
-- # other octet.
CREATE TABLE t (a VARBINARY(4) PRIMARY KEY);
INSERT INTO t VALUES (X'01'), (X'0100'), (X''), (X'00'), (X'0001'), (X'FF');
SELECT * FROM t;
INSERT INTO t VALUES (X'0100');
-- msg: CREATE TABLE 1
-- msg: INSERT 6
-- A:
-- A: 00
-- A: 0001
-- A: 01
-- A: 0100
-- A: FF
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T

-- # The default can be a binary string literal.
CREATE TABLE t (a INT, b VARBINARY(4) DEFAULT X'CAFE');
INSERT INTO t (a) VALUES (1);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- A: 1 B: CAFE

CREATE TABLE t (a VARBINARY(1) DEFAULT X'CAFE');
-- error 42601: syntax error: DEFAULT X'CAFE' is not valid for column A BINARY VARYING(1)

-- # A CAST can be to another binary string type.
/* types */
VALUES CAST(X'0102' AS VARBINARY(5));
-- COL1: 0102 (BINARY VARYING(5))

/* types */
VALUES CAST(X'01' AS BINARY(3));
-- COL1: 010000 (BINARY(3))

/* types */
VALUES CAST(X'0102' AS BLOB);
-- COL1: 0102 (BINARY LARGE OBJECT)

VALUES CAST(X'01' AS VARCHAR(10));
-- error 42846: cannot coerce BINARY(1) to CHARACTER VARYING(10)

-- # A binary string can be in a UNIQUE constraint, which is checked with an
-- # index.
CREATE TABLE t (a VARBINARY(4) UNIQUE, b INT);
INSERT INTO t VALUES (X'00', 1), (X'0000', 2), (X'', 3), (X'01', 4);
INSERT INTO t VALUES (X'0000', 5);
-- msg: CREATE TABLE 1
-- msg: INSERT 4
-- error 23505: violates unique constraint: UNIQUE (A) on ":memory:".PUBLIC.T

-- # A binary string and an interval are shown as a literal.
/* extensions V001-01 */
EXPLAIN SELECT * FROM (VALUES ROW(1)) AS t (x) WHERE X'01' IS NOT NULL AND INTERVAL '1' DAY IS NOT NULL;
-- EXPLAIN: T:
-- EXPLAIN:   VALUES (X SMALLINT) = ROW(1)
-- EXPLAIN: TABLE T (X SMALLINT)
-- EXPLAIN: WHERE X'01' IS NOT NULL AND INTERVAL '1' DAY(2) IS NOT NULL
-- EXPLAIN: EXPR (T.X SMALLINT)

-- # An index on a binary string has its values in order, so it can be read in
-- # the order of an ORDER BY.
/* extensions V002-01 */
CREATE TABLE t (a VARBINARY(4), b INT);
INSERT INTO t VALUES (X'0100', 1), (X'00', 2), (X'', 3), (X'01', 4), (X'0001', 5);
CREATE INDEX t_a ON t (a DESC, b);
SELECT b FROM t ORDER BY a DESC, b;
-- msg: CREATE TABLE 1
-- msg: INSERT 5
-- msg: CREATE INDEX 1
-- B: 1
-- B: 4
-- B: 5
-- B: 2
-- B: 3
