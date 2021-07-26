DELETE FROM foo;
-- error 42P01: no such table: FOO

CREATE TABLE foo (baz CHARACTER VARYING(10));
INSERT INTO foo (baz) VALUES ('hi');
INSERT INTO foo (baz) VALUES ('there');
DELETE FROM foo;
DELETE FROM foo;
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: DELETE 2
-- msg: DELETE 0

CREATE TABLE foo (baz FLOAT);
INSERT INTO foo (baz) VALUES (35);
INSERT INTO foo (baz) VALUES (78);
DELETE FROM foo WHERE baz = 35;
DELETE FROM foo WHERE baz = 35;
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: DELETE 1
-- msg: DELETE 0
-- BAZ: 78
