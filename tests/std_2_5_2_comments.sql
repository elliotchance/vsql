-- # A simple comment starts with -- and runs to the end of the line, so the
-- # statement continues on the next line. More minus signs, quotes and double
-- # quotes are just part of the comment. The two minus signs can't be split
-- # (Syntax Rules, 8), and 1--2 is 1 followed by a comment, not 1 - -2. In a
-- # string literal, -- is just text.
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

-- # Adjacent string literals are joined when the separator between them has a
-- # line break (5.3, Syntax Rules, 1 and 7). A simple comment always ends with
-- # one, so it can sit between the parts. When the second literal is inside
-- # the comment there is nothing to join.
VALUES 'a' -- a comment between the parts
  'b';
-- COL1: ab

VALUES 'a' -- the new line is in the comment
'b';
-- COL1: ab

VALUES 'a' --'b'
;
-- COL1: a

-- # A statement that's only a comment, or only spaces, is empty, which is a
-- # syntax error.
 -- a statement that is only a comment
;
-- error 42601: syntax error: unexpected $end

  ;
-- error 42601: syntax error: unexpected $end
