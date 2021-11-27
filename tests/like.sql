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
