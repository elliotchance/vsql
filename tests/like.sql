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
