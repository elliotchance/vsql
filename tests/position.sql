VALUES POSITION('h' IN 'hello Hello');
-- COL1: 1

VALUES POSITION('l' IN 'hello Hello');
-- COL1: 3

VALUES POSITION('H' IN 'hello Hello');
-- COL1: 7

VALUES POSITION('llo' IN 'hello Hello');
-- COL1: 3

VALUES POSITION('z' IN 'hello Hello');
-- COL1: 0
