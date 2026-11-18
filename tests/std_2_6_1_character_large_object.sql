-- # CHARACTER LARGE OBJECT (or CHAR LARGE OBJECT or CLOB) is a character
-- # string. One without a length has the maximum length.
/* types */
CREATE TABLE t (a CHARACTER LARGE OBJECT, b CHAR LARGE OBJECT(5), c CLOB, d CLOB(3));
INSERT INTO t VALUES ('hello world', 'hi', 'it''s', 'abc');
INSERT INTO t (a) VALUES (NULL);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- A: hello world (CHARACTER LARGE OBJECT) B: hi (CHARACTER LARGE OBJECT(5)) C: it's (CHARACTER LARGE OBJECT) D: abc (CHARACTER LARGE OBJECT(3))
-- A: NULL (CHARACTER LARGE OBJECT) B: NULL (CHARACTER LARGE OBJECT(5)) C: NULL (CHARACTER LARGE OBJECT) D: NULL (CHARACTER LARGE OBJECT(3))

-- # A value that's too long is truncated if the extra characters are spaces,
-- # otherwise it's 22001 (9.2, General Rules, 3.b.vii).
CREATE TABLE t (a CLOB(3));
INSERT INTO t VALUES ('abc   ');
SELECT * FROM t;
INSERT INTO t VALUES ('abcd');
INSERT INTO t VALUES (123);
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- A: abc
-- error 22001: string data right truncation for CHARACTER LARGE OBJECT(3)
-- error 42846: cannot coerce INTEGER to CHARACTER LARGE OBJECT(3)

CREATE TABLE t (a CLOB(0));
-- error 42601: syntax error: CHARACTER LARGE OBJECT length must be greater than 0

-- # A large object can't be compared as a key, so it can't be in a PRIMARY
-- # KEY, UNIQUE or FOREIGN KEY (9.12, Syntax Rules, 3), or an index.
CREATE TABLE t (a CLOB PRIMARY KEY);
-- error 42601: syntax error: column A in PRIMARY KEY cannot be a CHARACTER LARGE OBJECT

CREATE TABLE t (a INT, b BLOB, UNIQUE (a, b));
-- error 42601: syntax error: column B in UNIQUE cannot be a BINARY LARGE OBJECT

CREATE TABLE t (a CLOB REFERENCES t (a));
-- error 42601: syntax error: column A in FOREIGN KEY cannot be a CHARACTER LARGE OBJECT

/* extensions V002-01 */
CREATE TABLE t (a INT, b NCLOB);
CREATE INDEX t_b ON t (a, b);
ALTER TABLE t ADD CONSTRAINT u UNIQUE (b);
-- msg: CREATE TABLE 1
-- error 42601: syntax error: column B in index ":memory:".PUBLIC.T_B cannot be a CHARACTER LARGE OBJECT
-- error 42601: syntax error: column B in UNIQUE cannot be a CHARACTER LARGE OBJECT

-- # A CAST can be to or from a CHARACTER LARGE OBJECT.
/* types */
VALUES CAST('abc' AS CLOB);
-- COL1: abc (CHARACTER LARGE OBJECT)

/* types */
VALUES CAST(CAST('abc' AS CLOB) AS VARCHAR(2));
-- warning 01004: string data, right truncation
-- COL1: ab (CHARACTER VARYING(2))

-- # The national character set is the same as the character set (UTF8), so
-- # each national character string type is the same as the character string
-- # type, and a national character string literal is a character string
-- # literal.
/* types */
CREATE TABLE t (a NATIONAL CHARACTER, b NATIONAL CHAR(2), c NCHAR(3), d NCHAR, e NATIONAL CHARACTER VARYING(4), f NATIONAL CHAR VARYING(5), g NCHAR VARYING(6), h NATIONAL CHARACTER LARGE OBJECT, i NCHAR LARGE OBJECT(7), j NCLOB, k NCLOB(8));
INSERT INTO t VALUES (N'a', n'b', N'c', N'd', N'e', N'f', N'g', N'h', N'i', N'j', N'k');
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- A: a (CHARACTER(1)) B: b  (CHARACTER(2)) C: c   (CHARACTER(3)) D: d (CHARACTER(1)) E: e (CHARACTER VARYING(4)) F: f (CHARACTER VARYING(5)) G: g (CHARACTER VARYING(6)) H: h (CHARACTER LARGE OBJECT) I: i (CHARACTER LARGE OBJECT(7)) J: j (CHARACTER LARGE OBJECT) K: k (CHARACTER LARGE OBJECT(8))

/* types */
VALUES N'it''s';
-- COL1: it's (CHARACTER(4))
