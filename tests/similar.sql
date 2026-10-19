EXPLAIN VALUES 'a' SIMILAR TO 'a';
-- EXPLAIN: VALUES (COL1 BOOLEAN) = ROW('a' SIMILAR TO 'a')

VALUES 'a' SIMILAR TO 'a';
-- COL1: TRUE

VALUES 'a' SIMILAR TO 'A';
-- COL1: FALSE

VALUES 'a' SIMILAR TO 'aa';
-- COL1: FALSE

VALUES 'ab' SIMILAR TO 'a_';
-- COL1: TRUE

VALUES 'ab' NOT SIMILAR TO 'a_';
-- COL1: FALSE

VALUES 'abc' SIMILAR TO 'a_';
-- COL1: FALSE

VALUES 'abc' SIMILAR TO '_b_';
-- COL1: TRUE

VALUES 'abc' SIMILAR TO '%';
-- COL1: TRUE

VALUES 'abc' SIMILAR TO 'a%';
-- COL1: TRUE

VALUES 'abc' NOT SIMILAR TO 'a%';
-- COL1: FALSE

VALUES 'a' SIMILAR TO 'a%';
-- COL1: TRUE

VALUES 'ba' SIMILAR TO 'a%';
-- COL1: FALSE

VALUES 'ab' SIMILAR TO 'a%b';
-- COL1: TRUE

VALUES 'acb' SIMILAR TO 'a%b';
-- COL1: TRUE

VALUES 'acdeb' SIMILAR TO 'a%b';
-- COL1: TRUE

VALUES 'ab' NOT SIMILAR TO 'a%b';
-- COL1: FALSE

VALUES 'acb' NOT SIMILAR TO 'a%b';
-- COL1: FALSE

VALUES 'acdeb' NOT SIMILAR TO 'a%b';
-- COL1: FALSE

VALUES 'abd' SIMILAR TO 'a(b|c)d';
-- COL1: TRUE

VALUES 'abb' SIMILAR TO 'ab*';
-- COL1: TRUE

VALUES 'abb' SIMILAR TO 'ab+';
-- COL1: TRUE

VALUES 'abb' SIMILAR TO 'ab{2}';
-- COL1: TRUE

VALUES 'abab' SIMILAR TO '%b';
-- COL1: TRUE

VALUES 'abab' SIMILAR TO '%a%b';
-- COL1: TRUE

VALUES 'abab' SIMILAR TO '[ab]*b';
-- COL1: TRUE

VALUES 'abab' SIMILAR TO '%a';
-- COL1: FALSE

VALUES '' SIMILAR TO '_';
-- COL1: FALSE

VALUES '' SIMILAR TO '%';
-- COL1: TRUE

VALUES '' SIMILAR TO '';
-- COL1: TRUE

VALUES 'a' SIMILAR TO '';
-- COL1: FALSE

VALUES 'é' SIMILAR TO '_';
-- COL1: TRUE

VALUES 'aaa' SIMILAR TO 'a{2,}';
-- COL1: TRUE

VALUES 'a' SIMILAR TO 'a{2,}';
-- COL1: FALSE

VALUES 'aaa' SIMILAR TO 'a{2,3}';
-- COL1: TRUE

VALUES 'aaaa' SIMILAR TO 'a{2,3}';
-- COL1: FALSE

VALUES 'ac' SIMILAR TO 'ab?c';
-- COL1: TRUE

VALUES 'ab' SIMILAR TO '(a|ab)b';
-- COL1: TRUE

VALUES 'abb' SIMILAR TO '(a|ab)b';
-- COL1: TRUE

VALUES 'x' SIMILAR TO 'abc|x';
-- COL1: TRUE

VALUES 'b' SIMILAR TO '[^a]';
-- COL1: TRUE

VALUES 'a' SIMILAR TO '[^a]';
-- COL1: FALSE

VALUES 'x' SIMILAR TO '[a-z^x]';
-- COL1: FALSE

VALUES 'y' SIMILAR TO '[a-z^x]';
-- COL1: TRUE

VALUES 'A1' SIMILAR TO '[[:UPPER:]][[:DIGIT:]]';
-- COL1: TRUE

VALUES 'a1' SIMILAR TO '[[:UPPER:]][[:DIGIT:]]';
-- COL1: FALSE

VALUES 'a 1' SIMILAR TO '[[:ALPHA:]][[:SPACE:]][[:ALNUM:]]';
-- COL1: TRUE

VALUES 'a' SIMILAR TO '[[:lower:]]';
-- COL1: TRUE

VALUES 'a.b$}' SIMILAR TO 'a.b$}';
-- COL1: TRUE

VALUES 'a\b' SIMILAR TO 'a\b';
-- COL1: TRUE

VALUES 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' SIMILAR TO '(a|aa)*c';
-- COL1: FALSE

VALUES 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab' SIMILAR TO '(a*)*b';
-- COL1: TRUE

VALUES 'a' SIMILAR TO '(a';
-- error 2201B: invalid regular expression

VALUES 'a' SIMILAR TO 'a)';
-- error 2201B: invalid regular expression

VALUES 'a' SIMILAR TO '*a';
-- error 2201B: invalid regular expression

VALUES 'a' SIMILAR TO 'a**';
-- error 2201B: invalid regular expression

VALUES 'a' SIMILAR TO '[a';
-- error 2201B: invalid regular expression

VALUES 'a' SIMILAR TO 'a{0}';
-- error 2201B: invalid regular expression

VALUES 'a' SIMILAR TO 'a{3,2}';
-- error 2201B: invalid regular expression

VALUES 'a' SIMILAR TO '[[:FOO:]]';
-- error 2201B: invalid regular expression

VALUES 'a' SIMILAR TO 'a|';
-- error 2201B: invalid regular expression

VALUES 'a' SIMILAR TO '^a';
-- error 2201B: invalid regular expression

VALUES 'abc' SIMILAR TO 'abc';
-- COL1: TRUE

VALUES 'abc' SIMILAR TO '_b_';
-- COL1: TRUE

VALUES 'abc' SIMILAR TO '_A_';
-- COL1: FALSE

VALUES 'abc' SIMILAR TO '%(b|d)%';
-- COL1: TRUE

VALUES 'abc' SIMILAR TO '(b|c)%';
-- COL1: FALSE

VALUES 'AbcAbcdefgefg12efgefg12' SIMILAR TO '((Ab)?c)+d((efg)+(12))+';
-- COL1: TRUE

VALUES 'aaaaaab11111xy' SIMILAR TO 'a{6}_[0-9]{5}(x|y){2}';
-- COL1: TRUE

VALUES '$0.87' SIMILAR TO '$[0-9]+(.[0-9][0-9])?';
-- COL1: TRUE

VALUES 'abc' SIMILAR TO 'a.c';
-- COL1: FALSE
