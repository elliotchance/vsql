-- # A column can have any of the data types, with or without a length or
-- # precision.
CREATE TABLE bar (baz BIGINT);
-- msg: CREATE TABLE 1

CREATE TABLE bar (baz BOOLEAN);
-- msg: CREATE TABLE 1

CREATE TABLE bar (baz CHAR VARYING(10));
-- msg: CREATE TABLE 1

CREATE TABLE bar (baz CHARACTER VARYING(10));
-- msg: CREATE TABLE 1

CREATE TABLE bar (baz CHAR(10));
-- msg: CREATE TABLE 1

CREATE TABLE bar (baz CHARACTER(10));
-- msg: CREATE TABLE 1

CREATE TABLE bar (baz CHARACTER);
-- msg: CREATE TABLE 1

CREATE TABLE bar (baz CHAR);
-- msg: CREATE TABLE 1

CREATE TABLE bar (baz DOUBLE PRECISION);
-- msg: CREATE TABLE 1

CREATE TABLE foo (x FLOAT);
-- msg: CREATE TABLE 1

CREATE TABLE bar (baz FLOAT(10));
-- msg: CREATE TABLE 1

CREATE TABLE bar (baz INTEGER);
-- msg: CREATE TABLE 1

CREATE TABLE bar (baz INT);
-- msg: CREATE TABLE 1

CREATE TABLE bar (baz REAL);
-- msg: CREATE TABLE 1

CREATE TABLE bar (baz SMALLINT);
-- msg: CREATE TABLE 1

CREATE TABLE bar (baz VARCHAR(10));
-- msg: CREATE TABLE 1

-- # A table name can't be used twice in a schema (Syntax Rules, 7). Regular
-- # identifiers are the same when their upper case forms are (5.2, Syntax
-- # Rules, 27), so foo and Foo are the same table, but delimited identifiers
-- # must match exactly (5.2, Syntax Rules, 29).
CREATE TABLE foo (x FLOAT);
CREATE TABLE foo (baz CHARACTER VARYING(10));
-- msg: CREATE TABLE 1
-- error 42P07: duplicate table: ":memory:".PUBLIC.FOO

CREATE TABLE t1 (f1 CHARACTER VARYING(10), f2 FLOAT);
-- msg: CREATE TABLE 1

CREATE TABLE foo (x FLOAT);
CREATE TABLE Foo (baz CHARACTER VARYING(10));
-- msg: CREATE TABLE 1
-- error 42P07: duplicate table: ":memory:".PUBLIC.FOO

CREATE TABLE "foo" (x FLOAT);
CREATE TABLE "Foo" (baz CHARACTER VARYING(10));
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1

-- # A delimited identifier can't be empty, and must have a closing quote.
CREATE TABLE "" (x INT);
-- error 42601: syntax error: a delimited identifier cannot be empty

CREATE TABLE foo ("" INT);
-- error 42601: syntax error: a delimited identifier cannot be empty

CREATE TABLE "foo (x INT);
-- error 42601: syntax error: unterminated delimited identifier: "foo (x INT)

-- # A delimited identifier can have any character other than the ones in the
-- # Unicode General Categories Cc, Cf, Cn, Cs, Zl and Zp (5.2, Syntax Rules, 7,
-- # and Part 1, 4.10.2): here a tab, a zero width space (U+200B), an
-- # unassigned code point (U+0378) and a line separator (U+2028). Private use
-- # characters and other spaces are allowed.
CREATE TABLE "a	b" (x INT);
-- error 42601: syntax error: invalid character in delimited identifier: U+0009

CREATE TABLE "a​b" (x INT);
-- error 42601: syntax error: invalid character in delimited identifier: U+200B

CREATE TABLE foo ("a͸b" INT);
-- error 42601: syntax error: invalid character in delimited identifier: U+0378

CREATE TABLE foo ("a b" INT);
-- error 42601: syntax error: invalid character in delimited identifier: U+2028

CREATE TABLE "a b" (x INT);
-- msg: CREATE TABLE 1

-- # A doubled quote is a quote character in the name.
CREATE TABLE "a""b" ("x""y" INT, "ü""ö" INT);
INSERT INTO "a""b" ("x""y", "ü""ö") VALUES (1, 2);
SELECT * FROM "a""b";
SELECT "a""b"."x""y" AS """q""" FROM "a""b";
SELECT nope FROM "a""b";
CREATE TABLE """" (x INT);
SELECT * FROM """";
SELECT * FROM "no""pe";
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- x"y: 1 ü"ö: 2
-- "q": 1
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.NOPE
-- msg: CREATE TABLE 1
-- error 42P01: no such table: ":memory:".PUBLIC."no""pe"

CREATE TABLE "foo"" (x INT);
-- error 42601: syntax error: unterminated delimited identifier: "foo"" (x INT)

-- # NOT NULL, and the datetime and exact numeric types with and without a
-- # precision, scale or time zone.
CREATE TABLE t1 (f1 CHARACTER VARYING(10), f2 FLOAT NOT NULL);
-- msg: CREATE TABLE 1

