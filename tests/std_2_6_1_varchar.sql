-- # SUM needs a numeric argument (10.9, Syntax Rules, 7.g.i), so a VARCHAR is
-- # rejected, even when there are no rows to sum.
CREATE TABLE foo (x VARCHAR(10));
INSERT INTO foo (x) VALUES ('hello');
SELECT SUM(x) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 42883: function does not exist: SUM(CHARACTER VARYING(10))

CREATE TABLE foo (x VARCHAR(10));
SELECT SUM(x) FROM foo;
-- msg: CREATE TABLE 1
-- error 42883: function does not exist: SUM(CHARACTER VARYING(10))
