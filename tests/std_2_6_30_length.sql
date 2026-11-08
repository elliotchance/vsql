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
-- COL1: 2

VALUES OCTET_LENGTH('😊£');
-- COL1: 6

VALUES char_length('😊£');
-- COL1: 2

-- # A CHAR is padded with spaces to its length, and keeps them when it's
-- # concatenated (6.31, General Rules, 2.b.ii.3.C).
/* types */
VALUES CHAR_LENGTH(CAST('hello Hello' AS CHAR(30)));
-- COL1: 30 (INTEGER)

VALUES ROW(CHAR_LENGTH(CAST('a' AS CHAR(3)) || 'b'), UPPER(CAST('a' AS CHAR(3)) || 'b'));
-- COL1: 4 COL2: A  B
