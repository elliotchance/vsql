DELETE FROM foo;
-- error 42P01: no such table: ":memory:".PUBLIC.FOO

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
DELETE FROM foo WHERE baz = 35.0;
DELETE FROM foo WHERE baz = 35.0;
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: DELETE 1
-- msg: DELETE 0
-- BAZ: 78e0

DELETE FROM foo.bar;
-- error 3F000: invalid schema name: FOO

CREATE SCHEMA foo;
CREATE TABLE foo.bar (baz BIGINT);
DELETE FROM foo.bar;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: DELETE 0

-- # https://github.com/elliotchance/vsql/issues/200
CREATE TABLE PrimaryProduct (id INT NOT NULL, PRIMARY KEY(id));
INSERT INTO PrimaryProduct (id) VALUES (1);
INSERT INTO PrimaryProduct (id) VALUES (2);
EXPLAIN DELETE FROM PrimaryProduct WHERE id = 1;
DELETE FROM PrimaryProduct WHERE id = 1;
SELECT * FROM PrimaryProduct;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.PRIMARYPRODUCT (ID INTEGER NOT NULL) BETWEEN 1 AND 1
-- msg: DELETE 1
-- ID: 2
