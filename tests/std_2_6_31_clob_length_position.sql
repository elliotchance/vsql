-- # CHAR_LENGTH, OCTET_LENGTH and POSITION work on a CHARACTER LARGE OBJECT,
-- # like on any character string.
/* types */
CREATE TABLE t (a CLOB, b CLOB(10));
INSERT INTO t VALUES ('😊£abc', 'abc');
INSERT INTO t VALUES (NULL, NULL);
SELECT CHAR_LENGTH(a), CHARACTER_LENGTH(b), OCTET_LENGTH(a), POSITION('a' IN a), POSITION(b IN 'xabc'), POSITION(b IN a) FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- COL1: 5 (INTEGER) COL2: 3 (INTEGER) COL3: 9 (INTEGER) COL4: 3 (INTEGER) COL5: 2 (INTEGER) COL6: 3 (INTEGER)
-- COL1: NULL (INTEGER) COL2: NULL (INTEGER) COL3: NULL (INTEGER) COL4: NULL (INTEGER) COL5: NULL (INTEGER) COL6: NULL (INTEGER)

-- # A <char length expression>, <octet length expression> or <character
-- # position expression> of a CHARACTER LARGE OBJECT is Feature T050, and an
-- # <octet length expression> is also T047.
/* flags */
VALUES CHAR_LENGTH(CAST('ab' AS CLOB));
-- flags: F641, F661, T046, T050
-- COL1: 2

/* flags */
VALUES OCTET_LENGTH(CAST('ab' AS CLOB));
-- flags: F641, F661, T046, T047, T050
-- COL1: 2

/* flags */
VALUES POSITION('b' IN CAST('ab' AS CLOB));
-- flags: F641, F661, T046, T050
-- COL1: 2
