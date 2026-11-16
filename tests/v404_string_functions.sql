-- # REPLACE, REPEAT, INITCAP, CHR, UNICODE and SPLIT_PART are vsql extensions
-- # (V404-02 to V404-07), the string functions that most other databases have
-- # but the standard doesn't. They follow PostgreSQL. The standard way to do
-- # REPLACE is TRANSLATE_REGEX (F845).

/* setup */
CREATE TABLE t (id INT, s VARCHAR(10), c CHARACTER(5));
INSERT INTO t (id, s, c) VALUES (1, 'red apple', 'ab'), (2, 'green', 'x y'), (3, NULL, NULL);
CREATE TABLE w (s VARCHAR(20), c CHARACTER(5), n INT);
INSERT INTO w (s, c, n) VALUES ('a,b,c', 'ab', 2);

-- # Every occurrence is replaced. The result is a CHARACTER VARYING without a
-- # maximum length, because it can be longer than the input.
/* types */
VALUES REPLACE('hello', 'l', 'L');
-- COL1: heLLo (CHARACTER VARYING)

VALUES REPLACE('a.b.c.d', '.', '::');
-- COL1: a::b::c::d

VALUES REPLACE('Hello', 'He', 'Je');
-- COL1: Jello

-- # The occurrences are found from left to right and don't overlap.
VALUES ROW(REPLACE('aaa', 'aa', 'b'), REPLACE('aaaa', 'aa', 'b'), REPLACE('abab', 'aba', 'X'));
-- COL1: ba COL2: bb COL3: Xb

-- # The replacement isn't searched again.
VALUES REPLACE('ab', 'a', 'aa');
-- COL1: aab

-- # Matching is case-sensitive.
VALUES REPLACE('Hello hello', 'hello', 'bye');
-- COL1: Hello bye

-- # No match returns the string unchanged.
VALUES REPLACE('hello', 'x', 'y');
-- COL1: hello

-- # An empty from returns the string unchanged.
VALUES ROW(REPLACE('hello', '', 'x'), REPLACE('', '', 'x'));
-- COL1: hello COL2:

-- # An empty to removes each occurrence.
VALUES REPLACE('banana', 'an', '');
-- COL1: ba

VALUES REPLACE('', 'a', 'b');
-- COL1:

-- # Any NULL argument is NULL.
/* types */
VALUES ROW(REPLACE(CAST(NULL AS VARCHAR(5)), 'a', 'b'), REPLACE('abc', CAST(NULL AS VARCHAR(5)), 'b'), REPLACE('abc', 'a', CAST(NULL AS VARCHAR(5))));
-- COL1: NULL (CHARACTER VARYING) COL2: NULL (CHARACTER VARYING) COL3: NULL (CHARACTER VARYING)

-- # The padding of a CHARACTER is searched like any other character, and the
-- # result is a CHARACTER VARYING.
/* types */
VALUES REPLACE(CAST('ab' AS CHARACTER(5)), ' ', '.');
-- COL1: ab... (CHARACTER VARYING)

SELECT REPLACE(c, 'b', 'B') || '|' FROM t WHERE id = 1;
-- COL1: aB   |

-- # Characters are compared, not bytes, so a multibyte character is matched
-- # whole.
VALUES REPLACE('😊£😊', '😊', 'é');
-- COL1: é£é

VALUES ROW(CHAR_LENGTH(REPLACE('Жab', 'ab', 'ڣڣ')), REPLACE('Жab', 'Ж', ''));
-- COL1: 3 COL2: ab

-- # The result can be longer than the declared length of the string.
SELECT REPLACE(s, 'e', 'eeee') FROM t WHERE id = 1;
-- COL1: reeeed appleeee

-- # A result that's stored in a column is checked against that column.
CREATE TABLE u (s VARCHAR(3));
INSERT INTO u (s) VALUES (REPLACE('ab', 'b', 'bb'));
INSERT INTO u (s) VALUES (REPLACE('ab', 'b', 'bbbb'));
SELECT * FROM u;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 22001: string data right truncation for CHARACTER VARYING(3)
-- S: abb

-- # It works with columns and in a WHERE.
SELECT id, REPLACE(s, ' ', '_') AS r FROM t;
-- ID: 1 R: red_apple
-- ID: 2 R: green
-- ID: 3 R: NULL

SELECT id FROM t WHERE REPLACE(s, 'e', '') = 'grn';
-- ID: 2

SELECT id FROM t WHERE REPLACE(c, ' ', '') = 'xy';
-- ID: 2

-- # The arguments must be strings.
VALUES REPLACE(123, '2', 'x');
-- error 42883: function does not exist: REPLACE(SMALLINT, CHARACTER(1), CHARACTER(1))

VALUES REPLACE('abc', 'b');
-- error 42883: function does not exist: REPLACE(CHARACTER(3), CHARACTER(1))

