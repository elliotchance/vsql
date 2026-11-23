-- # The OCTET_LENGTH of a binary string is its number of octets (6.31, General
-- # Rules, 6). A BINARY is padded with X'00'.
/* types */
VALUES OCTET_LENGTH(X'010203');
-- COL1: 3 (INTEGER)

VALUES OCTET_LENGTH(X'');
-- COL1: 0

CREATE TABLE t (a BINARY(4), b VARBINARY(4), c BLOB);
INSERT INTO t VALUES (X'01', X'01', X'0102');
INSERT INTO t VALUES (NULL, NULL, NULL);
SELECT OCTET_LENGTH(a), OCTET_LENGTH(b), OCTET_LENGTH(c) FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- COL1: 4 COL2: 1 COL3: 2
-- COL1: NULL COL2: NULL COL3: NULL

-- # An <octet length expression> of a BINARY LARGE OBJECT is Feature T047.
/* flags */
VALUES OCTET_LENGTH(CAST(X'0102' AS BLOB));
-- flags: F641, F661, T021, T045, T047
-- COL1: 2
