/* types */
VALUES CHAR_LENGTH('hello Hello');
-- COL1: 11 (INTEGER)

/* types */
VALUES CHARACTER_LENGTH('hello Hello');
-- COL1: 11 (INTEGER)

/* types */
VALUES OCTET_LENGTH('hello Hello');
-- COL1: 11 (INTEGER)

VALUES CHAR_LENGTH('😊£');
-- COL1: 2

VALUES OCTET_LENGTH('😊£');
-- COL1: 6

VALUES char_length('😊£');
-- COL1: 2

/* types */
VALUES CHAR_LENGTH(CAST('hello Hello' AS CHAR(30)));
-- COL1: 30 (INTEGER)

VALUES ROW(CHAR_LENGTH(CAST('a' AS CHAR(3)) || 'b'), UPPER(CAST('a' AS CHAR(3)) || 'b'));
-- COL1: 4 COL2: A  B
