-- # The full Unicode case mappings are used (General Rules, 7.d), so one
-- # character can become several, like ß to SS. These types are long enough
-- # for the whole result.
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

-- # Characters outside the Basic Multilingual Plane are mapped too.
VALUES UPPER('𐐨'), LOWER('𐐀');
-- COL1: 𐐀
-- COL1: 𐐨

-- # A title case character has both an upper and a lower case mapping, and
-- # one with an iota subscript becomes two characters in upper case.
VALUES UPPER('ǅ'), LOWER('ǅ');
-- COL1: Ǆ
-- COL1: ǆ

VALUES UPPER(CAST('ᾈ' AS VARCHAR(2))), LOWER('ᾈ');
-- COL1: ἈΙ
-- COL1: ᾀ

-- # Only letters are mapped. Unicode gives ⓐ and ⅰ case mappings, but they're
-- # a symbol and a number, so they're unchanged.
VALUES UPPER('€ⓐⅰ'), LOWER('€ⒶⅠ');
-- COL1: €ⓐⅰ
-- COL1: €ⒶⅠ

-- # Each character is mapped on its own, so a final Σ becomes σ, not ς.
VALUES LOWER('ΣΑΣ');
-- COL1: σασ

-- # NULL gives NULL (General Rules, 7.b).
VALUES UPPER(CAST(NULL AS VARCHAR(2)));
-- COL1: NULL

-- # The result has the type of the argument (Syntax Rules, 9), so a longer
-- # result is cut to that length, with a warning unless only spaces are cut
-- # (General Rules, 7.g.ii). A shorter CHARACTER is padded with spaces (General
-- # Rules, 7.g.i).
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

-- # CURRENT_SCHEMA is a CHARACTER VARYING with no maximum length (6.4, Syntax
-- # Rules, 4), so nothing is cut.
/* types */
VALUES UPPER(CURRENT_SCHEMA);
-- COL1: PUBLIC (CHARACTER VARYING)

-- # A CHARACTER VARYING(2) column: ß fits as SS, but SSSS from ßß is cut to SS
-- # with a warning.
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

-- # UPPER can be used in a WHERE, so ß matches 'SS'.
CREATE TABLE t (a VARCHAR(2));
INSERT INTO t (a) VALUES ('ß');
SELECT a FROM t WHERE UPPER(a) = 'SS';
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- A: ß
