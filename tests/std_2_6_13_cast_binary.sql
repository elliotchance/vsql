-- # A CAST to a binary string type truncates a value that's too long, with a
-- # warning, even if the octets that are removed are X'00' (6.13, General
-- # Rules, 13.a.ii and 13.b.ii). A BINARY is padded with X'00' (6.13, General
-- # Rules, 13.a.iii).
/* types */
VALUES CAST(X'010203' AS BINARY(2));
-- warning 01004: string data, right truncation
-- COL1: 0102 (BINARY(2))

/* types */
VALUES CAST(X'010000' AS VARBINARY(1));
-- warning 01004: string data, right truncation
-- COL1: 01 (BINARY VARYING(1))

/* types */
VALUES CAST(X'010203' AS BLOB(2));
-- warning 01004: string data, right truncation
-- COL1: 0102 (BINARY LARGE OBJECT(2))

/* types */
VALUES CAST(X'01' AS BINARY(3));
-- COL1: 010000 (BINARY(3))

/* types */
VALUES CAST(X'0102' AS VARBINARY(2));
-- COL1: 0102 (BINARY VARYING(2))

-- # A large value that fits is kept as it is.
/* types */
CREATE TABLE t (a BLOB);
INSERT INTO t VALUES (X'0102030405060708090A0102030405060708090A0102030405060708090A0102030405060708090A0102030405060708090A0102030405060708090A0102030405060708090A0102030405060708090A');
SELECT OCTET_LENGTH(CAST(a AS BLOB(100))), OCTET_LENGTH(CAST(a AS BLOB(10))), CAST(a AS VARBINARY(3)) FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- COL1: 80 (INTEGER) COL2: 10 (INTEGER) COL3: 010203 (BINARY VARYING(3))
