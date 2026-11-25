-- # BINARY_TO_BASE64 and BASE64_TO_BINARY are vsql extensions (V406-03 and
-- # V406-04) that convert a binary string to base64 (RFC 4648) and back.

-- # BINARY_TO_BASE64 has 4 characters for every 3 octets, with = padding, and
-- # no line breaks.
/* types */
VALUES ROW(BINARY_TO_BASE64(X'4D616E'), BINARY_TO_BASE64(X'4D61'), BINARY_TO_BASE64(X'4D'), BINARY_TO_BASE64(X''));
-- COL1: TWFu (CHARACTER VARYING) COL2: TWE= (CHARACTER VARYING) COL3: TQ== (CHARACTER VARYING) COL4:  (CHARACTER VARYING)

VALUES ROW(BINARY_TO_BASE64(X'FBFF'), BINARY_TO_BASE64(X'D34D'));
-- COL1: +/8= COL2: 000=

CREATE TABLE t (a BINARY(3), b VARBINARY(4), c BLOB);
INSERT INTO t VALUES (X'4D', X'4D61', X'4D616E');
INSERT INTO t VALUES (NULL, NULL, NULL);
SELECT BINARY_TO_BASE64(a), BINARY_TO_BASE64(b), BINARY_TO_BASE64(c) FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- COL1: TQAA COL2: TWE= COL3: TWFu
-- COL1: NULL COL2: NULL COL3: NULL

-- # A result that's longer than the longest CHARACTER VARYING (10485760
-- # characters) is an error.
VALUES CHAR_LENGTH(BINARY_TO_BASE64(CAST(X'00' AS BINARY(7864320))));
-- COL1: 10485760

VALUES BINARY_TO_BASE64(CAST(X'00' AS BINARY(7864321)));
-- error 22001: string data right truncation for CHARACTER VARYING(10485760)

-- # The BINARY_TO_BASE64 of a BINARY LARGE OBJECT is a CHARACTER LARGE OBJECT.
/* types */
VALUES BINARY_TO_BASE64(CAST(X'FF' AS BLOB));
-- COL1: /w== (CHARACTER LARGE OBJECT)

-- # BASE64_TO_BINARY is the opposite of BINARY_TO_BASE64.
/* types */
VALUES ROW(BASE64_TO_BINARY('TWFu'), BASE64_TO_BINARY('TWE='), BASE64_TO_BINARY('TQ=='), BASE64_TO_BINARY(''));
-- COL1: 4D616E (BINARY VARYING(10485760)) COL2: 4D61 (BINARY VARYING(10485760)) COL3: 4D (BINARY VARYING(10485760)) COL4:  (BINARY VARYING(10485760))

VALUES ROW(BASE64_TO_BINARY('+/8='), BASE64_TO_BINARY('000='), BASE64_TO_BINARY(BINARY_TO_BASE64(X'00FF10')));
-- COL1: FBFF COL2: D34D COL3: 00FF10

-- # The padding is optional, and whitespace (such as line breaks that other
-- # databases add) is ignored.
VALUES ROW(BASE64_TO_BINARY('TWE'), BASE64_TO_BINARY('TQ'), BASE64_TO_BINARY(' TW Fu TQ== '));
-- COL1: 4D61 COL2: 4D COL3: 4D616E4D

CREATE TABLE t (a CHAR(4), b VARCHAR(4), c CLOB);
INSERT INTO t VALUES ('TWFu', 'TQ==', 'TWE=');
INSERT INTO t VALUES (NULL, NULL, NULL);
SELECT BASE64_TO_BINARY(a), BASE64_TO_BINARY(b), BASE64_TO_BINARY(c) FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- COL1: 4D616E COL2: 4D COL3: 4D61
-- COL1: NULL COL2: NULL COL3: NULL

-- # The BASE64_TO_BINARY of a CHARACTER LARGE OBJECT is a BINARY LARGE OBJECT.
/* types */
VALUES BASE64_TO_BINARY(CAST('/w==' AS CLOB));
-- COL1: FF (BINARY LARGE OBJECT)

-- # A character that isn't base64 (including the URL-safe - and _), a single
-- # character in the last group, too much padding or anything after the padding
-- # is an error.
VALUES BASE64_TO_BINARY('TW-u');
-- error 22018: invalid character value for cast

VALUES BASE64_TO_BINARY('TW_u');
-- error 22018: invalid character value for cast

VALUES BASE64_TO_BINARY('TWFuT');
-- error 22018: invalid character value for cast

VALUES BASE64_TO_BINARY('TWFu=');
-- error 22018: invalid character value for cast

VALUES BASE64_TO_BINARY('TQ===');
-- error 22018: invalid character value for cast

VALUES BASE64_TO_BINARY('TQ==TQ==');
-- error 22018: invalid character value for cast

-- # Only strings can be converted.
VALUES BINARY_TO_BASE64('TWFu');
-- error 42883: function does not exist: BINARY_TO_BASE64(CHARACTER(4))

VALUES BASE64_TO_BINARY(X'4D');
-- error 42883: function does not exist: BASE64_TO_BINARY(BINARY(1))

-- # The flagger.
/* flags */
VALUES ROW(BINARY_TO_BASE64(X'4D'), BASE64_TO_BINARY('TQ=='));
-- flags: F641, F661, T021, T051, V406-03, V406-04
-- COL1: TQ== COL2: 4D
