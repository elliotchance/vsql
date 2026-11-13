-- # A <binary string literal> is two hexits for each octet, in either case
-- # (5.3, Syntax Rules, 6), and it's shown as uppercase hexits. Its declared type
-- # is implementation-defined (5.3, Syntax Rules, 20), vsql uses BINARY VARYING.
/* types */
VALUES X'0aFF';
VALUES x'00';
VALUES X'';
-- COL1: 0AFF (BINARY VARYING(2))
-- COL1: 00 (BINARY VARYING(1))
-- COL1:  (BINARY VARYING)

VALUES X'0';
-- error 42601: syntax error: binary string must have an even number of hexits: X'0'

VALUES X'0G';
-- error 42601: syntax error: invalid hexit in binary string: X'0G

VALUES X'00;
-- error 42601: syntax error: unterminated binary string: X'00

-- # Spaces in a literal (T024) are not supported.
VALUES X'00 11';
-- error 42601: syntax error: invalid hexit in binary string: X'00

-- # BINARY without a length is BINARY(1) (6.1, Syntax Rules, 5).
/* types */
CREATE TABLE t (a BINARY, b BINARY(3), c BINARY VARYING(4), d VARBINARY(5));
INSERT INTO t VALUES (X'01', X'02', X'03', X'04');
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- A: 01 (BINARY(1)) B: 020000 (BINARY(3)) C: 03 (BINARY VARYING(4)) D: 04 (BINARY VARYING(5))

CREATE TABLE t (a BINARY(0));
-- error 42601: syntax error: BINARY length must be greater than 0

CREATE TABLE t (a VARBINARY(0));
-- error 42601: syntax error: BINARY VARYING length must be greater than 0

CREATE TABLE t (a BINARY(10485760), b VARBINARY(10485760));
-- msg: CREATE TABLE 1

CREATE TABLE t (a BINARY(10485761));
-- error 42601: syntax error: BINARY length must not be greater than 10485760

VALUES CAST(X'00' AS VARBINARY(10485761));
-- error 42601: syntax error: BINARY VARYING length must not be greater than 10485760

-- # A BINARY(L) is padded with X'00's (9.2, General Rules, 3.b.x). A value that's
-- # too long is truncated if the extra octets are all X'00's, otherwise it's an
-- # error (9.2, General Rules, 3.b.ix and 3.b.xii).
CREATE TABLE t (a BINARY(2), b VARBINARY(2));
INSERT INTO t VALUES (X'', X'');
INSERT INTO t VALUES (X'010000', X'020000');
INSERT INTO t VALUES (X'010001', NULL);
INSERT INTO t VALUES (NULL, X'020001');
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- error 22001: string data right truncation for BINARY(2)
-- error 22001: string data right truncation for BINARY VARYING(2)
-- A: 0000 B:
-- A: 0100 B: 0200

-- # A binary string can only be assigned to a binary string.
CREATE TABLE t (a VARBINARY(2), b VARCHAR(2));
INSERT INTO t (a) VALUES ('a');
INSERT INTO t (b) VALUES (X'01');
INSERT INTO t (a) SELECT b FROM t;
INSERT INTO t (a) VALUES (1);
-- msg: CREATE TABLE 1
-- error 42846: cannot coerce CHARACTER(1) to BINARY VARYING(2)
-- error 42846: cannot coerce BINARY VARYING(1) to CHARACTER VARYING(2)
-- error 42846: cannot coerce CHARACTER VARYING(2) to BINARY VARYING(2)
-- error 42846: cannot coerce SMALLINT to BINARY VARYING(2)

-- # The DEFAULT of a binary string column must be a binary string that fits.
CREATE TABLE t (a BINARY(2) DEFAULT X'01', b VARBINARY(2) DEFAULT X'0102');
INSERT INTO t (a, b) VALUES (DEFAULT, DEFAULT);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- A: 0100 B: 0102

CREATE TABLE t (a VARBINARY(1) DEFAULT X'0102');
-- error 42601: syntax error: DEFAULT X'0102' is not valid for column A BINARY VARYING(1)

CREATE TABLE t (a VARBINARY(1) DEFAULT 'a');
-- error 42601: syntax error: DEFAULT 'a' is not valid for column A BINARY VARYING(1)

-- # A CHECK constraint can use binary strings.
CREATE TABLE t (a BINARY(2), b VARBINARY(2), CHECK (a <> b));
INSERT INTO t VALUES (X'01', X'02');
INSERT INTO t VALUES (X'01', X'0100');
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 23514: violates check constraint: CHECK (A <> B) on ":memory:".PUBLIC.T

