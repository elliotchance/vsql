/* types */
VALUES '✌️';
-- COL1: ✌️ (CHARACTER(2))

/* types */
VALUES 'ぁ';
-- COL1: ぁ (CHARACTER(1))

/* types */
VALUES 'a <U+2022> character';
-- COL1: a • character (CHARACTER(13))

VALUES ROW(CHAR_LENGTH('ぁ'), OCTET_LENGTH('ぁ'));
-- COL1: 1 COL2: 3

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

/* types */
VALUES CAST('ぁぃぅ' AS VARCHAR(2));
-- warning 01004: string data, right truncation
-- COL1: ぁぃ (CHARACTER VARYING(2))

VALUES CHAR_LENGTH(CAST('ぁ' AS CHAR(3)));
-- COL1: 3

VALUES ROW(POSITION('b' IN 'Жabڣc'), POSITION('c' IN 'Жabڣc'));
-- COL1: 3 COL2: 5
