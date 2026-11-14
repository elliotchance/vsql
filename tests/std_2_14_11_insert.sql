-- # Each INSERT adds one row, which is read back in the type of its column,
-- # including all three boolean values.
CREATE TABLE foo (x FLOAT);
INSERT INTO foo (x) VALUES (1.23);
-- msg: CREATE TABLE 1
-- msg: INSERT 1

CREATE TABLE foo (x FLOAT);
INSERT INTO foo (x) VALUES (101);
INSERT INTO foo (x) VALUES (102);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- X: 101e0
-- X: 102e0

CREATE TABLE foo (b BOOLEAN);
INSERT INTO foo (b) VALUES (true);
INSERT INTO foo (b) VALUES (false);
INSERT INTO foo (b) VALUES (unknown);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- B: TRUE
-- B: FALSE
-- B: UNKNOWN

-- # The number of values must be the number of listed columns (Syntax Rules,
-- # 13).
CREATE TABLE foo (b BOOLEAN);
INSERT INTO foo (b) VALUES (123, 456);
-- msg: CREATE TABLE 1
-- error 42601: syntax error: INSERT has more values than columns

CREATE TABLE foo (b BOOLEAN, x INT);
INSERT INTO foo (b, x) VALUES (123);
-- msg: CREATE TABLE 1
-- error 42601: syntax error: INSERT has less values than columns

-- # The table and every listed column must exist.
INSERT INTO foo (b) VALUES (123);
-- error 42P01: no such table: ":memory:".PUBLIC.FOO

CREATE TABLE foo (b BOOLEAN);
INSERT INTO foo (x) VALUES (true);
-- msg: CREATE TABLE 1
-- error 42703: no such column: X

-- # Each value must be assignable to its column (Syntax Rules, 14) and
-- # (9.2, Syntax Rules, 3). A number can't be stored in a BOOLEAN or a string,
-- # and a string isn't converted to a number, even if it looks like one.
CREATE TABLE foo (b BOOLEAN);
INSERT INTO foo (b) VALUES (123);
-- msg: CREATE TABLE 1
-- error 42846: cannot coerce SMALLINT to BOOLEAN

CREATE TABLE foo (a INT, c VARCHAR(5));
INSERT INTO foo (a) VALUES ('x');
INSERT INTO foo (a) VALUES ('5');
INSERT INTO foo (c) VALUES (5);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- error 42846: cannot coerce CHARACTER(1) to INTEGER
-- error 42846: cannot coerce CHARACTER(1) to INTEGER
-- error 42846: cannot coerce SMALLINT to CHARACTER VARYING(5)

-- # A NOT NULL column rejects the null value, whether it's given or the column
-- # isn't listed and gets its default, which is NULL (General Rules, 7.a). A
-- # column that can be NULL can be given NULL or left out.
CREATE TABLE t1 (f1 CHARACTER VARYING(10), f2 FLOAT NOT NULL);
INSERT INTO t1 (f1, f2) VALUES ('a', 1.23);
SELECT * FROM t1;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- F1: a F2: 1.23e0

CREATE TABLE t1 (f1 CHARACTER VARYING(10), f2 FLOAT NOT NULL);
INSERT INTO t1 (f1, f2) VALUES ('a', NULL);
SELECT * FROM t1;
-- msg: CREATE TABLE 1
-- error 23502: violates non-null constraint: column F2

CREATE TABLE t1 (f1 CHARACTER VARYING(10), f2 FLOAT NOT NULL);
INSERT INTO t1 (f1, f2) VALUES (NULL, 1.23);
SELECT * FROM t1;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- F1: NULL F2: 1.23e0

CREATE TABLE t1 (f1 CHARACTER VARYING(10), f2 FLOAT);
INSERT INTO t1 (f1, f2) VALUES (NULL, NULL);
SELECT * FROM t1;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- F1: NULL F2: NULL

CREATE TABLE t1 (f1 VARCHAR(10), f2 FLOAT NOT NULL);
INSERT INTO t1 (f2) VALUES (1.23);
SELECT * FROM t1;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- F1: NULL F2: 1.23e0

CREATE TABLE t1 (f1 CHARACTER VARYING(10), f2 FLOAT NOT NULL);
INSERT INTO t1 (f1) VALUES ('a');
SELECT * FROM t1;
-- msg: CREATE TABLE 1
-- error 23502: violates non-null constraint: column F2

-- # A value can be an expression, which is computed before it's stored.
CREATE TABLE t1 (f1 FLOAT NOT NULL);
INSERT INTO t1 (f1) VALUES (-123.0 * 4.2);
SELECT * FROM t1;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- F1: -516.6e0

-- # A table in another schema, which must exist.
INSERT INTO foo.bar (nothing) VALUES (123);
-- error 3F000: invalid schema name: FOO

CREATE SCHEMA foo;
CREATE TABLE foo.bar (baz BIGINT);
INSERT INTO foo.bar (baz) VALUES (123);
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1

-- # A string that's too long for its VARCHAR is an error, rather than being cut
-- # short (9.2, General Rules, 3.b.v.2). Only that INSERT fails.
CREATE TABLE t1 (f1 CHARACTER VARYING(4));
INSERT INTO t1 (f1) VALUES ('abc');
INSERT INTO t1 (f1) VALUES ('too long');
SELECT * FROM t1;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 22001: string data right truncation for CHARACTER VARYING(4)
-- F1: abc

-- # A column can't be listed more than once (Syntax Rules, 8).
CREATE TABLE foo (a INT, c VARCHAR(5));
INSERT INTO foo (a, a, c) VALUES (3, 3, 'z');
-- msg: CREATE TABLE 1
-- error 42601: syntax error: column A is specified more than once

-- # VALUES can have several rows, and a row of one value doesn't need
-- # parentheses. Every row must have a value for each listed column.
CREATE TABLE foo (a INT, b VARCHAR(10));
INSERT INTO foo (a, b) VALUES (5, 'q'), (6, 'r'), (7, NULL);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- A: 5 B: q
-- A: 6 B: r
-- A: 7 B: NULL

CREATE TABLE foo (x INT);
INSERT INTO foo (x) VALUES (1), (2), 3;
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- X: 1
-- X: 2
-- X: 3

CREATE TABLE foo (a INT, b VARCHAR(10));
INSERT INTO foo (a, b) VALUES (5, 'q'), (6);
INSERT INTO foo (a, b) VALUES (5, 'q'), (6, 'r', 7);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- error 42601: syntax error: INSERT has less values than columns
-- error 42601: syntax error: INSERT has more values than columns

-- # When one row fails, none of the rows of that INSERT are inserted.
CREATE TABLE foo (a INT NOT NULL, PRIMARY KEY (a));
INSERT INTO foo (a) VALUES (1), (NULL);
INSERT INTO foo (a) VALUES (2), (3);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- error 23502: violates non-null constraint: column A
-- msg: INSERT 2
-- A: 2
-- A: 3

-- # VALUES NULL, without parentheses, is a row of one null value.
CREATE TABLE t1 (x INT);
INSERT INTO t1 (x) VALUES NULL;
SELECT * FROM t1;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- X: NULL

-- # A column of another table isn't in scope in the values of an INSERT.
CREATE TABLE other (y INT);
CREATE TABLE t2 (x INT);
INSERT INTO t2 (x) VALUES (y);
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.Y
