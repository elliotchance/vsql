-- # T351 Bracketed comments: a simple comment and the contents of a string
-- # aren't bracketed comments.
/* flags */
VALUES /* a comment */ 1;
-- flags: F641, F661, T351
-- COL1: 1

/* flags */
VALUES 1 /* a /* nested */ comment */;
-- flags: F641, F661, T351
-- COL1: 1

/* flags */
VALUES -- a simple comment /* is not a bracketed comment
1;
-- flags: F641, F661
-- COL1: 1

/* flags */
VALUES '/* not a comment */';
-- flags: F641, F661
-- COL1: /* not a comment */

/* flags */
VALUES 'a' /* between the parts of a literal */
'b';
-- flags: F271, F641, F661, T351
-- COL1: ab

/* flags */
VALUES 'a' -- a simple comment
'b';
-- flags: F271, F641, F661
-- COL1: ab

-- # A bracketed comment can go anywhere a separator can, with or without
-- # spaces around it, and can span lines. A /* inside one starts a nested
-- # comment that needs its own */ (Syntax Rules, 10). In /*/ the solidus
-- # belongs to the introducer, so it isn't an end. After -- the rest of the
-- # line is a simple comment, so a /* there doesn't start anything.
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

-- # Inside a string literal or a delimited identifier, /* is just part of
-- # the text. So "/*COL*/" is a column name, and there isn't one.
VALUES ROW('/* not a comment */', "/*COL*/");
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC."/*COL*/"

VALUES ROW('/* not a comment */', 2);
-- COL1: /* not a comment */ COL2: 2

-- # Adjacent string literals are joined, but only when the separator between
-- # them has a line break (5.3, Syntax Rules, 1 and 7). The line break can be
-- # in the comment. vsql doesn't count the comment itself as the line break,
-- # so two literals on one line are still a syntax error.
VALUES 'a' /* a comment between the parts */
  'b';
-- COL1: ab

VALUES 'a' /* the new line is in the
comment */ 'b';
-- COL1: ab

VALUES 'a' /* there is no new line */ 'b';
-- error 42601: syntax error: unexpected string

-- # A comment that isn't closed is an error, including when a nested comment
-- # is closed but the outer one isn't. "/ *" with a space is a divide followed
-- # by an unexpected "*", not a comment.
VALUES 4/*2;
-- error 42601: syntax error: unterminated comment: /*2

VALUES 1 /* a /* nested */ comment that doesn't end;
-- error 42601: syntax error: unterminated comment: /* a /* nested */ comment that doesn't end

VALUES 4/ *2;
-- error 42601: syntax error: unexpected "*"

-- # A statement that's only comments is empty, which is a syntax error.
 /* a statement that is only a comment */;
-- error 42601: syntax error: unexpected $end

 /* a comment */ /* and /* another */ one */
;
-- error 42601: syntax error: unexpected $end

EXPLAIN /* nothing to explain */;
-- error 42601: syntax error: unexpected $end
