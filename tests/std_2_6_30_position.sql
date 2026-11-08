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

VALUES ROW(POSITION('' IN 'abc'), POSITION('' IN ''), POSITION('a' IN ''));
-- COL1: 1 COL2: 1 COL3: 0

VALUES POSITION('é' IN 'aébé');
-- COL1: 2
