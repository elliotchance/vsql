-- # The length of a character string type can be in CHARACTERS (the default)
-- # or OCTETS (T062, Syntax Rules, 9 and 16 and Conformance Rules, 23).
/* types */
/* flags */
CREATE TABLE t (a CHARACTER(3 CHARACTERS), b VARCHAR(4 OCTETS), c CHAR(4 OCTETS));
INSERT INTO t (a, b, c) VALUES ('é', 'éé', 'é');
SELECT a || '|', b || '|', c || '|', OCTET_LENGTH(b), OCTET_LENGTH(c) FROM t;
-- flags: T062
-- msg: CREATE TABLE 1
-- flags:
-- msg: INSERT 1
-- flags:
-- COL1: é  | (CHARACTER(4)) COL2: éé| (CHARACTER VARYING(5)) COL3: é  | (CHARACTER(5)) COL4: 4 (INTEGER) COL5: 4 (INTEGER)

-- # A string with more octets than the length is an error, unless the extra
-- # octets are spaces (9.2, General Rules, 3.b).
CREATE TABLE t (b VARCHAR(4 OCTETS), c CHAR(2 OCTETS));
INSERT INTO t (b) VALUES ('ééé');
INSERT INTO t (b) VALUES ('éé  ');
INSERT INTO t (c) VALUES ('é ');
INSERT INTO t (c) VALUES ('aé');
SELECT b || '|', c || '|' FROM t;
-- msg: CREATE TABLE 1
-- error 22001: string data right truncation for CHARACTER VARYING(4 OCTETS)
-- msg: INSERT 1
-- msg: INSERT 1
-- error 22001: string data right truncation for CHARACTER(2 OCTETS)
-- COL1: éé| COL2: NULL
-- COL1: NULL COL2: é|

-- # A cast to a length in octets cuts the string to the last whole character
-- # that fits, with a warning if it isn't spaces (6.13, General Rules, 11 and
-- # 12). A CHARACTER is padded with spaces to the length.
/* types */
VALUES ROW(CAST('aéb' AS VARCHAR(2 OCTETS)) || '|', CAST('aé' AS CHAR(5 OCTETS)) || '|');
-- warning 01004: string data, right truncation
-- COL1: a| (CHARACTER VARYING(3)) COL2: aé  | (CHARACTER(6))

-- # The type keeps its length units, and the length in octets is also its
-- # maximum length in characters (General Rules, 3).
CREATE TABLE t (b VARCHAR(4 OCTETS), a VARCHAR(4 CHARACTERS));
SELECT column_name, data_type, character_maximum_length, character_octet_length FROM information_schema.columns WHERE table_name = 'T';
-- msg: CREATE TABLE 1
-- COLUMN_NAME: B DATA_TYPE: CHARACTER VARYING CHARACTER_MAXIMUM_LENGTH: 4 CHARACTER_OCTET_LENGTH: 4
-- COLUMN_NAME: A DATA_TYPE: CHARACTER VARYING CHARACTER_MAXIMUM_LENGTH: 4 CHARACTER_OCTET_LENGTH: 16

VALUES CAST('a' AS CHAR(0 OCTETS));
-- error 42601: syntax error: CHARACTER length must be greater than 0
