/* setup */
CREATE TABLE foo (num FLOAT);
INSERT INTO foo (num) VALUES (13);
INSERT INTO foo (num) VALUES (27);
INSERT INTO foo (num) VALUES (35);

SELECT * FROM foo WHERE num = 27;
-- NUM: 27

SELECT * FROM foo WHERE num <> 13;
-- NUM: 27
-- NUM: 35

SELECT * FROM foo WHERE num > 27;
-- NUM: 35

SELECT * FROM foo WHERE num >= 27;
-- NUM: 27
-- NUM: 35

SELECT * FROM foo WHERE num < 27;
-- NUM: 13

SELECT * FROM foo WHERE num <= 27;
-- NUM: 13
-- NUM: 27
