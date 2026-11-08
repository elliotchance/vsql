-- # A string cast to a shorter CHAR or VARCHAR keeps the first characters.
-- # Losing characters that aren't spaces is only a warning (General Rules,
-- # 11.d.ii and 12.d.ii).
/* types */
VALUES ROW(CAST('abc' AS CHARACTER(3)), CHARACTER_LENGTH(CAST('abc' AS CHARACTER(3))));
-- COL1: abc (CHARACTER(3)) COL2: 3 (INTEGER)

VALUES ROW(CAST('abcde' AS CHARACTER(3)), CHARACTER_LENGTH(CAST('abcde' AS CHARACTER(3))));
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- COL1: abc COL2: 3

/* types */
VALUES ROW(CAST('abc ' AS CHARACTER(3)), CHARACTER_LENGTH(CAST('abc ' AS CHARACTER(3))));
-- COL1: abc (CHARACTER(3)) COL2: 3 (INTEGER)

/* types */
VALUES ROW(CAST('abc         ' AS CHARACTER(3)), CHARACTER_LENGTH(CAST('abc         ' AS CHARACTER(3))));
-- COL1: abc (CHARACTER(3)) COL2: 3 (INTEGER)

VALUES ROW(CAST('abc d' AS CHARACTER(3)), CHARACTER_LENGTH(CAST('abc d' AS CHARACTER(3))));
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- COL1: abc COL2: 3

VALUES CAST('hello' AS VARCHAR(2));
-- warning 01004: string data, right truncation
-- COL1: he

-- # A string cast to a longer CHAR is padded with spaces (General Rules,
-- # 11.d.iii).
/* types */
VALUES CAST('ab' AS CHARACTER(4));
-- COL1: ab   (CHARACTER(4))

-- # Storing a string that's too long in a column is an error, not a warning
-- # like a CAST (9.2, General Rules, 3.b.v.2).
CREATE TABLE foo (x VARCHAR(4));
INSERT INTO foo (x) VALUES ('hello');
-- msg: CREATE TABLE 1
-- error 22001: string data right truncation for CHARACTER VARYING(4)

-- # The padding counts toward the length of a CHAR.
/* types */
VALUES ROW(CAST('abc' AS CHARACTER(4)), CHARACTER_LENGTH(CAST('abc' AS CHARACTER(4))));
-- COL1: abc  (CHARACTER(4)) COL2: 4 (INTEGER)

-- # A number cast to a CHAR is its literal, and it's an error, not a warning,
-- # when that doesn't fit (General Rules, 11.a.iii.4).
/* types */
VALUES CAST(123 AS CHARACTER(3));
-- COL1: 123 (CHARACTER(3))

VALUES CAST(1.23 AS CHARACTER(3));
-- error 22001: string data right truncation for CHARACTER(3)

-- # A VARCHAR isn't padded, but keeps any trailing spaces of the string.
/* types */
VALUES ROW(CAST('abc' AS VARCHAR(3)), CHARACTER_LENGTH(CAST('abc' AS VARCHAR(3))));
-- COL1: abc (CHARACTER VARYING(3)) COL2: 3 (INTEGER)

/* types */
VALUES ROW(CAST('abc ' AS VARCHAR(20)), CHARACTER_LENGTH(CAST('abc ' AS VARCHAR(20))));
-- COL1: abc  (CHARACTER VARYING(20)) COL2: 4 (INTEGER)

-- # A number can be cast to another numeric type, but not to a BOOLEAN (Syntax
-- # Rules, 7).
/* types */
VALUES CAST(123 AS SMALLINT);
-- COL1: 123 (SMALLINT)

VALUES CAST(123 AS BOOLEAN);
-- error 42846: cannot coerce SMALLINT to BOOLEAN

-- # A string cast to a BOOLEAN is trimmed and read as a boolean literal in any
-- # case, so 'unknown' is UNKNOWN (the null value). Anything else, such as 't'
-- # or '1', is an error (General Rules, 21.a).
/* types */
VALUES CAST('true' AS BOOLEAN);
-- COL1: TRUE (BOOLEAN)

VALUES CAST('  FaLsE ' AS BOOLEAN);
-- COL1: FALSE

VALUES CAST('unknown' AS BOOLEAN);
-- COL1: UNKNOWN

VALUES CAST(CAST('false' AS VARCHAR(10)) AS BOOLEAN);
-- COL1: FALSE

VALUES CAST(CAST(NULL AS VARCHAR(10)) AS BOOLEAN);
-- COL1: UNKNOWN

