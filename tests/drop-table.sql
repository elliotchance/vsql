DROP TABLE foo
-- error: vsql.SQLState42P01: no such table: foo

CREATE TABLE foo (a FLOAT)
DROP TABLE foo
DROP TABLE foo
-- msg: CREATE TABLE 1
-- msg: DROP TABLE 1
-- error: vsql.SQLState42P01: no such table: foo
