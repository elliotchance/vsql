SELECT 1 AS bob;
-- BOB: 1

SELECT 1 AS "Bob";
-- Bob: 1

SELECT 'foo' || 'bar' AS Str;
-- STR: foobar

SELECT 1 + 2 AS total1, 3 + 4 AS total2;
-- TOTAL1: 3 TOTAL2: 7
