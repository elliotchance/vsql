CREATE TABLE foo (x INTEGER);
INSERT INTO foo (x) VALUES (-2147483649);
INSERT INTO foo (x) VALUES (-2147483648);
INSERT INTO foo (x) VALUES (2147483647);
INSERT INTO foo (x) VALUES (2147483648);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- error 22003: numeric value out of range
-- msg: INSERT 1
-- msg: INSERT 1
-- error 22003: numeric value out of range
-- X: -2147483648
-- X: 2147483647