-- # CAST between binary strings truncates with a warning, and pads a BINARY(L)
-- # with X'00's (6.13, General Rules, 13).
/* types */
VALUES CAST(X'AB' AS BINARY(3));
VALUES CAST(X'ABCD' AS BINARY);
VALUES CAST(X'ABCD' AS VARBINARY(1));
VALUES CAST(X'ABCD' AS VARBINARY(2));
VALUES CAST(NULL AS VARBINARY(2));
-- COL1: AB0000 (BINARY(3))
-- warning 01004: string data, right truncation
-- COL1: AB (BINARY(1))
-- warning 01004: string data, right truncation
-- COL1: AB (BINARY VARYING(1))
-- COL1: ABCD (BINARY VARYING(2))
-- COL1: NULL (BINARY VARYING(2))

-- # A binary string can't be cast to or from any other type (6.13, Syntax Rules,
-- # 6).
VALUES CAST('ab' AS VARBINARY(3));
VALUES CAST(X'AB' AS VARCHAR(3));
-- error 42846: cannot coerce CHARACTER(2) to BINARY VARYING(3)
-- error 42846: cannot coerce BINARY VARYING(1) to CHARACTER VARYING(3)

-- # Binary strings are compared octet by octet. If one is the start of the
-- # other, the shorter one is less, even if the rest is X'00's (8.2, General
-- # Rules, 5).
VALUES X'AB' = X'AB', X'AB' < X'AC', X'AB' > X'AA', X'AB' < X'AB00', X'' < X'00', X'FF' > X'0000';
-- COL1: TRUE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: TRUE

VALUES X'AB' = 'a';
-- error 42883: cannot compare BINARY VARYING(1) and CHARACTER(1)

VALUES X'AB' = 1;
-- error 42883: cannot compare BINARY VARYING(1) and SMALLINT

VALUES X'AB' = CAST(NULL AS VARBINARY(2));
-- COL1: UNKNOWN

-- # A binary string can be a key, and the keys are in the order of the values.
CREATE TABLE t (k VARBINARY(3) PRIMARY KEY, v VARBINARY(4));
INSERT INTO t VALUES (X'01', X'AABB'), (X'0100', X'00'), (X'', X'AB'), (X'00', NULL), (X'0001', X'0001'), (X'02', X'0000');
SELECT * FROM t;
SELECT * FROM t WHERE k > X'00' AND k < X'0100';
SELECT * FROM t WHERE k = X'0100';
-- msg: CREATE TABLE 1
-- msg: INSERT 6
-- K:  V: AB
-- K: 00 V: NULL
-- K: 0001 V: 0001
-- K: 01 V: AABB
-- K: 0100 V: 00
-- K: 02 V: 0000
-- K: 0001 V: 0001
-- K: 01 V: AABB
-- K: 0100 V: 00

CREATE TABLE t (k BINARY(2) PRIMARY KEY);
INSERT INTO t VALUES (X'01');
INSERT INTO t VALUES (X'0100');
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T

/* extensions V002-01 */
-- # An index on more than one column needs to find the end of each binary string
-- # in the key.
CREATE TABLE t (a VARBINARY(3), b INT);
INSERT INTO t VALUES (X'0100', 1), (X'01', 2), (X'00', 3), (X'0000', 4), (X'01', 0);
CREATE INDEX i ON t (a, b);
SELECT * FROM t WHERE a = X'01' AND b > 0;
SELECT * FROM t WHERE a >= X'00' AND a < X'01' ORDER BY a, b;
-- msg: CREATE TABLE 1
-- msg: INSERT 5
-- msg: CREATE INDEX 1
-- A: 01 B: 2
-- A: 00 B: 3
-- A: 0000 B: 4

CREATE TABLE p (k VARBINARY(2) PRIMARY KEY);
CREATE TABLE c (k BINARY(1) REFERENCES p (k));
INSERT INTO p VALUES (X'01');
INSERT INTO c VALUES (X'01');
INSERT INTO c VALUES (X'02');
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- error 23503: violates foreign key constraint: FOREIGN KEY (K) REFERENCES ":memory:".PUBLIC.P (K) on ":memory:".PUBLIC.C

CREATE TABLE t (v VARBINARY(2));
INSERT INTO t VALUES (X'AB'), (X'00'), (NULL), (X'AB'), (X'');
SELECT v, COUNT(*) FROM t GROUP BY v ORDER BY v;
SELECT MIN(v), MAX(v), COUNT(v) FROM t;
SELECT DISTINCT v FROM t ORDER BY v DESC;
-- msg: CREATE TABLE 1
-- msg: INSERT 5
-- V: NULL COL2: 1
-- V:  COL2: 1
-- V: 00 COL2: 1
-- V: AB COL2: 2
-- warning 01003: null value eliminated in set function
-- COL1:  COL2: AB COL3: 4
-- V: AB
-- V: 00
-- V:
-- V: NULL

