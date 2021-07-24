CREATE TABLE foo (a FLOAT)
INSERT INTO foo (a) VALUES (1.23)
-- msg: CREATE TABLE 1
-- msg: INSERT 1

CREATE TABLE foo (a FLOAT)
INSERT INTO foo (a) VALUES (101)
INSERT INTO foo (a) VALUES (102)
SELECT * FROM foo
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- A: 101
-- A: 102

CREATE TABLE foo (b BOOLEAN)
INSERT INTO foo (b) VALUES (true)
INSERT INTO foo (b) VALUES (false)
INSERT INTO foo (b) VALUES (unknown)
SELECT * FROM foo
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- B: TRUE
-- B: FALSE
-- B: UNKNOWN

CREATE TABLE foo (b BOOLEAN)
INSERT INTO foo (b) VALUES (123, 456)
-- msg: CREATE TABLE 1
-- error: vsql.SQLState42601: syntax error: INSERT has more values than columns

CREATE TABLE foo (b BOOLEAN, c INT)
INSERT INTO foo (b, c) VALUES (123)
-- msg: CREATE TABLE 1
-- error: vsql.SQLState42601: syntax error: INSERT has less values than columns

INSERT INTO foo (b) VALUES (123)
-- error: vsql.SQLState42P01: no such table: FOO

CREATE TABLE foo (b BOOLEAN)
INSERT INTO foo (c) VALUES (true)
-- msg: CREATE TABLE 1
-- error: vsql.SQLState42703: no such column: C

CREATE TABLE foo (b BOOLEAN)
INSERT INTO foo (b) VALUES (123)
-- msg: CREATE TABLE 1
-- error: vsql.SQLState42804: data type mismatch for column B: expected BOOLEAN but got INTEGER
