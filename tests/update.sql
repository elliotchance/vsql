UPDATE foo SET a = 123
-- error: vdb.SQLState42P01: no such table: foo

CREATE TABLE foo (baz CHARACTER VARYING(10))
INSERT INTO foo (baz) VALUES ('hi')
INSERT INTO foo (baz) VALUES ('there')
UPDATE foo SET baz = 'hi'
UPDATE foo SET baz = 'other'
SELECT * FROM foo
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: UPDATE 1
-- msg: UPDATE 2
-- baz: other
-- baz: other

CREATE TABLE foo (baz FLOAT)
INSERT INTO foo (baz) VALUES (35)
INSERT INTO foo (baz) VALUES (78)
UPDATE foo SET baz = 100 WHERE baz = 35
UPDATE foo SET baz = 100 WHERE baz = 100
SELECT * FROM foo
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: UPDATE 1
-- msg: UPDATE 0
-- baz: 78
-- baz: 100
