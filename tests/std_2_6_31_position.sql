-- # POSITION is where the first match starts, counting from 1, or 0 when
-- # there's no match (General Rules, 2.b and 2.c). Matching is case-sensitive.
-- # The result is an INTEGER (Syntax Rules, 1).
/* types */
VALUES POSITION('h' IN 'hello Hello');
-- COL1: 1 (INTEGER)

VALUES POSITION('l' IN 'hello Hello');
-- COL1: 3

VALUES POSITION('H' IN 'hello Hello');
-- COL1: 7

VALUES POSITION('llo' IN 'hello Hello');
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
