CREATE TABLE foo (num FLOAT);
INSERT INTO foo (num) VALUES (13);
INSERT INTO foo (num) VALUES (27);
INSERT INTO foo (num) VALUES (35);
SELECT '=';
SELECT * FROM foo WHERE num = 27;
SELECT '!=';
SELECT * FROM foo WHERE num != 13;
SELECT '>';
SELECT * FROM foo WHERE num > 27;
SELECT '>=';
SELECT * FROM foo WHERE num >= 27;
SELECT '<';
SELECT * FROM foo WHERE num < 27;
SELECT '<=';
SELECT * FROM foo WHERE num <= 27;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- COL1: =
-- NUM: 27
-- COL1: !=
-- NUM: 27
-- NUM: 35
-- COL1: >
-- NUM: 35
-- COL1: >=
-- NUM: 27
-- NUM: 35
-- COL1: <
-- NUM: 13
-- COL1: <=
-- NUM: 13
-- NUM: 27
