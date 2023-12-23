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
