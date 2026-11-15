-- # SIMILAR TO is kept when it's shown.
/* extensions V001-01 */
EXPLAIN VALUES 'a' SIMILAR TO 'a';
-- EXPLAIN: VALUES (COL1 BOOLEAN) = ROW('a' SIMILAR TO 'a')

-- # The whole string must match, including its case. _ and % are the same
-- # as in LIKE.
VALUES 'a' SIMILAR TO 'a';
VALUES 'a' SIMILAR TO 'A';
VALUES 'a' SIMILAR TO 'aa';
VALUES 'ab' SIMILAR TO 'a_';
VALUES 'ab' NOT SIMILAR TO 'a_';
VALUES 'abc' SIMILAR TO 'a_';
VALUES 'abc' SIMILAR TO '_b_';
VALUES 'abc' SIMILAR TO '%';
VALUES 'abc' SIMILAR TO 'a%';
VALUES 'abc' NOT SIMILAR TO 'a%';
-- COL1: TRUE
-- COL1: FALSE
-- COL1: FALSE
-- COL1: TRUE
-- COL1: FALSE
-- COL1: FALSE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: FALSE

VALUES 'a' SIMILAR TO 'a%';
VALUES 'ba' SIMILAR TO 'a%';
VALUES 'ab' SIMILAR TO 'a%b';
VALUES 'acb' SIMILAR TO 'a%b';
VALUES 'acdeb' SIMILAR TO 'a%b';
VALUES 'ab' NOT SIMILAR TO 'a%b';
VALUES 'acb' NOT SIMILAR TO 'a%b';
VALUES 'acdeb' NOT SIMILAR TO 'a%b';
-- COL1: TRUE
-- COL1: FALSE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: FALSE
-- COL1: FALSE
-- COL1: FALSE

-- # Unlike LIKE, a pattern can have alternatives, groups and repetition.
VALUES 'abd' SIMILAR TO 'a(b|c)d';
VALUES 'abb' SIMILAR TO 'ab*';
VALUES 'abb' SIMILAR TO 'ab+';
VALUES 'abb' SIMILAR TO 'ab{2}';
VALUES 'abab' SIMILAR TO '%b';
VALUES 'abab' SIMILAR TO '%a%b';
VALUES 'abab' SIMILAR TO '[ab]*b';
VALUES 'abab' SIMILAR TO '%a';
-- COL1: TRUE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: FALSE

-- # The value is compared with PAD SPACE (see std_2_8_6_similar_pad_space.sql),
-- # so an empty string can match a pattern that needs one character, as a
-- # space. It's one character, not one byte.
VALUES '' SIMILAR TO '_';
VALUES '' SIMILAR TO '%';
VALUES '' SIMILAR TO '';
VALUES 'a' SIMILAR TO '';
VALUES 'é' SIMILAR TO '_';
-- COL1: TRUE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: FALSE
-- COL1: TRUE

-- # Repetition with bounds, and an optional item.
VALUES 'aaa' SIMILAR TO 'a{2,}';
VALUES 'a' SIMILAR TO 'a{2,}';
VALUES 'aaa' SIMILAR TO 'a{2,3}';
VALUES 'aaaa' SIMILAR TO 'a{2,3}';
VALUES 'ac' SIMILAR TO 'ab?c';
-- COL1: TRUE
-- COL1: FALSE
-- COL1: TRUE
-- COL1: FALSE
-- COL1: TRUE

-- # Every alternative is tried, not just the first that matches.
VALUES 'ab' SIMILAR TO '(a|ab)b';
VALUES 'abb' SIMILAR TO '(a|ab)b';
VALUES 'x' SIMILAR TO 'abc|x';
-- COL1: TRUE
-- COL1: TRUE
-- COL1: TRUE

-- # Character sets, negated with ^ only at the start, and with character
-- # classes, whose names can be in any case.
VALUES 'b' SIMILAR TO '[^a]';
VALUES 'a' SIMILAR TO '[^a]';
VALUES 'x' SIMILAR TO '[a-z^x]';
VALUES 'y' SIMILAR TO '[a-z^x]';
VALUES 'A1' SIMILAR TO '[[:UPPER:]][[:DIGIT:]]';
VALUES 'a1' SIMILAR TO '[[:UPPER:]][[:DIGIT:]]';
VALUES 'a 1' SIMILAR TO '[[:ALPHA:]][[:SPACE:]][[:ALNUM:]]';
VALUES 'a' SIMILAR TO '[[:lower:]]';
-- COL1: TRUE
-- COL1: FALSE
-- COL1: FALSE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: FALSE
-- COL1: TRUE
-- COL1: TRUE

