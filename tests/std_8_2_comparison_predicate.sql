-- # 8.2 <comparison predicate>

-- # General Rules: 3, b:
-- # [E021-12]
VALUES ROW(1, 'hello' = 'hello   ');
VALUES ROW(2, 'hello  ' = 'hello');
VALUES ROW(3, 'hello  ' = 'hello  ');
VALUES ROW(4, '  hello' = 'hello');
VALUES ROW(5, 'hello' = '  hello');
VALUES ROW(6, '  hello' = '  hello');
-- COL1: 1 COL2: TRUE
-- COL1: 2 COL2: TRUE
-- COL1: 3 COL2: TRUE
-- COL1: 4 COL2: FALSE
-- COL1: 5 COL2: FALSE
-- COL1: 6 COL2: TRUE
