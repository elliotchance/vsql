-- # BINARY_TO_HEX and HEX_TO_BINARY are vsql extensions (V406-01 and V406-02)
-- # that convert a binary string to its hexadecimal digits and back. The
-- # standard has no CAST between a binary string and a character string.

-- # BINARY_TO_HEX has two upper case digits for each octet, the same way that
-- # a binary string is shown. A BINARY is padded with X'00'.
/* types */
VALUES ROW(BINARY_TO_HEX(X'CAFE'), BINARY_TO_HEX(X'0a1b'), BINARY_TO_HEX(X''));
-- COL1: CAFE (CHARACTER VARYING) COL2: 0A1B (CHARACTER VARYING) COL3:  (CHARACTER VARYING)

CREATE TABLE t (a BINARY(3), b VARBINARY(4), c BLOB);
INSERT INTO t VALUES (X'01', X'0102', X'010203');
INSERT INTO t VALUES (NULL, NULL, NULL);
SELECT BINARY_TO_HEX(a), BINARY_TO_HEX(b), BINARY_TO_HEX(c) FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- COL1: 010000 COL2: 0102 COL3: 010203
-- COL1: NULL COL2: NULL COL3: NULL

-- # A result that's longer than the longest CHARACTER VARYING (10485760
-- # characters) is an error.
VALUES CHAR_LENGTH(BINARY_TO_HEX(CAST(X'00' AS BINARY(5242880))));
-- COL1: 10485760

VALUES BINARY_TO_HEX(CAST(X'00' AS BINARY(5242881)));
-- error 22001: string data right truncation for CHARACTER VARYING(10485760)

-- # The BINARY_TO_HEX of a BINARY LARGE OBJECT is a CHARACTER LARGE OBJECT.
/* types */
VALUES BINARY_TO_HEX(CAST(X'FF' AS BLOB));
-- COL1: FF (CHARACTER LARGE OBJECT)

-- # HEX_TO_BINARY accepts upper or lower case digits, and is the opposite of
-- # BINARY_TO_HEX.
/* types */
VALUES ROW(HEX_TO_BINARY('CAFE'), HEX_TO_BINARY('0a1b'), HEX_TO_BINARY(''), HEX_TO_BINARY(BINARY_TO_HEX(X'00FF')));
-- COL1: CAFE (BINARY VARYING(10485760)) COL2: 0A1B (BINARY VARYING(10485760)) COL3:  (BINARY VARYING(10485760)) COL4: 00FF (BINARY VARYING(10485760))

CREATE TABLE t (a CHAR(4), b VARCHAR(4), c CLOB);
INSERT INTO t VALUES ('abcd', '01', '010203');
INSERT INTO t VALUES (NULL, NULL, NULL);
SELECT HEX_TO_BINARY(a), HEX_TO_BINARY(b), HEX_TO_BINARY(c) FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- COL1: ABCD COL2: 01 COL3: 010203
-- COL1: NULL COL2: NULL COL3: NULL

-- # The HEX_TO_BINARY of a CHARACTER LARGE OBJECT is a BINARY LARGE OBJECT.
/* types */
VALUES HEX_TO_BINARY(CAST('ff' AS CLOB));
-- COL1: FF (BINARY LARGE OBJECT)

-- # Anything that isn't pairs of hexadecimal digits is an error.
VALUES HEX_TO_BINARY('ABC');
-- error 22018: invalid character value for cast

VALUES HEX_TO_BINARY('0G');
-- error 22018: invalid character value for cast

VALUES HEX_TO_BINARY('G0');
-- error 22018: invalid character value for cast

VALUES HEX_TO_BINARY('CA FE');
-- error 22018: invalid character value for cast

VALUES HEX_TO_BINARY('x''CAFE''');
-- error 22018: invalid character value for cast

-- # Only strings can be converted.
VALUES BINARY_TO_HEX(123);
-- error 42883: function does not exist: BINARY_TO_HEX(SMALLINT)

VALUES HEX_TO_BINARY(X'CAFE');
-- error 42883: function does not exist: HEX_TO_BINARY(BINARY(2))

-- # The flagger.
/* flags */
VALUES ROW(BINARY_TO_HEX(X'CAFE'), HEX_TO_BINARY('CAFE'));
-- flags: F641, F661, T021, T051, V406-01, V406-02
-- COL1: CAFE COL2: CAFE