-- # It's deterministic, so it can be in a CHECK.
CREATE TABLE c (a VARCHAR(10), CHECK (REPLACE(a, 'x', '') <> ''));
INSERT INTO c (a) VALUES ('axb');
INSERT INTO c (a) VALUES ('xx');
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 23514: violates check constraint: CHECK (REPLACE(A, 'x', '') <> '') on ":memory:".PUBLIC.C

-- # REPLACE isn't reserved.
CREATE TABLE replace (replace VARCHAR(10));
INSERT INTO replace (replace) VALUES ('aXa');
SELECT REPLACE(replace, 'X', 'b') FROM replace;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: aba

-- # REPEAT repeats the string n times. It has no maximum length.
/* types */
VALUES ROW(REPEAT('ab', 3), REPEAT('é😊', 2), REPEAT('ab', 1), REPEAT('', 5));
-- COL1: ababab (CHARACTER VARYING) COL2: é😊é😊 (CHARACTER VARYING) COL3: ab (CHARACTER VARYING) COL4:  (CHARACTER VARYING)

-- # A count that isn't positive is an empty string.
/* types */
VALUES ROW(REPEAT('ab', 0), REPEAT('ab', -3), REPEAT('ab', -9223372036854775807));
-- COL1:  (CHARACTER VARYING) COL2:  (CHARACTER VARYING) COL3:  (CHARACTER VARYING)

-- # A NULL argument is NULL.
/* types */
VALUES ROW(REPEAT(CAST(NULL AS VARCHAR(5)), 2), REPEAT('ab', CAST(NULL AS INT)));
-- COL1: NULL (CHARACTER VARYING) COL2: NULL (CHARACTER VARYING)

-- # The padding of a CHARACTER is repeated too.
SELECT REPEAT(c, 2), CHAR_LENGTH(REPEAT(c, 2)) FROM w;
-- COL1: ab   ab    COL2: 10

-- # The result can be up to the maximum length of a CHARACTER VARYING
-- # (10485760 characters), counted in characters, not bytes.
VALUES CHAR_LENGTH(REPEAT('😊', 10485760));
-- COL1: 10485760

VALUES CHAR_LENGTH(REPEAT('😊', 10485761));
-- error 22001: string data right truncation for CHARACTER VARYING(10485760)

VALUES CHAR_LENGTH(REPEAT('ab', 9223372036854775807));
-- error 22001: string data right truncation for CHARACTER VARYING(10485760)

SELECT REPEAT(s, n) FROM w;
-- COL1: a,b,ca,b,c

-- # The count must be an integer.
VALUES REPEAT('a', 1.5);
-- error 42883: function does not exist: REPEAT(CHARACTER(1), NUMERIC(2, 1))

-- # INITCAP makes the first letter of each word upper case and the rest lower
-- # case. A word is a run of letters and digits.
/* types */
VALUES ROW(INITCAP('hELLO wORLD'), INITCAP('o''neil mc-donald'), INITCAP('2nd place_x'));
-- COL1: Hello World (CHARACTER(11)) COL2: O'Neil Mc-Donald (CHARACTER(16)) COL3: 2nd Place_X (CHARACTER(11))

-- # It uses the same Unicode case mappings as UPPER and LOWER, so a character
-- # may become several characters.
VALUES ROW(INITCAP('éCOLE ÀÉ'), INITCAP('😊abc'), INITCAP(CAST('ßa' AS VARCHAR(5))), INITCAP(''));
-- COL1: École Àé COL2: 😊Abc COL3: SSa COL4:

-- # It has the declared type of its operand, so a CHARACTER keeps its padding
-- # and a result longer than the type is truncated with a warning.
/* types */
SELECT INITCAP(c), INITCAP(s), INITCAP(CAST('ßa' AS VARCHAR(2))) FROM w;
-- warning 01004: string data, right truncation
-- COL1: Ab    (CHARACTER(5)) COL2: A,B,C (CHARACTER VARYING(20)) COL3: SS (CHARACTER VARYING(2))

/* types */
VALUES INITCAP(CAST(NULL AS VARCHAR(5)));
-- COL1: NULL (CHARACTER VARYING(5))

-- # CHR is the character with a Unicode code point.
/* types */
VALUES ROW(CHR(65), CHR(233), CHR(128522), CHR(1114109), CHR(CAST(NULL AS INT)));
-- COL1: A (CHARACTER VARYING(1)) COL2: é (CHARACTER VARYING(1)) COL3: 😊 (CHARACTER VARYING(1)) COL4: 􏿽 (CHARACTER VARYING(1)) COL5: NULL (CHARACTER VARYING(1))

SELECT CHR(n + 63) FROM w;
-- COL1: A

-- # 0, a negative number, a surrogate or a number above U+10FFFF is an error.
VALUES CHR(0);
-- error 22023: invalid parameter value: CHR: 0 is not a valid Unicode code point

VALUES CHR(-65);
-- error 22023: invalid parameter value: CHR: -65 is not a valid Unicode code point

VALUES CHR(55296);
-- error 22023: invalid parameter value: CHR: 55296 is not a valid Unicode code point

VALUES CHR(57343);
-- error 22023: invalid parameter value: CHR: 57343 is not a valid Unicode code point

