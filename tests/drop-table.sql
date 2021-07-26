DROP TABLE foo
-- error 42P01: no such table: FOO

CREATE TABLE foo (a FLOAT)
DROP TABLE foo
DROP TABLE foo
-- msg: CREATE TABLE 1
-- msg: DROP TABLE 1
-- error 42P01: no such table: FOO
