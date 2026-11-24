-- # A <binary concatenation> is a BINARY when both operands are, with the
-- # combined length (6.32, Syntax Rules, 6.a.iii).
/* types */
VALUES X'0102' || X'03';
-- COL1: 010203 (BINARY(3))

/* types */
VALUES X'' || X'';
-- COL1:  (BINARY(0))

-- # It's a BINARY VARYING when either operand is (6.32, Syntax Rules, 6.a.ii),
-- # and a BINARY LARGE OBJECT when either one is (6.32, Syntax Rules, 6.a.i).
/* types */
CREATE TABLE t (a BINARY(2), b VARBINARY(3), c BLOB(5), d BLOB);
INSERT INTO t VALUES (X'0100', X'02', X'0300', X'04');
SELECT a || a, a || b, b || a, b || b, a || c, c || b, c || c, c || d FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 01000100 (BINARY(4)) COL2: 010002 (BINARY VARYING(5)) COL3: 020100 (BINARY VARYING(5)) COL4: 0202 (BINARY VARYING(6)) COL5: 01000300 (BINARY LARGE OBJECT(7)) COL6: 030002 (BINARY LARGE OBJECT(8)) COL7: 03000300 (BINARY LARGE OBJECT(10)) COL8: 030004 (BINARY LARGE OBJECT)

-- # If either operand is NULL, the result is NULL (6.32, General Rules, 3.a).
/* types */
CREATE TABLE t (a VARBINARY(3));
INSERT INTO t VALUES (NULL);
SELECT a || X'01', X'01' || a FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: NULL (BINARY VARYING(4)) COL2: NULL (BINARY VARYING(4))

-- # A binary string can only be concatenated with another binary string.
VALUES X'01' || 'a';
-- error 42883: operator does not exist: BINARY || CHARACTER

VALUES 'a' || X'01';
-- error 42883: operator does not exist: CHARACTER || BINARY

-- # The concatenation of two BINARY can't be longer than the maximum length of
-- # a BINARY, so it's an error (6.32, Syntax Rules, 6.a.iii). A BINARY VARYING
-- # has the maximum length instead.
/* extensions V001-01 */
CREATE TABLE t (a VARBINARY(10485760), b BINARY(10485760), c BINARY(5242880));
EXPLAIN SELECT a || a, c || c FROM t;
SELECT b || X'01' FROM t;
-- msg: CREATE TABLE 1
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (A BINARY VARYING(10485760), B BINARY(10485760), C BINARY(5242880))
-- EXPLAIN: EXPR (COL1 BINARY VARYING(10485760), COL2 BINARY(10485760))
-- error 42601: syntax error: BINARY(10485761) is longer than the maximum length of 10485760

-- # 10485760 octets is the longest BINARY VARYING, and only X'00' octets are
-- # removed from the end of one that's longer (6.32, General Rules, 3.b.ii).
SELECT OCTET_LENGTH(a) FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (VALUES CAST(X'01020304050607080900' AS VARBINARY(10))) AS t0 (a)) AS t1 (a)) AS t2 (a)) AS t3 (a)) AS t4 (a)) AS s (a);
SELECT OCTET_LENGTH(a || X'0000') FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (VALUES CAST(X'01020304050607080900' AS VARBINARY(10))) AS t0 (a)) AS t1 (a)) AS t2 (a)) AS t3 (a)) AS t4 (a)) AS s (a);
SELECT OCTET_LENGTH(a || X'01') FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (VALUES CAST(X'01020304050607080900' AS VARBINARY(10))) AS t0 (a)) AS t1 (a)) AS t2 (a)) AS t3 (a)) AS t4 (a)) AS s (a);
-- COL1: 10485760
-- COL1: 10485760
-- error 22001: string data right truncation for BINARY VARYING(10485760)

-- # A large value is concatenated like any other.
CREATE TABLE t (a BLOB, b VARBINARY(200));
INSERT INTO t VALUES (X'0102030405060708090A0102030405060708090A0102030405060708090A0102030405060708090A0102030405060708090A0102030405060708090A0102030405060708090A0102030405060708090A', X'0102030405060708090A0102030405060708090A0102030405060708090A0102030405060708090A0102030405060708090A0102030405060708090A0102030405060708090A0102030405060708090A');
SELECT OCTET_LENGTH(a || b), OCTET_LENGTH(b || b), SUBSTRING(a || b FROM 79 FOR 4) FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 160 COL2: 160 COL3: 090A0102

-- # A <binary concatenation> is Feature T021, or T048 for a BINARY LARGE
-- # OBJECT.
/* flags */
VALUES X'01' || X'02';
-- flags: F641, F661, T021
-- COL1: 0102

/* flags */
VALUES CAST(X'01' AS BLOB) || X'02';
-- flags: F641, F661, T021, T045, T048
-- COL1: 0102
