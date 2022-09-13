SELECT * FROM foo;
-- error 42P01: no such table: PUBLIC.FOO

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
-- error 42P01: no such table: PUBLIC.FOO
-- error 42P01: no such table: PUBLIC.BAR

CREATE TABLE foo (x FLOAT);
EXPLAIN SELECT foo.* FROM foo;
-- msg: CREATE TABLE 1
-- EXPLAIN: TABLE PUBLIC.FOO (PUBLIC.FOO.X DOUBLE PRECISION)
-- EXPLAIN: EXPR (X DOUBLE PRECISION)

CREATE TABLE foo (x FLOAT);
INSERT INTO foo (x) VALUES (1.234);
SELECT foo.* FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- X: 1.234

CREATE TABLE foo (x FLOAT);
EXPLAIN SELECT bar.* FROM foo;
-- msg: CREATE TABLE 1
-- error 42P01: no such table: PUBLIC.BAR

SELECT * FROM foo.bar;
-- error 3F000: invalid schema name: FOO

CREATE SCHEMA foo;
CREATE TABLE foo.bar (x FLOAT);
INSERT INTO foo.bar (x) VALUES (1.234);
SELECT * FROM foo.bar;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- X: 1.234

/* connection 1 */
START TRANSACTION;
CREATE TABLE foo (bar INT);
INSERT INTO foo (bar) VALUES (123);
/* connection 2 */
SELECT * FROM foo;
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 2: error 42P01: no such table: PUBLIC.FOO

/* connection 1 */
START TRANSACTION;
CREATE TABLE foo (bar INT);
INSERT INTO foo (bar) VALUES (123);
COMMIT;
/* connection 2 */
SELECT * FROM foo;
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: COMMIT
-- 2: BAR: 123

/* connection 1 */
START TRANSACTION;
CREATE TABLE foo (bar INT);
INSERT INTO foo (bar) VALUES (123);
DROP TABLE foo;
COMMIT;
/* connection 2 */
SELECT * FROM foo;
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: DROP TABLE 1
-- 1: msg: COMMIT
-- 2: error 42P01: no such table: PUBLIC.FOO
