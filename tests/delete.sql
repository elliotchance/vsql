DELETE FROM foo;
-- error 42P01: no such table: PUBLIC.FOO

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
-- BAZ: 78

DELETE FROM foo.bar;
-- error 3F000: invalid schema name: FOO

CREATE SCHEMA foo;
CREATE TABLE foo.bar (baz BIGINT);
DELETE FROM foo.bar;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: DELETE 0

/* connection 1 */
START TRANSACTION;
CREATE TABLE foo (bar INT);
INSERT INTO foo (bar) VALUES (123);
/* connection 2 */
DELETE FROM foo;
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
DELETE FROM foo;
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: COMMIT
-- 2: msg: DELETE 1

/* connection 1 */
START TRANSACTION;
CREATE TABLE foo (bar INT);
INSERT INTO foo (bar) VALUES (123);
DROP TABLE foo;
COMMIT;
/* connection 2 */
DELETE FROM foo;
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: DROP TABLE 1
-- 1: msg: COMMIT
-- 2: error 42P01: no such table: PUBLIC.FOO
