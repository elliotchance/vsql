VALUES 1 -- a comment
;
-- COL1: 1

VALUES 1 --- more minus signs, 'quotes' and "identifiers"
  + 2;
-- COL1: 3

VALUES 1--2
;
-- COL1: 1

VALUES ROW('--', 2);
-- COL1: -- COL2: 2

VALUES 'a' -- a comment between the parts
  'b';
-- COL1: ab

VALUES 'a' -- the new line is in the comment
'b';
-- COL1: ab

VALUES 'a' --'b'
;
-- COL1: a
