-- # LIKE is kept when it's shown.
/* extensions V001-01 */
EXPLAIN VALUES 'a' LIKE 'a';
-- EXPLAIN: VALUES (COL1 BOOLEAN) = ROW('a' LIKE 'a')

-- # Without wildcards the whole string must match, including its case.
VALUES 'a' LIKE 'a';
VALUES 'a' LIKE 'A';
VALUES 'a' LIKE 'aa';
-- COL1: TRUE
-- COL1: FALSE
-- COL1: FALSE

-- # _ matches exactly one character.
VALUES 'ab' LIKE 'a_';
VALUES 'ab' NOT LIKE 'a_';
VALUES 'abc' LIKE 'a_';
VALUES 'abc' LIKE '_b_';
-- COL1: TRUE
-- COL1: FALSE
-- COL1: FALSE
-- COL1: TRUE

-- # % matches any number of characters, including none.
VALUES 'abc' LIKE '%';
VALUES 'abc' LIKE 'a%';
VALUES 'abc' NOT LIKE 'a%';
VALUES 'a' LIKE 'a%';
VALUES 'ba' LIKE 'a%';
VALUES 'ab' LIKE 'a%b';
VALUES 'acb' LIKE 'a%b';
VALUES 'acdeb' LIKE 'a%b';
VALUES 'ab' NOT LIKE 'a%b';
VALUES 'acb' NOT LIKE 'a%b';
-- COL1: TRUE
-- COL1: TRUE
-- COL1: FALSE
-- COL1: TRUE
-- COL1: FALSE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: FALSE
-- COL1: FALSE

VALUES 'acdeb' NOT LIKE 'a%b';
-- COL1: FALSE

-- # % has to try every length, not stop at the first or last match.
VALUES 'abab' LIKE '%b';
VALUES 'abcabc' LIKE '%c';
VALUES 'abab' LIKE 'a%b';
VALUES 'aXbYab' LIKE 'a%b';
VALUES 'abab' LIKE '%a%b';
VALUES 'abab' LIKE '%a';
VALUES 'abc' LIKE '%b%';
VALUES 'abc' LIKE '%%c';
VALUES 'abcbd' LIKE '%b_';
-- COL1: TRUE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: FALSE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: TRUE

-- # The empty string only matches a pattern that can match no characters.
VALUES '' LIKE '_';
VALUES '' LIKE '%';
VALUES '' LIKE '';
VALUES 'a' LIKE '';
-- COL1: FALSE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: FALSE

-- # _ is one character, not one byte.
VALUES 'é' LIKE '_';
-- COL1: TRUE

-- # Every other character is itself, including those that are special in
-- # regular expressions.
VALUES 'a.c' LIKE 'a.c';
VALUES 'abc' LIKE 'a.c';
VALUES '$5^' LIKE '$5^';
VALUES 'a\b' LIKE 'a\b';
-- COL1: TRUE
-- COL1: FALSE
-- COL1: TRUE
-- COL1: TRUE

-- # Wildcards next to each other.
VALUES ROW('ab' LIKE '%_', 'ab' LIKE '_%', 'ab' LIKE '__', 'ab' LIKE '%%');
VALUES ROW('' LIKE '%_', 'a' LIKE '__', 'abc' LIKE '_%_', 'a' LIKE '_%_');
-- COL1: TRUE COL2: TRUE COL3: TRUE COL4: TRUE
-- COL1: FALSE COL2: FALSE COL3: TRUE COL4: FALSE

-- # Regular expression syntax (of SIMILAR) has no meaning in LIKE.
VALUES 'abd' LIKE 'a(b|c)d';
VALUES 'abb' LIKE 'ab*';
VALUES 'abb' LIKE 'ab+';
VALUES 'abb' LIKE 'ab{2}';
VALUES 'abc' LIKE '%(b|d)%';
VALUES 'AbcAbcdefgefg12efgefg12' LIKE '((Ab)?c)+d((efg)+(12))+';
VALUES 'aaaaaab11111xy' LIKE 'a{6}_[0-9]{5}(x|y){2}';
VALUES '$0.87' LIKE '$[0-9]+(.[0-9][0-9])?';
-- COL1: FALSE
-- COL1: FALSE
-- COL1: FALSE
-- COL1: FALSE
-- COL1: FALSE
-- COL1: FALSE
-- COL1: FALSE
-- COL1: FALSE

-- # The operands must be character strings (#780).
VALUES 1 LIKE 'a';
VALUES 'a' LIKE 1;
VALUES TRUE LIKE 'T%';
VALUES 'a' LIKE 'a' ESCAPE 1;
VALUES CAST(NULL AS INT) LIKE 'a';
-- error 42883: operator does not exist: INTEGER LIKE CHARACTER
-- error 42883: operator does not exist: CHARACTER LIKE INTEGER
-- error 42883: operator does not exist: BOOLEAN LIKE CHARACTER
-- error 42883: operator does not exist: CHARACTER LIKE INTEGER
-- error 42883: operator does not exist: INTEGER LIKE CHARACTER