-- # The result of combining binary strings is only a BINARY if they all are
-- # (9.5, Syntax Rules, 3.b).
/* types */
VALUES CAST(X'AB' AS BINARY(3)), CAST(X'ABCD' AS BINARY(2));
VALUES CAST(X'AB' AS BINARY(3)), X'ABCDEF01';
VALUES COALESCE(CAST(NULL AS VARBINARY(2)), X'01');
VALUES CASE WHEN TRUE THEN X'01' ELSE X'0203' END;
-- COL1: AB0000 (BINARY(3))
-- COL1: ABCD00 (BINARY(3))
-- COL1: AB0000 (BINARY VARYING(4))
-- COL1: ABCDEF01 (BINARY VARYING(4))
-- COL1: 01 (BINARY VARYING(2))
-- COL1: 01 (BINARY VARYING(2))

VALUES X'01', 'a';
-- error 42804: data type mismatch in row 2, column 1 of VALUES: expected BINARY VARYING(1) but got CHARACTER(1)

-- # <binary concatenation> is only a BINARY when both are (6.31, Syntax Rules,
-- # 6.a).
/* types */
VALUES CAST(X'01' AS BINARY(2)) || CAST(X'02' AS BINARY(1));
VALUES CAST(X'01' AS BINARY(2)) || X'02';
VALUES X'01' || CAST(NULL AS VARBINARY(2));
-- COL1: 010002 (BINARY(3))
-- COL1: 010002 (BINARY VARYING(3))
-- COL1: NULL (BINARY VARYING(3))

VALUES X'01' || 'a';
-- error 42883: operator does not exist: BINARY VARYING || CHARACTER

-- # The result can't be longer than the maximum length of a binary string.
/* types */
VALUES CAST(NULL AS VARBINARY(10485760)) || X'01';
-- COL1: NULL (BINARY VARYING(10485760))

VALUES CAST(NULL AS BINARY(10485760)) || CAST(NULL AS BINARY(1));
-- error 42601: syntax error: BINARY(10485761) is longer than the maximum length of 10485760

-- # 10485760 octets is the longest value, and only X'00's are removed from the
-- # end of one that's longer.
SELECT OCTET_LENGTH(a) FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (VALUES CAST(X'01020304050607080910' AS VARBINARY(10))) AS t0 (a)) AS t1 (a)) AS t2 (a)) AS t3 (a)) AS t4 (a)) AS s (a);
SELECT OCTET_LENGTH(a || X'0000') FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (VALUES CAST(X'01020304050607080910' AS VARBINARY(10))) AS t0 (a)) AS t1 (a)) AS t2 (a)) AS t3 (a)) AS t4 (a)) AS s (a);
SELECT OCTET_LENGTH(a || X'0001') FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (VALUES CAST(X'01020304050607080910' AS VARBINARY(10))) AS t0 (a)) AS t1 (a)) AS t2 (a)) AS t3 (a)) AS t4 (a)) AS s (a);
-- COL1: 10485760
-- COL1: 10485760
-- error 22001: string data right truncation for BINARY VARYING(10485760)

-- # OCTET_LENGTH and POSITION count octets (6.30, General Rules, 3).
VALUES OCTET_LENGTH(X'0001FF'), OCTET_LENGTH(CAST(X'01' AS BINARY(4))), OCTET_LENGTH(X'');
-- COL1: 3
-- COL1: 4
-- COL1: 0

VALUES POSITION(X'FF' IN X'00FF00FF'), POSITION(X'' IN X'01'), POSITION(X'02' IN X'01'), POSITION(X'00' IN CAST(X'01' AS BINARY(2)));
-- COL1: 2
-- COL1: 1
-- COL1: 0
-- COL1: 2

VALUES POSITION(X'01' IN 'a');
-- error 42883: function does not exist: POSITION(BINARY VARYING(1), CHARACTER(1))

-- # A binary string can be updated, and it's kept on disk.
CREATE TABLE t (k INT PRIMARY KEY, v VARBINARY(4));
INSERT INTO t VALUES (1, X'AB');
UPDATE t SET v = v || X'00FF' WHERE k = 1;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: UPDATE 1
-- K: 1 V: AB00FF

-- # The COLUMNS view has the length in octets of a binary string column.
CREATE TABLE t (a BINARY, b VARBINARY(10));
SELECT column_name, data_type, character_maximum_length, character_octet_length, character_set_name FROM information_schema.columns WHERE table_name = 'T';
-- msg: CREATE TABLE 1
-- COLUMN_NAME: A DATA_TYPE: BINARY CHARACTER_MAXIMUM_LENGTH: 1 CHARACTER_OCTET_LENGTH: 1 CHARACTER_SET_NAME: NULL
-- COLUMN_NAME: B DATA_TYPE: BINARY VARYING CHARACTER_MAXIMUM_LENGTH: 10 CHARACTER_OCTET_LENGTH: 10 CHARACTER_SET_NAME: NULL