CREATE TABLE foo (bar DATE);
-- msg: CREATE TABLE 1

CREATE TABLE foo (bar TIME);
-- msg: CREATE TABLE 1

CREATE TABLE foo (bar TIME(3));
-- msg: CREATE TABLE 1

CREATE TABLE foo (bar TIME WITHOUT TIME ZONE);
-- msg: CREATE TABLE 1

CREATE TABLE foo (bar TIME(3) WITHOUT TIME ZONE);
-- msg: CREATE TABLE 1

CREATE TABLE foo (bar TIME WITH TIME ZONE);
-- msg: CREATE TABLE 1

CREATE TABLE foo (bar TIME(3) WITH TIME ZONE);
-- msg: CREATE TABLE 1

CREATE TABLE foo (bar TIMESTAMP);
-- msg: CREATE TABLE 1

CREATE TABLE foo (bar TIMESTAMP(3));
-- msg: CREATE TABLE 1

CREATE TABLE foo (bar TIMESTAMP WITHOUT TIME ZONE);
-- msg: CREATE TABLE 1

CREATE TABLE foo (bar TIMESTAMP(3) WITHOUT TIME ZONE);
-- msg: CREATE TABLE 1

CREATE TABLE foo (bar TIMESTAMP WITH TIME ZONE);
-- msg: CREATE TABLE 1

CREATE TABLE foo (bar TIMESTAMP(3) WITH TIME ZONE);
-- msg: CREATE TABLE 1

CREATE TABLE foo (bar NUMERIC);
-- msg: CREATE TABLE 1

CREATE TABLE foo (bar NUMERIC(10));
-- msg: CREATE TABLE 1

CREATE TABLE foo (bar NUMERIC(10, 2));
-- msg: CREATE TABLE 1

CREATE TABLE foo (bar DECIMAL);
-- msg: CREATE TABLE 1

CREATE TABLE foo (bar DECIMAL(10));
-- msg: CREATE TABLE 1

CREATE TABLE foo (bar DECIMAL(10, 2));
-- msg: CREATE TABLE 1

-- # A length must be greater than 0 (6.1, Syntax Rules, 4), as must a precision
-- # (6.1, Syntax Rules, 21). A scale can't be greater than the precision (6.1,
-- # Syntax Rules, 23), but it can be the same.
CREATE TABLE foo (x VARCHAR(0));
-- error 42601: syntax error: CHARACTER VARYING length must be greater than 0

CREATE TABLE foo (x CHAR(0));
-- error 42601: syntax error: CHARACTER length must be greater than 0

CREATE TABLE foo (x NUMERIC(0));
-- error 42601: syntax error: NUMERIC precision must be greater than 0

CREATE TABLE foo (x NUMERIC(3, 5));
-- error 42601: syntax error: NUMERIC scale (5) must not be greater than precision (3)

CREATE TABLE foo (x DECIMAL(3, 4));
-- error 42601: syntax error: DECIMAL scale (4) must not be greater than precision (3)

CREATE TABLE foo (x NUMERIC(3, 3), y DECIMAL(1, 1));
-- msg: CREATE TABLE 1

CREATE TABLE foo (x FLOAT(0));
-- error 42601: syntax error: FLOAT precision must be greater than 0

-- # A table can only be created in a schema that exists.
CREATE TABLE foo.bar (baz BIGINT);
-- error 3F000: invalid schema name: FOO

CREATE SCHEMA foo;
CREATE TABLE foo.bar (baz BIGINT);
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1

-- # ABSOLUTE and CONTINUE are non-reserved words, so they can be used as the
-- # names of tables and schemas, in either case.
CREATE TABLE absolute (baz BIGINT);
-- msg: CREATE TABLE 1

CREATE TABLE ABSOLUTE (baz BIGINT);
-- msg: CREATE TABLE 1

CREATE SCHEMA absolute;
CREATE TABLE absolute.continue (baz BIGINT);
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1

CREATE SCHEMA absolute;
CREATE TABLE absolute.CONTINUE (baz BIGINT);
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1

-- # A column name can't be used twice in a table (11.4, Syntax Rules, 3). x and
-- # X are the same name, but "x" isn't, because a delimited identifier isn't
-- # changed to upper case (5.2, Syntax Rules, 28).
CREATE TABLE foo (x INT, x INT);
-- error 42601: syntax error: column X is defined more than once

CREATE TABLE foo (x INT, X VARCHAR(5));
-- error 42601: syntax error: column X is defined more than once

CREATE TABLE foo (x INT, "x" VARCHAR(5));
-- msg: CREATE TABLE 1

-- # A table needs at least one column, a table constraint isn't enough (Syntax
-- # Rules, 9.a).
CREATE TABLE foo (CONSTRAINT c CHECK (1 = 1));
-- error 42601: syntax error: a table must have at least one column

CREATE TABLE foo (x INT, CONSTRAINT c CHECK (1 = 1));
-- msg: CREATE TABLE 1
