-- # There are some special tokens that are required to reduce the ambiguity for
-- # the parser. These tests ensure different whitespace combinations don't
-- # interfere with that.

-- # count(*) parses the same with or without spaces around the parentheses
-- # and the asterisk, because any token can be followed by a separator
-- # (Syntax Rules, 7). The table doesn't exist, so each one fails, but not
-- # with a syntax error.
SELECT x, count(*) FROM foo;
SELECT x, count( * ) FROM foo;
SELECT x, count (*) FROM foo;
SELECT x, count ( *) FROM foo;
-- error 42P01: no such table: ":memory:".PUBLIC.FOO
-- error 42P01: no such table: ":memory:".PUBLIC.FOO
-- error 42P01: no such table: ":memory:".PUBLIC.FOO
-- error 42P01: no such table: ":memory:".PUBLIC.FOO
