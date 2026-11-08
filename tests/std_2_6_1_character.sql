-- # A CHARACTER(8) value is padded with spaces to 8 characters when it's stored
-- # (9.2, General Rules, 3.b.iii). Casting it to a long enough VARCHAR keeps
-- # those spaces (6.13, General Rules, 12.d.i), so the length is 8, not 5.
CREATE TABLE foo (x CHARACTER(8));
INSERT INTO foo (x) VALUES ('hello');
SELECT x, CHARACTER_LENGTH(CAST(x AS VARCHAR(10))) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- X: hello    COL2: 8

CREATE TABLE foo (x CHARACTER(8));
INSERT INTO foo (x) VALUES ('hello');
SELECT CAST(x AS VARCHAR(10)), CHARACTER_LENGTH(CAST(x AS VARCHAR(10))) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: hello    COL2: 8

-- # Casting to a shorter VARCHAR cuts it off with a warning, because non-space
-- # characters are lost (6.13, General Rules, 12.d.ii). Casting to a longer
-- # CHAR pads it further (6.13, General Rules, 11.d.iii).
CREATE TABLE foo (x CHARACTER(8));
INSERT INTO foo (x) VALUES ('hello');
SELECT CAST(x AS VARCHAR(4)) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- warning 01004: string data, right truncation
-- COL1: hell

CREATE TABLE foo (x CHARACTER(8));
INSERT INTO foo (x) VALUES ('hello');
SELECT CAST(x AS CHAR(10)), CHARACTER_LENGTH(CAST(x AS CHAR(10))) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: hello      COL2: 10

-- # An empty string is stored as all spaces, and CHARACTER without a length is
-- # CHARACTER(1) (Syntax Rules, 5).
CREATE TABLE foo (x CHARACTER(5));
INSERT INTO foo (x) VALUES ('');
SELECT x || '|', CHARACTER_LENGTH(x) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1:      | COL2: 5

CREATE TABLE foo (x CHARACTER);
INSERT INTO foo (x) VALUES ('a');
SELECT x || '|', CHARACTER_LENGTH(x) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: a| COL2: 1

-- # A longer string can only be stored if the extra characters are all spaces,
-- # which are dropped (9.2, General Rules, 3.b.ii.1). Otherwise it's an error
-- # (9.2, General Rules, 3.b.ii.2). UPDATE pads a shorter value the same way as
-- # INSERT, and a NULL isn't padded.
CREATE TABLE foo (x CHARACTER(5));
INSERT INTO foo (x) VALUES ('ab ');
INSERT INTO foo (x) VALUES ('abcde   ');
SELECT x || '|' FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- COL1: ab   |
-- COL1: abcde|

CREATE TABLE foo (x CHARACTER(5));
INSERT INTO foo (x) VALUES ('abcdef');
-- msg: CREATE TABLE 1
-- error 22001: string data right truncation for CHARACTER(5)

CREATE TABLE foo (x CHARACTER(5));
INSERT INTO foo (x) VALUES ('abcde');
UPDATE foo SET x = 'z';
SELECT x || '|', CHARACTER_LENGTH(x) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: UPDATE 1
-- COL1: z    | COL2: 5

CREATE TABLE foo (x CHARACTER(5));
INSERT INTO foo (x) VALUES (NULL);
SELECT x FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- X: NULL

-- # Comparing strings pads the shorter one with spaces (8.2, General Rules,
-- # 3.b), so 'ab' in a CHARACTER(5) equals 'ab', 'ab ' and the VARCHAR 'ab',
-- # and is neither less nor greater than them.
CREATE TABLE foo (x CHARACTER(5), y CHARACTER VARYING(5));
INSERT INTO foo (x, y) VALUES ('ab', 'ab');
SELECT x = 'ab', x = 'ab ', x = y, x < 'ab ', x > 'ab' FROM foo;
SELECT y FROM foo WHERE x = 'ab';
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: TRUE COL2: TRUE COL3: TRUE COL4: FALSE COL5: FALSE
-- Y: ab

-- # Both values are stored as 'a  ', so they're one group.
CREATE TABLE foo (x CHARACTER(3), y INT);
INSERT INTO foo (x, y) VALUES ('a', 1);
INSERT INTO foo (x, y) VALUES ('a  ', 2);
SELECT x || '|', COUNT(*) FROM foo GROUP BY x;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- COL1: a  | COL2: 2
