SELECT 1 + 2;
-- COL1: 3

SELECT 1 - 2;
-- COL1: -1

SELECT 2 * 3;
-- COL1: 6

SELECT 6 / 2;
-- COL1: 3

SELECT 1.2 + 2.4;
-- COL1: 3.6

SELECT 1.7 - 0.5;
-- COL1: 1.2

SELECT 2.2 * 3.3;
-- COL1: 7.26

SELECT 6 / 2.5;
-- COL1: 2.4

SELECT 0 / 2.5;
-- COL1: 0

SELECT 2.5 / 0;
-- error 22012: division by zero

SELECT -123;
-- COL1: -123

SELECT +1.23;
-- COL1: 1.23

SELECT 1.5 + 2.4 * 7;
-- COL1: 18.3
