CREATE TABLE foo (x BIGINT);
INSERT INTO foo (x) VALUES (-9223372036854775807);
INSERT INTO foo (x) VALUES (9223372036854775807);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- X: -9223372036854775807
-- X: 9223372036854775807
