/* types */
VALUES UPPER(CAST('straße' AS VARCHAR(10)));
-- COL1: STRASSE (CHARACTER VARYING(10))

/* types */
VALUES LOWER(CAST('STRAẞE' AS VARCHAR(10)));
-- COL1: straße (CHARACTER VARYING(10))

VALUES UPPER(CAST('ﬃ' AS VARCHAR(3)));
-- COL1: FFI

VALUES CHARACTER_LENGTH(UPPER(CAST('ΐ' AS VARCHAR(3))));
-- COL1: 3

VALUES CHARACTER_LENGTH(LOWER(CAST('İ' AS VARCHAR(2))));
-- COL1: 2

VALUES UPPER('hello ñandú');
-- COL1: HELLO ÑANDÚ

VALUES LOWER('HELLO ÑANDÚ');
-- COL1: hello ñandú

VALUES UPPER('𐐨'), LOWER('𐐀');
-- COL1: 𐐀
-- COL1: 𐐨

VALUES UPPER('ǅ'), LOWER('ǅ');
-- COL1: Ǆ
-- COL1: ǆ

VALUES UPPER(CAST('ᾈ' AS VARCHAR(2))), LOWER('ᾈ');
-- COL1: ἈΙ
-- COL1: ᾀ

VALUES UPPER('€ⓐⅰ'), LOWER('€ⒶⅠ');
-- COL1: €ⓐⅰ
-- COL1: €ⒶⅠ

VALUES LOWER('ΣΑΣ');
-- COL1: σασ

VALUES UPPER(CAST(NULL AS VARCHAR(2)));
-- COL1: NULL

/* types */
VALUES UPPER('straße');
-- warning 01004: string data, right truncation
-- COL1: STRASS (CHARACTER(6))

/* types */
VALUES LOWER('İ');
-- warning 01004: string data, right truncation
-- COL1: i (CHARACTER(1))

/* types */
VALUES UPPER(CAST('ßa' AS VARCHAR(2)));
-- warning 01004: string data, right truncation
-- COL1: SS (CHARACTER VARYING(2))

/* types */
VALUES UPPER(CAST('ß ' AS VARCHAR(2)));
-- COL1: SS (CHARACTER VARYING(2))

/* types */
VALUES UPPER(CAST('ﬁ' AS CHARACTER(4)));
-- COL1: FI   (CHARACTER(4))

/* types */
VALUES UPPER(CAST('é' AS CHARACTER(3)));
-- COL1: É   (CHARACTER(3))

/* types */
VALUES UPPER(CURRENT_SCHEMA);
-- COL1: PUBLIC (CHARACTER VARYING)

CREATE TABLE t (a VARCHAR(2));
INSERT INTO t (a) VALUES ('ß');
INSERT INTO t (a) VALUES ('ßß');
SELECT a, UPPER(a) FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- warning 01004: string data, right truncation
-- A: ß COL2: SS
-- A: ßß COL2: SS

CREATE TABLE t (a VARCHAR(2));
INSERT INTO t (a) VALUES ('ß');
SELECT a FROM t WHERE UPPER(a) = 'SS';
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- A: ß
