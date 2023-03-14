CREATE TABLE foo (x VARCHAR(10));
INSERT INTO foo (x) VALUES ('hello');
SELECT SUM(x) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 42883: function does not exist: SUM(CHARACTER VARYING)

CREATE TABLE foo (x VARCHAR(10));
SELECT SUM(x) FROM foo;
-- msg: CREATE TABLE 1
-- error 42883: function does not exist: SUM(CHARACTER VARYING)
