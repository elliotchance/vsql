UPDATE foo SET x = 123;
-- error 42P01: no such table: PUBLIC.FOO

CREATE TABLE foo (baz CHARACTER VARYING(10));
INSERT INTO foo (baz) VALUES ('hi');
INSERT INTO foo (baz) VALUES ('there');
UPDATE foo SET baz = 'hi';
UPDATE foo SET baz = 'other';
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: UPDATE 1
-- msg: UPDATE 2
-- BAZ: other
-- BAZ: other

CREATE TABLE foo (baz FLOAT);
INSERT INTO foo (baz) VALUES (35);
INSERT INTO foo (baz) VALUES (78);
UPDATE foo SET baz = 100 WHERE baz = 35.0;
UPDATE foo SET baz = 100 WHERE baz = 100.0;
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: UPDATE 1
-- msg: UPDATE 0
-- BAZ: 100
-- BAZ: 78

CREATE TABLE foo (baz FLOAT);
UPDATE foo SET baz = true;
-- msg: CREATE TABLE 1
-- error 42846: cannot coerce BOOLEAN to DOUBLE PRECISION

CREATE TABLE foo (baz FLOAT);
INSERT INTO foo (baz) VALUES (123);
UPDATE foo SET baz = NULL;
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: UPDATE 1
-- BAZ: NULL

CREATE TABLE foo (baz FLOAT NOT NULL);
INSERT INTO foo (baz) VALUES (123);
UPDATE foo SET baz = NULL;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 23502: violates non-null constraint: column BAZ

CREATE TABLE foo (baz FLOAT);
INSERT INTO foo (baz) VALUES (-123);
UPDATE foo SET baz = -223.0 * 4.2;
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: UPDATE 1
-- BAZ: -936.6

CREATE TABLE foo (baz FLOAT);
INSERT INTO foo (baz) VALUES (-123);
UPDATE foo SET baz = baz * 4.2;
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: UPDATE 1
-- BAZ: -516.6

UPDATE foo.bar SET baz = baz * 4.2;
-- error 3F000: invalid schema name: FOO

CREATE SCHEMA foo;
CREATE TABLE foo.bar (baz FLOAT);
INSERT INTO foo.bar (baz) VALUES (-123);
UPDATE foo.bar SET baz = baz * 4.2;
SELECT * FROM foo.bar;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: UPDATE 1
-- BAZ: -516.6

CREATE TABLE foo (baz FLOAT NOT NULL);
UPDATE foo SET baz = NULL;
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- error 23502: violates non-null constraint: column BAZ

CREATE TABLE foo (baz VARCHAR(4));
INSERT INTO foo (baz) VALUES ('abc');
UPDATE foo SET baz = 'too long';
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 22001: string data right truncation for CHARACTER VARYING(4)
-- BAZ: abc

/* connection 1 */
START TRANSACTION;
CREATE TABLE foo (bar INT);
INSERT INTO foo (bar) VALUES (123);
/* connection 2 */
UPDATE foo SET bar = 456;
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
UPDATE foo SET bar = 456;
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: COMMIT
-- 2: msg: UPDATE 1

/* connection 1 */
START TRANSACTION;
CREATE TABLE foo (bar INT);
INSERT INTO foo (bar) VALUES (123);
DROP TABLE foo;
COMMIT;
/* connection 2 */
UPDATE foo SET bar = 456;
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: DROP TABLE 1
-- 1: msg: COMMIT
-- 2: error 42P01: no such table: PUBLIC.FOO
