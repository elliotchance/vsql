-- # A VARCHAR keeps only the characters it was given, so casting it to a longer
-- # VARCHAR doesn't pad it (6.13, General Rules, 12.d.i), but casting to
-- # CHAR(10) does (6.13, General Rules, 11.d.iii). A shorter VARCHAR cuts it
-- # off with a warning (6.13, General Rules, 12.d.ii).
CREATE TABLE foo (x CHARACTER VARYING(8));
INSERT INTO foo (x) VALUES ('hello');
SELECT CAST(x AS VARCHAR(10)), CHARACTER_LENGTH(CAST(x AS VARCHAR(10))) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: hello COL2: 5

CREATE TABLE foo (x CHARACTER VARYING(8));
INSERT INTO foo (x) VALUES ('hello');
SELECT CAST(x AS VARCHAR(4)) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- warning 01004: string data, right truncation
-- COL1: hell

CREATE TABLE foo (x CHARACTER VARYING(8));
INSERT INTO foo (x) VALUES ('hello');
SELECT CAST(x AS CHAR(10)), CHARACTER_LENGTH(CAST(x AS CHAR(10))) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: hello      COL2: 10

-- # A CHAR and a VARCHAR of the same length compare by their characters.
VALUES CAST('ABC' AS CHAR(3)) = CAST('ABC' AS VARCHAR(3));
-- COL1: TRUE

VALUES CAST('ABC' AS CHAR(3)) = CAST('DEF' AS VARCHAR(3));
-- COL1: FALSE

-- # A value that's too long can only lose spaces, which is the only <truncating
-- # whitespace> (5.2, Syntax Rules, 4), not a tab.
CREATE TABLE foo (x VARCHAR(2));
INSERT INTO foo (x) VALUES ('ab  ');
INSERT INTO foo (x) VALUES (U&'ab\0009');
SELECT x || '|' FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 22001: string data right truncation for CHARACTER VARYING(2)
-- COL1: ab|
