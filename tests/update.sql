EXPLAIN UPDATE foo SET x = 123;
-- error 42P01: no such table: ":memory:".PUBLIC.FOO

UPDATE foo SET x = 123;
-- error 42P01: no such table: ":memory:".PUBLIC.FOO

CREATE TABLE foo (baz CHARACTER VARYING(10));
INSERT INTO foo (baz) VALUES ('hi');
INSERT INTO foo (baz) VALUES ('there');
UPDATE foo SET baz = 'hi';
UPDATE foo SET baz = 'other';
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: UPDATE 2
-- msg: UPDATE 2
-- BAZ: other
-- BAZ: other

CREATE TABLE foo (x INT, y INT);
INSERT INTO foo (x, y) VALUES (1, 2);
UPDATE foo SET x = x;
UPDATE foo SET y = x + 1;
UPDATE foo SET x = y WHERE x = 99;
UPDATE foo SET x = z;
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: UPDATE 1
-- msg: UPDATE 1
-- warning 02000: no data
-- msg: UPDATE 0
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.Z
-- X: 1 Y: 2

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
-- msg: UPDATE 1
-- BAZ: 100e0
-- BAZ: 78e0

CREATE TABLE foo (a INT, c VARCHAR(5));
INSERT INTO foo (a, c) VALUES (1, 'ok');
UPDATE foo SET a = 'abc';
UPDATE foo SET c = 7;
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 42846: cannot coerce CHARACTER(3) to INTEGER
-- error 42846: cannot coerce SMALLINT to CHARACTER VARYING(5)
-- A: 1 C: ok

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
UPDATE foo SET baz = -223.0e0 * 4.2e0;
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: UPDATE 1
-- BAZ: -936.6e0

CREATE TABLE foo (baz FLOAT);
INSERT INTO foo (baz) VALUES (-123);
UPDATE foo SET baz = baz * 4.2e0;
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: UPDATE 1
-- BAZ: -516.6e0

CREATE TABLE foo (baz FLOAT);
INSERT INTO foo (baz) VALUES (-123);
UPDATE foo SET baz = foo.baz * 4.2e0;
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: UPDATE 1
-- BAZ: -516.6e0

-- # Only the table being updated is in scope, so a column of another table (or
-- # a table that doesn't exist) can't be used, even if the table being updated
-- # has a column with the same name.
CREATE TABLE t (x INT, y INT);
CREATE TABLE u (y INT, z INT);
INSERT INTO t (x, y) VALUES (1, 100);
UPDATE t SET x = u.y;
UPDATE t SET x = nosuch.y;
UPDATE t SET x = u.z;
UPDATE t SET x = public.t.y + 1;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 42P01: no such table: ":memory:".PUBLIC.U
-- error 42P01: no such table: ":memory:".PUBLIC.NOSUCH
-- error 42P01: no such table: ":memory:".PUBLIC.U
-- msg: UPDATE 1
-- X: 101 Y: 100

UPDATE foo.bar SET baz = baz * 4.2;
-- error 3F000: invalid schema name: FOO

CREATE SCHEMA foo;
CREATE TABLE foo.bar (baz FLOAT);
INSERT INTO foo.bar (baz) VALUES (-123);
UPDATE foo.bar SET baz = baz * 4.2e0;
SELECT * FROM foo.bar;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: UPDATE 1
-- BAZ: -516.6e0

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

-- # https://github.com/elliotchance/vsql/issues/200
CREATE TABLE PrimaryProduct (id INT NOT NULL, PRIMARY KEY(id));
INSERT INTO PrimaryProduct (id) VALUES (1);
EXPLAIN UPDATE PrimaryProduct SET id = 2 WHERE id = 1;
UPDATE PrimaryProduct SET id = 2 WHERE id = 1;
SELECT * FROM PrimaryProduct;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.PRIMARYPRODUCT (ID INTEGER NOT NULL) BETWEEN 1 AND 1
-- msg: UPDATE 1
-- ID: 2

-- # The PRIMARY KEY is checked once every row has changed, so a new key can be
-- # the old key of another row (#523).
CREATE TABLE PrimaryProduct (id INT NOT NULL, PRIMARY KEY(id));
INSERT INTO PrimaryProduct (id) VALUES (1);
INSERT INTO PrimaryProduct (id) VALUES (2);
INSERT INTO PrimaryProduct (id) VALUES (3);
UPDATE PrimaryProduct SET id = id + 1;
SELECT * FROM PrimaryProduct;
UPDATE PrimaryProduct SET id = 6 - id;
SELECT * FROM PrimaryProduct;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: UPDATE 3
-- ID: 2
-- ID: 3
-- ID: 4
-- msg: UPDATE 3
-- ID: 2
-- ID: 3
-- ID: 4

CREATE TABLE PrimaryProduct (id INT NOT NULL, PRIMARY KEY(id));
INSERT INTO PrimaryProduct (id) VALUES (1);
INSERT INTO PrimaryProduct (id) VALUES (2);
INSERT INTO PrimaryProduct (id) VALUES (3);
UPDATE PrimaryProduct SET id = 3 WHERE id < 3;
SELECT * FROM PrimaryProduct;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.PRIMARYPRODUCT
-- ID: 1
-- ID: 2
-- ID: 3

CREATE TABLE PrimaryProduct (id INT NOT NULL, PRIMARY KEY(id));
INSERT INTO PrimaryProduct (id) VALUES (1);
INSERT INTO PrimaryProduct (id) VALUES (2);
INSERT INTO PrimaryProduct (id) VALUES (3);
UPDATE PrimaryProduct SET id = 4 WHERE id < 3;
SELECT * FROM PrimaryProduct;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.PRIMARYPRODUCT
-- ID: 1
-- ID: 2
-- ID: 3

CREATE TABLE PrimaryProduct (id INT NOT NULL, x INT, PRIMARY KEY(id));
INSERT INTO PrimaryProduct (id, x) VALUES (1, 10);
INSERT INTO PrimaryProduct (id, x) VALUES (2, 20);
START TRANSACTION;
UPDATE PrimaryProduct SET id = id + 1, x = x + 1;
UPDATE PrimaryProduct SET x = x + 1;
UPDATE PrimaryProduct SET id = id - 1;
SELECT * FROM PrimaryProduct;
ROLLBACK;
SELECT * FROM PrimaryProduct;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: UPDATE 2
-- msg: UPDATE 2
-- msg: UPDATE 2
-- ID: 1 X: 12
-- ID: 2 X: 22
-- msg: ROLLBACK
-- ID: 1 X: 10
-- ID: 2 X: 20

CREATE TABLE foo (a INT, c VARCHAR(5));
INSERT INTO foo (a, c) VALUES (3, 'z');
UPDATE foo SET a = 1, a = 2;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 42601: syntax error: column A is set more than once

CREATE TABLE foo (a INT, c VARCHAR(5));
INSERT INTO foo (a, c) VALUES (3, 'z');
UPDATE foo SET a = 1, c = 'y';
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: UPDATE 1
-- A: 1 C: y

CREATE TABLE foo ("name" VARCHAR(10), "Count" INT);
INSERT INTO foo ("name", "Count") VALUES ('a', 1);
UPDATE foo SET "name" = 'b', "Count" = "Count" + 1;
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: UPDATE 1
-- name: b Count: 2
