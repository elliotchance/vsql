/* extensions V001-01 */
EXPLAIN VALUES 'a' LIKE 'a';
-- EXPLAIN: VALUES (COL1 BOOLEAN) = ROW('a' LIKE 'a')

VALUES 'a' LIKE 'a';
-- COL1: TRUE

VALUES 'a' LIKE 'A';
-- COL1: FALSE

VALUES 'a' LIKE 'aa';
-- COL1: FALSE

VALUES 'ab' LIKE 'a_';
-- COL1: TRUE

VALUES 'ab' NOT LIKE 'a_';
-- COL1: FALSE

VALUES 'abc' LIKE 'a_';
-- COL1: FALSE

VALUES 'abc' LIKE '_b_';
-- COL1: TRUE

VALUES 'abc' LIKE '%';
-- COL1: TRUE

VALUES 'abc' LIKE 'a%';
-- COL1: TRUE

VALUES 'abc' NOT LIKE 'a%';
-- COL1: FALSE

VALUES 'a' LIKE 'a%';
-- COL1: TRUE

VALUES 'ba' LIKE 'a%';
-- COL1: FALSE

VALUES 'ab' LIKE 'a%b';
-- COL1: TRUE

VALUES 'acb' LIKE 'a%b';
-- COL1: TRUE

VALUES 'acdeb' LIKE 'a%b';
-- COL1: TRUE

VALUES 'ab' NOT LIKE 'a%b';
-- COL1: FALSE

VALUES 'acb' NOT LIKE 'a%b';
-- COL1: FALSE

VALUES 'acdeb' NOT LIKE 'a%b';
-- COL1: FALSE

VALUES 'abab' LIKE '%b';
-- COL1: TRUE

VALUES 'abcabc' LIKE '%c';
-- COL1: TRUE

VALUES 'abab' LIKE 'a%b';
-- COL1: TRUE

VALUES 'aXbYab' LIKE 'a%b';
-- COL1: TRUE

VALUES 'abab' LIKE '%a%b';
-- COL1: TRUE

VALUES 'abab' LIKE '%a';
-- COL1: FALSE

VALUES 'abc' LIKE '%b%';
-- COL1: TRUE

VALUES 'abc' LIKE '%%c';
-- COL1: TRUE

VALUES 'abcbd' LIKE '%b_';
-- COL1: TRUE

VALUES '' LIKE '_';
-- COL1: FALSE

VALUES '' LIKE '%';
-- COL1: TRUE

VALUES '' LIKE '';
-- COL1: TRUE

VALUES 'a' LIKE '';
-- COL1: FALSE

VALUES 'é' LIKE '_';
-- COL1: TRUE

VALUES 'a.c' LIKE 'a.c';
-- COL1: TRUE

VALUES 'abc' LIKE 'a.c';
-- COL1: FALSE

VALUES '$5^' LIKE '$5^';
-- COL1: TRUE

VALUES 'a\b' LIKE 'a\b';
-- COL1: TRUE

VALUES ROW('ab' LIKE '%_', 'ab' LIKE '_%', 'ab' LIKE '__', 'ab' LIKE '%%');
-- COL1: TRUE COL2: TRUE COL3: TRUE COL4: TRUE

VALUES ROW('' LIKE '%_', 'a' LIKE '__', 'abc' LIKE '_%_', 'a' LIKE '_%_');
-- COL1: FALSE COL2: FALSE COL3: TRUE COL4: FALSE

VALUES 'abd' LIKE 'a(b|c)d';
-- COL1: FALSE

VALUES 'abb' LIKE 'ab*';
-- COL1: FALSE

VALUES 'abb' LIKE 'ab+';
-- COL1: FALSE

VALUES 'abb' LIKE 'ab{2}';
-- COL1: FALSE

VALUES 'abc' LIKE '%(b|d)%';
-- COL1: FALSE

VALUES 'AbcAbcdefgefg12efgefg12' LIKE '((Ab)?c)+d((efg)+(12))+';
-- COL1: FALSE

VALUES 'aaaaaab11111xy' LIKE 'a{6}_[0-9]{5}(x|y){2}';
-- COL1: FALSE

VALUES '$0.87' LIKE '$[0-9]+(.[0-9][0-9])?';
-- COL1: FALSE
