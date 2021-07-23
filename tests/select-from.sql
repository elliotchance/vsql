SELECT * FROM foo
-- error: vsql.SQLState42P01: no such table: foo

CREATE TABLE foo (a FLOAT)
INSERT INTO foo (a) VALUES (1.234)
SELECT * FROM foo
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- a: 1.234
