CREATE TABLE foo (num FLOAT)
INSERT INTO foo (num) VALUES (13)
INSERT INTO foo (num) VALUES (27)
INSERT INTO foo (num) VALUES (35)
SELECT '='
SELECT * FROM foo WHERE num = 27
SELECT '!='
SELECT * FROM foo WHERE num != 13
SELECT '>'
SELECT * FROM foo WHERE num > 27
SELECT '>='
SELECT * FROM foo WHERE num >= 27
SELECT '<'
SELECT * FROM foo WHERE num < 27
SELECT '<='
SELECT * FROM foo WHERE num <= 27
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- col1: =
-- num: 27
-- col1: !=
-- num: 27
-- num: 35
-- col1: >
-- num: 35
-- col1: >=
-- num: 27
-- num: 35
-- col1: <
-- num: 13
-- col1: <=
-- num: 13
-- num: 27
