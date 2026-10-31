VALUES 1 /* a comment */ + 2;
-- COL1: 3

VALUES 1/*no spaces*/+/**/2;
-- COL1: 3

VALUES /* a comment
that has more than one line, 'quotes', "identifiers" and -- minus signs
*/ 1;
-- COL1: 1

VALUES 1 /* a /* nested */ comment */ + 2;
-- COL1: 3

VALUES 1 /* /* /* */ */ */ + 2;
-- COL1: 3

VALUES 1 /*/ is not the end */ + 2;
-- COL1: 3

VALUES 1 -- a simple comment /* is not a bracketed comment
+ 2;
-- COL1: 3

VALUES ROW('/* not a comment */', "/*COL*/");
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC."/*COL*/"

VALUES ROW('/* not a comment */', 2);
-- COL1: /* not a comment */ COL2: 2

VALUES 'a' /* a comment between the parts */
  'b';
-- COL1: ab

VALUES 'a' /* the new line is in the
comment */ 'b';
-- COL1: ab

VALUES 'a' /* there is no new line */ 'b';
-- error 42601: syntax error: unexpected string

VALUES 4/*2;
-- error 42601: syntax error: unterminated comment: /*2

VALUES 1 /* a /* nested */ comment that doesn't end;
-- error 42601: syntax error: unterminated comment: /* a /* nested */ comment that doesn't end

VALUES 4/ *2;
-- error 42601: syntax error: unexpected "*"

 /* a statement that is only a comment */;
-- error 42601: syntax error: unexpected $end

 /* a comment */ /* and /* another */ one */
;
-- error 42601: syntax error: unexpected $end

EXPLAIN /* nothing to explain */;
-- error 42601: syntax error: unexpected $end