VALUES CAST('abc' AS BOOLEAN);
-- error 22018: invalid character value for cast

VALUES CAST('' AS BOOLEAN);
-- error 22018: invalid character value for cast

VALUES CAST('t' AS BOOLEAN);
-- error 22018: invalid character value for cast

VALUES CAST('1' AS BOOLEAN);
-- error 22018: invalid character value for cast

VALUES CAST('TRUE x' AS BOOLEAN);
-- error 22018: invalid character value for cast

-- # A BOOLEAN cast to a string is TRUE or FALSE, padded for a CHAR, and UNKNOWN
-- # is NULL. When the word doesn't fit it's an invalid character value (22018),
-- # not a truncation (General Rules, 11.f and 12.f).
/* types */
VALUES CAST(TRUE AS VARCHAR(10));
-- COL1: TRUE (CHARACTER VARYING(10))

VALUES CAST(FALSE AS CHAR(10)) || 'x';
-- COL1: FALSE     x

VALUES CAST(TRUE AS VARCHAR(4));
-- COL1: TRUE

VALUES CAST(UNKNOWN AS VARCHAR(10));
-- COL1: NULL

VALUES CAST(TRUE AS CHAR(3));
-- error 22018: invalid character value for cast

VALUES CAST(FALSE AS VARCHAR(4));
-- error 22018: invalid character value for cast

-- # The declared type of a CAST is the target type (Syntax Rules, 2).
/* extensions V001-01 */
EXPLAIN VALUES CAST(123 AS SMALLINT);
-- EXPLAIN: VALUES (COL1 SMALLINT) = ROW(CAST(123 AS SMALLINT))

-- # A string cast to a number is trimmed and must be a numeric literal, or it's
-- # an error (General Rules, 8.b.i and 9.b.i). It's then cast as that literal,
-- # so an approximate literal such as '1e2' can be cast to an INT (General
-- # Rules, 8.b.ii).
VALUES CAST('hello' AS DOUBLE PRECISION);
-- error 22018: invalid character value for cast

VALUES CAST('abc' AS INT);
-- error 22018: invalid character value for cast

VALUES CAST('12abc' AS INT);
-- error 22018: invalid character value for cast

VALUES CAST('abc' AS NUMERIC(5, 2));
-- error 22018: invalid character value for cast

VALUES CAST('' AS INT);
-- error 22018: invalid character value for cast

VALUES CAST('' AS NUMERIC(5, 2));
-- error 22018: invalid character value for cast

VALUES CAST('1e' AS INT);
-- error 22018: invalid character value for cast

/* types */
VALUES CAST(' 12 ' AS INT);
-- COL1: 12 (INTEGER)

VALUES CAST(' 1.5 ' AS NUMERIC(5, 2));
-- COL1: 1.50

VALUES CAST('-12' AS INT);
-- COL1: -12

VALUES CAST('+.5' AS NUMERIC(3, 2));
-- COL1: 0.50

VALUES CAST('1e2' AS INT);
-- COL1: 100

VALUES CAST('1e2' AS DOUBLE PRECISION);
-- COL1: 100e0

-- # A literal too large for a DOUBLE PRECISION or for the target is out of
-- # range, and one too small for a DOUBLE PRECISION is zero.
VALUES CAST('1e309' AS DOUBLE PRECISION);
-- error 22003: numeric value out of range

VALUES CAST('-1.5E400' AS INT);
-- error 22003: numeric value out of range

VALUES CAST('1e309' AS BIGINT);
-- error 22003: numeric value out of range

VALUES CAST('1e39' AS REAL);
-- error 22003: numeric value out of range

VALUES CAST('1e-400' AS DOUBLE PRECISION);
-- COL1: 0e0

VALUES CAST('1e-400' AS SMALLINT);
-- COL1: 0

VALUES CAST(' 1.5 ' AS DOUBLE PRECISION);
-- COL1: 1.5e0

VALUES CAST('99999' AS SMALLINT);
-- error 22003: numeric value out of range

-- # A BOOLEAN or a datetime can't be cast to a number (Syntax Rules, 7), or be
-- # stored in a numeric column.
VALUES CAST(TRUE AS FLOAT);
-- error 42846: cannot coerce BOOLEAN to DOUBLE PRECISION

VALUES CAST(TRUE AS INT);
-- error 42846: cannot coerce BOOLEAN to INTEGER

VALUES CAST(DATE '2020-01-01' AS INT);
-- error 42846: cannot coerce DATE to INTEGER

