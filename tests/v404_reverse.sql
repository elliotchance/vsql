-- # REVERSE is a vsql extension (V404-11) that reverses a character string (by
-- # code point) or a binary string (by octet). The result has the type of the
-- # argument.

/* setup */
CREATE TABLE t (id INT, s VARCHAR(10), c CHARACTER(5), b VARBINARY(10), f BLOB);
INSERT INTO t (id, s, c, b, f) VALUES (1, 'hello', 'ab', X'010203', X'0A0B'), (2, '', 'x y', X'', X''), (3, NULL, NULL, NULL, NULL);

/* types */
VALUES REVERSE('hello');
-- COL1: olleh (CHARACTER(5))

-- # A multibyte character is reversed as one character.
VALUES ROW(REVERSE('😊£ab'), REVERSE('a'), REVERSE(''));
-- COL1: ba£😊 COL2: a COL3:

-- # A character made of several code points is split up: the combining accent
-- # (U+0301) after the e ends up before it.
VALUES ROW(UNICODE(REVERSE(CHR(101) || CHR(769) || 'x')), UNICODE(SUBSTRING(REVERSE(CHR(101) || CHR(769) || 'x') FROM 2)), UNICODE(SUBSTRING(REVERSE(CHR(101) || CHR(769) || 'x') FROM 3)));
-- COL1: 120 COL2: 769 COL3: 101

-- # A binary string is reversed by octet.
/* types */
VALUES ROW(REVERSE(X'010203'), REVERSE(X''), REVERSE(CAST(X'01' AS BINARY(3))), REVERSE(CAST(X'0102' AS BLOB)));
-- COL1: 030201 (BINARY(3)) COL2:  (BINARY(0)) COL3: 000001 (BINARY(3)) COL4: 0201 (BINARY LARGE OBJECT)

-- # Columns keep their type, and the padding of a CHARACTER is reversed too.
-- # NULL is NULL.
/* types */
SELECT id, REVERSE(s), REVERSE(c) || '|', REVERSE(b), REVERSE(f) FROM t ORDER BY id;
-- ID: 1 (INTEGER) COL2: olleh (CHARACTER VARYING(10)) COL3:    ba| (CHARACTER(6)) COL4: 030201 (BINARY VARYING(10)) COL5: 0B0A (BINARY LARGE OBJECT)
-- ID: 2 (INTEGER) COL2:  (CHARACTER VARYING(10)) COL3:   y x| (CHARACTER(6)) COL4:  (BINARY VARYING(10)) COL5:  (BINARY LARGE OBJECT)
-- ID: 3 (INTEGER) COL2: NULL (CHARACTER VARYING(10)) COL3: NULL (CHARACTER(6)) COL4: NULL (BINARY VARYING(10)) COL5: NULL (BINARY LARGE OBJECT)

-- # Reversing twice gives the same value.
SELECT REVERSE(REVERSE(s)) = s, REVERSE(REVERSE(b)) = b FROM t WHERE id = 1;
-- COL1: TRUE COL2: TRUE

-- # It's a routine of the VSQL schema.
VALUES VSQL.REVERSE('abc');
-- COL1: cba

-- # A dynamic parameter is a CHARACTER VARYING.
/* types */
/* params 'abc' */
VALUES REVERSE(?);
-- sql: VALUES REVERSE('abc')
-- COL1: cba (CHARACTER VARYING(10485760))

-- # A number isn't a string.
VALUES REVERSE(123);
-- error 42883: function does not exist: REVERSE(INTEGER)

-- # The flagger.
/* flags */
SELECT REVERSE(s), REVERSE(b) FROM t WHERE id = 1;
-- flags: V404-11
-- COL1: olleh COL2: 030201
