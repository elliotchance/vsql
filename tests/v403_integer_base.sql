-- # INTEGER_TO_BASE, BASE_TO_INTEGER, INTEGER_TO_HEX and HEX_TO_INTEGER are vsql
-- # extensions (V403-18 to V403-21) that write an integer in another base
-- # (radix) from 2 to 36, and read it back.

-- # INTEGER_TO_BASE uses upper case digits, and a - in front of a negative
-- # number.
/* types */
VALUES ROW(INTEGER_TO_BASE(255, 2), INTEGER_TO_BASE(255, 8), INTEGER_TO_BASE(255, 16), INTEGER_TO_BASE(35, 36));
-- COL1: 11111111 (CHARACTER VARYING) COL2: 377 (CHARACTER VARYING) COL3: FF (CHARACTER VARYING) COL4: Z (CHARACTER VARYING)

VALUES ROW(INTEGER_TO_BASE(0, 2), INTEGER_TO_BASE(-10, 2), INTEGER_TO_BASE(1295, 36));
-- COL1: 0 COL2: -1010 COL3: ZZ

VALUES ROW(INTEGER_TO_HEX(9223372036854775807), INTEGER_TO_HEX(-9223372036854775808), INTEGER_TO_HEX(-1));
-- COL1: 7FFFFFFFFFFFFFFF COL2: -8000000000000000 COL3: -1

-- # Any exact integer can be converted, but not a number with a scale or an
-- # approximate number.
CREATE TABLE t (s SMALLINT, i INTEGER, b BIGINT);
INSERT INTO t VALUES (10, 100, 1000);
INSERT INTO t VALUES (NULL, NULL, NULL);
SELECT INTEGER_TO_HEX(s), INTEGER_TO_HEX(i), INTEGER_TO_BASE(b, i / 10) FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- COL1: A COL2: 64 COL3: 1000
-- COL1: NULL COL2: NULL COL3: NULL

VALUES INTEGER_TO_HEX(1.5);
-- error 42883: function does not exist: INTEGER_TO_HEX(NUMERIC(2, 1))

VALUES INTEGER_TO_HEX(1e0);
-- error 42883: function does not exist: INTEGER_TO_HEX(DOUBLE PRECISION)

-- # BASE_TO_INTEGER accepts upper or lower case digits, and a - in front, and
-- # is a BIGINT.
/* types */
VALUES ROW(BASE_TO_INTEGER('11111111', 2), BASE_TO_INTEGER('377', 8), BASE_TO_INTEGER('ff', 16), BASE_TO_INTEGER('zZ', 36));
-- COL1: 255 (BIGINT) COL2: 255 (BIGINT) COL3: 255 (BIGINT) COL4: 1295 (BIGINT)

VALUES ROW(HEX_TO_INTEGER('7FFFFFFFFFFFFFFF'), HEX_TO_INTEGER('-8000000000000000'), HEX_TO_INTEGER('-0'), HEX_TO_INTEGER('0001'));
-- COL1: 9223372036854775807 COL2: -9223372036854775808 COL3: 0 COL4: 1

VALUES BASE_TO_INTEGER(INTEGER_TO_BASE(-123456789, 7), 7);
-- COL1: -123456789

CREATE TABLE t (a CHAR(2), b VARCHAR(10));
INSERT INTO t VALUES ('10', 'ff');
INSERT INTO t VALUES (NULL, NULL);
SELECT BASE_TO_INTEGER(a, 2), HEX_TO_INTEGER(b) FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- COL1: 2 COL2: 255
-- COL1: NULL COL2: NULL

-- # A number that doesn't fit in a BIGINT is an error.
VALUES HEX_TO_INTEGER('8000000000000000');
-- error 22003: numeric value out of range

VALUES HEX_TO_INTEGER('-8000000000000001');
-- error 22003: numeric value out of range

VALUES BASE_TO_INTEGER('1Y2P0IJ32E8E8', 36);
-- error 22003: numeric value out of range

-- # A digit that isn't in the radix, or no digits, is an error.
VALUES BASE_TO_INTEGER('12', 2);
-- error 22018: invalid character value for cast

VALUES HEX_TO_INTEGER('FG');
-- error 22018: invalid character value for cast

VALUES HEX_TO_INTEGER('0x1F');
-- error 22018: invalid character value for cast

VALUES HEX_TO_INTEGER(' 1F');
-- error 22018: invalid character value for cast

VALUES HEX_TO_INTEGER('');
-- error 22018: invalid character value for cast

VALUES HEX_TO_INTEGER('-');
-- error 22018: invalid character value for cast

-- # A radix outside of 2 to 36 is an error.
VALUES INTEGER_TO_BASE(10, 1);
-- error 22003: numeric value out of range

VALUES INTEGER_TO_BASE(10, 37);
-- error 22003: numeric value out of range

VALUES BASE_TO_INTEGER('10', 37);
-- error 22003: numeric value out of range

-- # The flagger.
/* flags */
VALUES ROW(INTEGER_TO_BASE(5, 2), BASE_TO_INTEGER('101', 2), INTEGER_TO_HEX(255), HEX_TO_INTEGER('FF'));
-- flags: F641, F661, T051, V403-18, V403-19, V403-20, V403-21
-- COL1: 101 COL2: 5 COL3: FF COL4: 255
