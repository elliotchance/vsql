-- # LENGTH is a vsql extension (V404-10), another name for CHAR_LENGTH. Most
-- # databases call it LENGTH. Like PostgreSQL and SQLite, the length of a binary
-- # string is its number of octets, like OCTET_LENGTH.

/* setup */
CREATE TABLE t (id INT, s VARCHAR(10), c CHARACTER(5), b VARBINARY(10), f BLOB);
INSERT INTO t (id, s, c, b, f) VALUES (1, 'hello', 'ab', X'0102', X'010203'), (2, '', 'x y', X'', X''), (3, NULL, NULL, NULL, NULL);

-- # It counts characters, not bytes, so a multibyte character counts as one.
/* types */
VALUES ROW(LENGTH('hello'), LENGTH('😊£'), LENGTH(''));
-- COL1: 5 (INTEGER) COL2: 2 (INTEGER) COL3: 0 (INTEGER)

-- # Spaces at the end count, and so does the padding of a CHARACTER, like
-- # CHAR_LENGTH.
VALUES ROW(LENGTH('ab  '), LENGTH(CAST('ab' AS CHARACTER(5))), CHAR_LENGTH(CAST('ab' AS CHARACTER(5))));
-- COL1: 4 COL2: 5 COL3: 5

-- # A binary string is counted in octets.
/* types */
VALUES ROW(LENGTH(X'010203'), LENGTH(X''), LENGTH(CAST(X'0102' AS BINARY(4))), LENGTH(CAST(X'01' AS BLOB)));
-- COL1: 3 (INTEGER) COL2: 0 (INTEGER) COL3: 4 (INTEGER) COL4: 1 (INTEGER)

-- # Columns, and NULL is NULL.
/* types */
SELECT id, LENGTH(s), LENGTH(c), LENGTH(b), LENGTH(f) FROM t ORDER BY id;
-- ID: 1 (INTEGER) COL2: 5 (INTEGER) COL3: 5 (INTEGER) COL4: 2 (INTEGER) COL5: 3 (INTEGER)
-- ID: 2 (INTEGER) COL2: 0 (INTEGER) COL3: 5 (INTEGER) COL4: 0 (INTEGER) COL5: 0 (INTEGER)
-- ID: 3 (INTEGER) COL2: NULL (INTEGER) COL3: NULL (INTEGER) COL4: NULL (INTEGER) COL5: NULL (INTEGER)

-- # It's a routine of the VSQL schema.
VALUES VSQL.LENGTH('abc');
-- COL1: 3

-- # A dynamic parameter is a CHARACTER VARYING, like the argument of
-- # CHAR_LENGTH.
/* types */
/* params 'abcde' */
VALUES LENGTH(?);
-- sql: VALUES LENGTH('abcde')
-- COL1: 5 (INTEGER)

-- # A number isn't a string.
VALUES LENGTH(123);
-- error 42883: function does not exist: LENGTH(INTEGER)

-- # The flagger.
/* flags */
SELECT LENGTH(s), LENGTH(b) FROM t WHERE id = 1;
-- flags: V404-10
-- COL1: 5 COL2: 2
