-- # POSITION is where the first match starts, counting from 1, or 0 when
-- # there's no match (General Rules, 2.b and 2.c). Matching is case-sensitive.
-- # The result is an INTEGER (Syntax Rules, 1).
/* types */
VALUES POSITION('h' IN 'hello Hello');
-- COL1: 1 (INTEGER)

VALUES POSITION('l' IN 'hello Hello');
VALUES POSITION('H' IN 'hello Hello');
VALUES POSITION('llo' IN 'hello Hello');
-- COL1: 3
-- COL1: 7
-- COL1: 3

/* types */
VALUES POSITION('z' IN 'hello Hello');
-- COL1: 0 (INTEGER)

-- # An empty search string is always found at 1, even in an empty string
-- # (General Rules, 2.a).
VALUES ROW(POSITION('' IN 'abc'), POSITION('' IN ''), POSITION('a' IN ''));
-- COL1: 1 COL2: 1 COL3: 0

-- # Positions count characters, not octets.
VALUES POSITION('é' IN 'aébé');
-- COL1: 2

-- # USING OCTETS counts the position in octets of the UTF-8, and USING
-- # CHARACTERS is the same as without USING (General Rules, 2.b). USING isn't
-- # restricted by a Conformance Rule, so it's Core SQL (E021-11).
/* flags */
VALUES POSITION('b' IN 'aébé' USING OCTETS);
-- flags: F641, F661
-- COL1: 4

VALUES POSITION('b' IN 'aébé' USING CHARACTERS);
VALUES position('z' in 'aébé' using octets);
-- COL1: 3
-- COL1: 0

VALUES ROW(POSITION('' IN 'abc' USING OCTETS), POSITION('' IN '' USING OCTETS), POSITION('é' IN '😊é' USING OCTETS));
-- COL1: 1 COL2: 1 COL3: 5

/* types */
VALUES POSITION(CAST(NULL AS VARCHAR(10)) IN 'abc' USING OCTETS);
-- COL1: NULL (INTEGER)

-- # A CHARACTER LARGE OBJECT is counted the same way.
/* types */
CREATE TABLE t (a CLOB, b CLOB(10));
INSERT INTO t VALUES ('😊£abc', 'bc');
SELECT POSITION('a' IN a USING OCTETS), POSITION(b IN a USING OCTETS), POSITION(b IN a USING CHARACTERS) FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 7 (INTEGER) COL2: 8 (INTEGER) COL3: 4 (INTEGER)

-- # A binary string doesn't have characters, so it can't have USING (like
-- # SUBSTRING).
VALUES POSITION(X'02' IN X'0102' USING OCTETS);
-- error 42601: syntax error: POSITION of BINARY(1) IN BINARY(2) cannot have USING OCTETS
