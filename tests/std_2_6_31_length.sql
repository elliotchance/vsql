-- # The lengths are INTEGERs (Syntax Rules, 8).
/* types */
VALUES CHAR_LENGTH('hello Hello');
-- COL1: 11 (INTEGER)

/* types */
VALUES CHARACTER_LENGTH('hello Hello');
-- COL1: 11 (INTEGER)

/* types */
VALUES OCTET_LENGTH('hello Hello');
-- COL1: 11 (INTEGER)

-- # CHAR_LENGTH counts characters (General Rules, 5.b) and OCTET_LENGTH counts
-- # the bytes of the UTF-8 (General Rules, 6). Function names aren't case
-- # sensitive.
VALUES CHAR_LENGTH('😊£');
VALUES OCTET_LENGTH('😊£');
VALUES char_length('😊£');
-- COL1: 2
-- COL1: 6
-- COL1: 2

-- # A CHAR is padded with spaces to its length, and keeps them when it's
-- # concatenated (6.31, General Rules, 2.b.ii.3.C).
/* types */
VALUES CHAR_LENGTH(CAST('hello Hello' AS CHAR(30)));
-- COL1: 30 (INTEGER)

VALUES ROW(CHAR_LENGTH(CAST('a' AS CHAR(3)) || 'b'), UPPER(CAST('a' AS CHAR(3)) || 'b'));
-- COL1: 4 COL2: A  B

-- # USING OCTETS counts the octets of the UTF-8, like OCTET_LENGTH, and USING
-- # CHARACTERS is the same as without USING (Syntax Rules, 5.b). USING isn't
-- # restricted by a Conformance Rule, so it's Core SQL (E021-04).
/* flags */
VALUES CHAR_LENGTH('😊£a' USING OCTETS);
-- flags: F641, F661
-- COL1: 7

VALUES CHARACTER_LENGTH('😊£a' USING CHARACTERS);
VALUES char_length('😊£a' using octets);
-- COL1: 3
-- COL1: 7

/* types */
VALUES CHARACTER_LENGTH(CAST(NULL AS VARCHAR(10)) USING OCTETS);
-- COL1: NULL (INTEGER)

-- # A CHAR is padded with spaces, which are one octet each.
VALUES CHAR_LENGTH(CAST('é' AS CHAR(3)) USING OCTETS);
-- COL1: 4

-- # A CHARACTER LARGE OBJECT is counted the same way.
/* types */
CREATE TABLE t (a CLOB);
INSERT INTO t VALUES ('😊£abc');
SELECT CHAR_LENGTH(a USING OCTETS), CHAR_LENGTH(a USING CHARACTERS) FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 9 (INTEGER) COL2: 5 (INTEGER)

-- # A binary string doesn't have characters.
VALUES CHAR_LENGTH(X'0102' USING OCTETS);
-- error 42883: function does not exist: CHAR_LENGTH(BINARY(2))