VALUES CHR(1114112);
-- error 22023: invalid parameter value: CHR: 1114112 is not a valid Unicode code point

VALUES CHAR_LENGTH(CHR(57344));
-- COL1: 1

-- # A noncharacter can't be in a string, like U&'\FFFF'.
VALUES CHR(65535);
-- error 22029: non-character in character string

-- # UNICODE is the Unicode code point of the first character, or 0 for an empty
-- # string.
/* types */
VALUES ROW(UNICODE('A'), UNICODE('abc'), UNICODE('é'), UNICODE('😊x'), UNICODE(''), UNICODE(CAST(NULL AS VARCHAR(5))));
-- COL1: 65 (INTEGER) COL2: 97 (INTEGER) COL3: 233 (INTEGER) COL4: 128522 (INTEGER) COL5: 0 (INTEGER) COL6: NULL (INTEGER)

-- # The padding of an empty CHARACTER is a space.
SELECT UNICODE(c), UNICODE(CAST('' AS CHARACTER(3))), UNICODE(CHR(128522)) FROM w;
-- COL1: 97 COL2: 32 COL3: 128522

-- # SPLIT_PART is the nth field of the string split on the delimiter, from 1.
-- # It's a CHARACTER VARYING with the length of the string, like SUBSTRING.
/* types */
SELECT SPLIT_PART(s, ',', 1), SPLIT_PART(s, ',', 3), SPLIT_PART(s, ',', n) FROM w;
-- COL1: a (CHARACTER VARYING(20)) COL2: c (CHARACTER VARYING(20)) COL3: b (CHARACTER VARYING(20))

-- # A negative n counts from the end.
VALUES ROW(SPLIT_PART('a,b,c', ',', -1), SPLIT_PART('a,b,c', ',', -3));
-- COL1: c COL2: a

-- # A field that doesn't exist is an empty string.
VALUES ROW(SPLIT_PART('a,b,c', ',', 4), SPLIT_PART('a,b,c', ',', -4), SPLIT_PART('a,b,c', ',', 9223372036854775807), SPLIT_PART('a,b,c', ',', -9223372036854775807), SPLIT_PART('', ',', 1));
-- COL1:  COL2:  COL3:  COL4:  COL5:

-- # Fields can be empty, and the delimiter can be several characters. It's
-- # matched as plain text, case-sensitive.
VALUES ROW(SPLIT_PART('a,,c', ',', 2), SPLIT_PART('a<>b<>c', '<>', 2), SPLIT_PART('aXbxc', 'x', 1), SPLIT_PART('a%b', '%', 2), SPLIT_PART('a.b', '_', 1));
-- COL1:  COL2: b COL3: aXb COL4: b COL5: a.b

-- # Characters, not bytes.
VALUES ROW(SPLIT_PART('é😊ü😊ö', '😊', 2), SPLIT_PART('naïve', 'ï', -1));
-- COL1: ü COL2: ve

-- # An empty delimiter doesn't split the string, so it's the only field.
VALUES ROW(SPLIT_PART('abc', '', 1), SPLIT_PART('abc', '', -1), SPLIT_PART('abc', '', 2), SPLIT_PART('abc', '', -2));
-- COL1: abc COL2: abc COL3:  COL4:

-- # The padding of a CHARACTER is part of the last field.
SELECT SPLIT_PART(c, 'a', 2) || '|', SPLIT_PART('a,b', CAST(',' AS CHARACTER(2)), 1) FROM w;
-- COL1: b   | COL2: a,b

-- # n can't be 0.
VALUES SPLIT_PART('a,b', ',', 0);
-- error 22023: invalid parameter value: SPLIT_PART: field position must not be zero

/* types */
VALUES ROW(SPLIT_PART(CAST(NULL AS VARCHAR(5)), ',', 1), SPLIT_PART('a', CAST(NULL AS VARCHAR(5)), 1), SPLIT_PART('a', ',', CAST(NULL AS INT)));
-- COL1: NULL (CHARACTER VARYING(5)) COL2: NULL (CHARACTER VARYING(1)) COL3: NULL (CHARACTER VARYING(1))

-- # None of the names are reserved.
CREATE TABLE repeat (repeat INT, initcap INT, chr INT, unicode INT, split_part INT);
INSERT INTO repeat (repeat, initcap, chr, unicode, split_part) VALUES (1, 2, 3, 4, 5);
SELECT repeat, split_part FROM repeat;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- REPEAT: 1 SPLIT_PART: 5

-- # The flagger.
/* flags */
SELECT REPLACE(s, 'apple', 'pear') FROM t WHERE id = 1;
-- flags: V404-02
-- COL1: red pear

/* flags */
SELECT REPEAT(s, 2), INITCAP(s), CHR(n + 63), UNICODE(s), SPLIT_PART(s, ',', 2) FROM w;
-- flags: V404-03, V404-04, V404-05, V404-06, V404-07
-- COL1: a,b,ca,b,c COL2: A,B,C COL3: A COL4: 97 COL5: b
