CREATE TABLE foo (x SMALLINT);
INSERT INTO foo (x) VALUES (-32769);
INSERT INTO foo (x) VALUES (-32768);
INSERT INTO foo (x) VALUES (32767);
INSERT INTO foo (x) VALUES (32768);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- error 22003: numeric value out of range
-- msg: INSERT 1
-- msg: INSERT 1
-- error 22003: numeric value out of range
-- X: -32768
-- X: 32767