-- # Characters that are special in other regular expressions are themselves.
VALUES 'a.b$}' SIMILAR TO 'a.b$}';
VALUES 'a\b' SIMILAR TO 'a\b';
-- COL1: TRUE
-- COL1: TRUE

-- # Patterns that take exponential time to backtrack still finish.
VALUES 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' SIMILAR TO '(a|aa)*c';
VALUES 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab' SIMILAR TO '(a*)*b';
-- COL1: FALSE
-- COL1: TRUE

-- # A pattern that isn't a valid regular expression is an error, including
-- # an empty alternative, a repetition of nothing or of zero, and ^ outside
-- # of a character set.
VALUES 'a' SIMILAR TO '(a';
VALUES 'a' SIMILAR TO 'a)';
VALUES 'a' SIMILAR TO '*a';
VALUES 'a' SIMILAR TO 'a**';
VALUES 'a' SIMILAR TO '[a';
VALUES 'a' SIMILAR TO 'a{0}';
VALUES 'a' SIMILAR TO 'a{3,2}';
VALUES 'aab' SIMILAR TO 'a{,2}b';
-- error 2201B: invalid regular expression
-- error 2201B: invalid regular expression
-- error 2201B: invalid regular expression
-- error 2201B: invalid regular expression
-- error 2201B: invalid regular expression
-- error 2201B: invalid regular expression
-- error 2201B: invalid regular expression
-- error 2201B: invalid regular expression

-- # A <low value> or <high value> can't have an underscore.
VALUES 'aaaaaaaaaa' SIMILAR TO 'a{1_0}';
VALUES 'a' SIMILAR TO 'a{1,1_0}';
VALUES 'a(' SIMILAR TO 'a(';
VALUES 'a' SIMILAR TO '[[:FOO:]]';
VALUES 'a' SIMILAR TO 'a|';
VALUES 'a' SIMILAR TO '^a';
-- error 2201B: invalid regular expression
-- error 2201B: invalid regular expression
-- error 2201B: invalid regular expression
-- error 2201B: invalid regular expression
-- error 2201B: invalid regular expression
-- error 2201B: invalid regular expression

-- # Patterns that combine everything above.
VALUES 'abc' SIMILAR TO 'abc';
VALUES 'abc' SIMILAR TO '_b_';
VALUES 'abc' SIMILAR TO '_A_';
VALUES 'abc' SIMILAR TO '%(b|d)%';
VALUES 'abc' SIMILAR TO '(b|c)%';
VALUES 'AbcAbcdefgefg12efgefg12' SIMILAR TO '((Ab)?c)+d((efg)+(12))+';
VALUES 'aaaaaab11111xy' SIMILAR TO 'a{6}_[0-9]{5}(x|y){2}';
VALUES '$0.87' SIMILAR TO '$[0-9]+(.[0-9][0-9])?';
VALUES 'abc' SIMILAR TO 'a.c';
VALUES 'a' SIMILAR TO '(a*){3}';
-- COL1: TRUE
-- COL1: TRUE
-- COL1: FALSE
-- COL1: TRUE
-- COL1: FALSE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: FALSE
-- COL1: TRUE

VALUES 'a b' SIMILAR TO 'a[[:WHITESPACE:]]b';
-- COL1: TRUE

-- # The operands must be character strings (#780).
VALUES 1 SIMILAR TO '1';
VALUES '1' SIMILAR TO 1;
VALUES TRUE SIMILAR TO 'T%';
VALUES '1' SIMILAR TO '1' ESCAPE 1;
VALUES CAST(NULL AS INT) SIMILAR TO '1';
-- error 42883: operator does not exist: SMALLINT SIMILAR TO CHARACTER
-- error 42883: operator does not exist: CHARACTER SIMILAR TO SMALLINT
-- error 42883: operator does not exist: BOOLEAN SIMILAR TO CHARACTER
-- error 42883: operator does not exist: CHARACTER SIMILAR TO SMALLINT
-- error 42883: operator does not exist: INTEGER SIMILAR TO CHARACTER
