-- # A literal's length is in characters, not bytes (Syntax Rules, 17). ✌️ is
-- # two characters: the hand and a variation selector.
/* types */
VALUES '✌️';
-- COL1: ✌️ (CHARACTER(2))

/* types */
VALUES 'ぁ';
-- COL1: ぁ (CHARACTER(1))

/* types */
VALUES 'a <U+2022> character';
-- COL1: a • character (CHARACTER(13))

-- # CHAR_LENGTH counts characters while OCTET_LENGTH counts UTF-8 bytes.
VALUES ROW(CHAR_LENGTH('ぁ'), OCTET_LENGTH('ぁ'));
-- COL1: 1 COL2: 3

-- # A column's length is in characters too, so a 3 byte character fits in
-- # CHAR(1). Only extra spaces can be cut off when it's stored (9.2, General
-- # Rules, 3.b.ii.1 and 3.b.v.1), and anything else is an error (9.2, General
-- # Rules, 3.b.v.2). A short CHAR is padded with spaces (9.2, General Rules,
-- # 3.b.iii).
CREATE TABLE t (c CHAR(1), v VARCHAR(2));
INSERT INTO t (c, v) VALUES ('ぁ', 'ぁぃ');
SELECT c, v FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- C: ぁ V: ぁぃ

CREATE TABLE t (v VARCHAR(2));
INSERT INTO t (v) VALUES ('ぁぃぅ');
-- msg: CREATE TABLE 1
-- error 22001: string data right truncation for CHARACTER VARYING(2)

CREATE TABLE t (c CHAR(1), v VARCHAR(1));
INSERT INTO t (c, v) VALUES ('ぁ  ', 'ぁ  ');
SELECT c, CHAR_LENGTH(c), v, CHAR_LENGTH(v) FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- C: ぁ COL2: 1 V: ぁ COL4: 1

CREATE TABLE t (c CHAR(3));
INSERT INTO t (c) VALUES ('ぁ');
SELECT CHAR_LENGTH(c), OCTET_LENGTH(c) FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 3 COL2: 5

-- # A CAST can cut off characters, but only with a warning (6.13, General
-- # Rules, 12.d.ii).
/* types */
VALUES CAST('ぁぃぅ' AS VARCHAR(2));
-- warning 01004: string data, right truncation
-- COL1: ぁぃ (CHARACTER VARYING(2))

VALUES CHAR_LENGTH(CAST('ぁ' AS CHAR(3)));
-- COL1: 3

-- # POSITION counts characters, not bytes.
VALUES ROW(POSITION('b' IN 'Жabڣc'), POSITION('c' IN 'Жabڣc'));
-- COL1: 3 COL2: 5
