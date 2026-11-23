-- # A <binary position expression> is the position of the first octet of one
-- # binary string in another, or 0 (zero) if it isn't found (6.31, General
-- # Rules, 3.b and 3.c). A zero-length string is at 1 (6.31, General Rules,
-- # 3.a).
/* types */
VALUES POSITION(X'0304' IN X'0102030403');
-- COL1: 3 (INTEGER)

VALUES POSITION(X'05' IN X'01020304');
-- COL1: 0

VALUES POSITION(X'' IN X'');
-- COL1: 1

VALUES POSITION(X'' IN X'0102');
-- COL1: 1

-- # A BINARY is padded with X'00', which can be found.
CREATE TABLE t (a BINARY(4), b BLOB, c VARBINARY(3));
INSERT INTO t VALUES (X'01', X'000102', X'0102');
SELECT POSITION(X'00' IN a), POSITION(c IN b), POSITION(b IN c), POSITION(b IN b) FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 2 COL2: 2 COL3: 0 COL4: 1

-- # The result is NULL if either is NULL.
VALUES POSITION(CAST(NULL AS VARBINARY(2)) IN X'01');
-- COL1: NULL

-- # Both must be binary strings, or both character strings.
VALUES POSITION('a' IN X'01');
-- error 42883: function does not exist: POSITION(CHARACTER(1), BINARY(1))

-- # A <binary position expression> is Feature T021, or T047 for a BINARY LARGE
-- # OBJECT.
/* flags */
VALUES POSITION(X'02' IN X'0102');
-- flags: F641, F661, T021
-- COL1: 2

/* flags */
VALUES POSITION(X'02' IN CAST(X'0102' AS BLOB));
-- flags: F641, F661, T021, T045, T047
-- COL1: 2