VALUES CAST(DATE '2020-01-01' AS DOUBLE PRECISION);
-- error 42846: cannot coerce DATE to DOUBLE PRECISION

VALUES CAST(DATE '2020-01-01' AS NUMERIC(5, 0));
-- error 42846: cannot coerce DATE to NUMERIC(5)

VALUES CAST(TIME '10:00:00' AS SMALLINT);
-- error 42846: cannot coerce TIME(0) WITHOUT TIME ZONE to SMALLINT

VALUES CAST(TIMESTAMP '2020-01-01 10:00:00+05:00' AS BIGINT);
-- error 42846: cannot coerce TIMESTAMP(0) WITH TIME ZONE to BIGINT

CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (DATE '2020-01-01');
INSERT INTO t (x) VALUES (TRUE);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- error 42846: cannot coerce DATE to INTEGER
-- error 42846: cannot coerce BOOLEAN to INTEGER

-- # A number too large for the target is out of range (General Rules, 8.a.ii),
-- # and an exact number cast to a VARCHAR must fit (General Rules, 12.a.iii.3).
VALUES CAST(60000 AS SMALLINT);
-- error 22003: numeric value out of range

VALUES CAST(12345 AS VARCHAR(10));
-- COL1: 12345

VALUES CAST(12345 AS VARCHAR(3));
-- error 22001: string data right truncation for CHARACTER VARYING(3)

-- # NUMERIC without a scale has a scale of 0 (6.1, Syntax Rules, 22), so the
-- # digits after the point are truncated.
VALUES CAST(123456789 AS DOUBLE PRECISION);
-- COL1: 1.23456789e+08

VALUES CAST(1.23 AS NUMERIC);
-- COL1: 1

-- # A datetime cast to a string is its whole literal, with the keyword and the
-- # fractional seconds of its precision (General Rules, 11.e.i.2 and 12.e.i.2).
-- # It's an error when that doesn't fit.
/* types */
VALUES CAST(DATE '2022-06-30' AS VARCHAR(20));
-- COL1: DATE '2022-06-30' (CHARACTER VARYING(20))

/* types */
VALUES CAST(DATE '2022-06-30' AS CHARACTER(20));
-- COL1: DATE '2022-06-30'    (CHARACTER(20))

VALUES CAST(DATE '2022-06-30' AS VARCHAR(10));
-- error 22001: string data right truncation for CHARACTER VARYING(10)

VALUES CAST(DATE '2022-06-30' AS CHARACTER(10));
-- error 22001: string data right truncation for CHARACTER(10)

/* types */
VALUES CAST(TIME '12:34:56' AS VARCHAR(40));
-- COL1: TIME '12:34:56' (CHARACTER VARYING(40))

/* types */
VALUES CAST(TIME '12:34:56.123' AS VARCHAR(40));
-- COL1: TIME '12:34:56.123' (CHARACTER VARYING(40))

/* types */
VALUES CAST(TIME '12:34:56-11:30' AS VARCHAR(40));
-- COL1: TIME '12:34:56-11:30' (CHARACTER VARYING(40))

/* types */
VALUES CAST(TIMESTAMP '2022-06-30 12:34:56' AS VARCHAR(40));
-- COL1: TIMESTAMP '2022-06-30 12:34:56' (CHARACTER VARYING(40))

/* types */
VALUES CAST(TIMESTAMP '2022-06-30 12:34:56.456000+05:12' AS VARCHAR(50));
-- COL1: TIMESTAMP '2022-06-30 12:34:56.456000+05:12' (CHARACTER VARYING(50))

VALUES CAST(TIMESTAMP '2022-06-30 12:34:56' AS VARCHAR(30));
-- error 22001: string data right truncation for CHARACTER VARYING(30)

-- # The target type must be valid: a length greater than 0 (6.1, Syntax Rules,
-- # 4) and a scale no greater than the precision (6.1, Syntax Rules, 23).
VALUES CAST('x' AS VARCHAR(0));
-- error 42601: syntax error: CHARACTER VARYING length must be greater than 0

VALUES CAST(1.23 AS NUMERIC(2, 3));
-- error 42601: syntax error: NUMERIC scale (3) must not be greater than precision (2)

-- # Only the most recent 100 warnings are kept.
CREATE TABLE t1 (x VARCHAR(10));
INSERT INTO t1 (x) VALUES ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab'), ('ab');
SELECT COUNT(CAST(x AS CHAR(1))) FROM t1;
-- msg: CREATE TABLE 1
-- msg: INSERT 101
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- COL1: 101
