-- # A <large object length> can have a <multiplier>: K is 1024, M is 1048576
-- # and G is 1073741824 (6.1, Syntax Rules, 11.b). It can be written after the
-- # number with or without a space, in either case.
/* types */
CREATE TABLE t (a CLOB(2K), b BLOB(3 m), c NCLOB(1G), d BLOB(1k), e CLOB(2147483647));
INSERT INTO t VALUES ('a', X'01', 'c', X'02', 'e');
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- A: a (CHARACTER LARGE OBJECT(2048)) B: 01 (BINARY LARGE OBJECT(3145728)) C: c (CHARACTER LARGE OBJECT(1073741824)) D: 02 (BINARY LARGE OBJECT(1024)) E: e (CHARACTER LARGE OBJECT(2147483647))

/* types */
VALUES CAST('abc' AS CLOB(1K));
-- COL1: abc (CHARACTER LARGE OBJECT(1024))

-- # The length can't be more than 2147483647 (6.1, Syntax Rules, 17), so 2G
-- # and anything with T (1099511627776) or P (1125899906842624) is too long.
CREATE TABLE t (a CLOB(2G));
-- error 42601: syntax error: CHARACTER LARGE OBJECT length must not be greater than 2147483647

CREATE TABLE t (a BLOB(2147483648));
-- error 42601: syntax error: BINARY LARGE OBJECT length must not be greater than 2147483647

CREATE TABLE t (a CLOB(1T));
-- error 42601: syntax error: CHARACTER LARGE OBJECT length must not be greater than 2147483647

CREATE TABLE t (a BLOB(1 P));
-- error 42601: syntax error: BINARY LARGE OBJECT length must not be greater than 2147483647

CREATE TABLE t (a BLOB(99999P));
-- error 42601: syntax error: BINARY LARGE OBJECT length must not be greater than 2147483647

CREATE TABLE t (a CLOB(99999999999999999999));
-- error 42601: syntax error: CHARACTER LARGE OBJECT length must not be greater than 2147483647

-- # The length must be at least 1 (6.1, Syntax Rules, 12), and only K, M, G, T
-- # and P are multipliers.
CREATE TABLE t (a CLOB(0K));
-- error 42601: syntax error: CHARACTER LARGE OBJECT length must be greater than 0

CREATE TABLE t (a CLOB(1X));
-- error 42601: syntax error: unexpected identifier at line 1, column 25 near "CLOB(1X)", expecting ")"

CREATE TABLE t (a CLOB(1 "K"));
-- error 42601: syntax error: unexpected identifier at line 1, column 26 near "CLOB(1 "K")", expecting ")"
