SELECT * FROM foo;
-- error 42P01: no such table: FOO

CREATE TABLE foo (x FLOAT);
INSERT INTO foo (x) VALUES (1.234);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- X: 1.234

CREATE TABLE foo (x FLOAT);
CREATE TABLE "Foo" ("a" FLOAT);
INSERT INTO FOO (x) VALUES (1.234);
INSERT INTO "Foo" ("a") VALUES (4.56);
SELECT * FROM Foo;
SELECT * FROM "Foo";
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- X: 1.234
-- a: 4.56

SELECT *
FROM foo;
SELECT * FROM bar;
-- error 42P01: no such table: FOO
-- error 42P01: no such table: BAR
