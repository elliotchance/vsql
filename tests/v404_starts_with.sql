-- # STARTS_WITH and ENDS_WITH are vsql extensions (V404-12 and V404-13) that
-- # test if a string starts or ends with another one. Unlike LIKE, no character
-- # is special, and unlike =, nothing is padded.

/* setup */
CREATE TABLE t (id INT, s VARCHAR(20), p VARCHAR(10), c CHARACTER(5), b VARBINARY(10), f BLOB);
INSERT INTO t (id, s, p, c, b, f) VALUES (1, 'report.csv', 'rep', 'ab', X'010203', X'0102'), (2, '50%_off', '50%', 'x', X'', X''), (3, NULL, NULL, NULL, NULL, NULL);

/* types */
VALUES ROW(STARTS_WITH('hello world', 'hello'), ENDS_WITH('report.csv', '.csv'));
-- COL1: TRUE (BOOLEAN) COL2: TRUE (BOOLEAN)

-- # Not a match.
VALUES ROW(STARTS_WITH('hello world', 'world'), ENDS_WITH('report.csv', 'report'), STARTS_WITH('Hello', 'hello'), ENDS_WITH('abc', 'B'));
-- COL1: FALSE COL2: FALSE COL3: FALSE COL4: FALSE

-- # % and _ are compared like any other character.
VALUES ROW(STARTS_WITH('100%', '100%'), STARTS_WITH('1000', '10%'), STARTS_WITH('a_c', 'a_'), STARTS_WITH('abc', 'a_'), ENDS_WITH('a%b', '%b'), ENDS_WITH('ab', '_b'), STARTS_WITH('a\b', 'a\'));
-- COL1: TRUE COL2: FALSE COL3: TRUE COL4: FALSE COL5: TRUE COL6: FALSE COL7: TRUE

-- # An empty prefix or suffix is always TRUE, and an empty string only starts
-- # and ends with an empty string.
VALUES ROW(STARTS_WITH('abc', ''), ENDS_WITH('abc', ''), STARTS_WITH('', ''), ENDS_WITH('', ''), STARTS_WITH('', 'a'), ENDS_WITH('', 'a'));
-- COL1: TRUE COL2: TRUE COL3: TRUE COL4: TRUE COL5: FALSE COL6: FALSE

-- # A prefix or suffix that's longer than the string, or the string itself.
VALUES ROW(STARTS_WITH('ab', 'abc'), ENDS_WITH('bc', 'abc'), STARTS_WITH('abc', 'abc'), ENDS_WITH('abc', 'abc'));
-- COL1: FALSE COL2: FALSE COL3: TRUE COL4: TRUE

-- # Multibyte characters are compared by code point.
VALUES ROW(STARTS_WITH('😊£x', '😊'), STARTS_WITH('😊£x', '😊£'), ENDS_WITH('x😊£', '£'), ENDS_WITH('é', 'e'), STARTS_WITH('é', 'e'));
-- COL1: TRUE COL2: TRUE COL3: TRUE COL4: FALSE COL5: FALSE

-- # The padding of a CHARACTER counts, unlike with =, and so do spaces at the
-- # end.
VALUES ROW(ENDS_WITH(CAST('ab' AS CHARACTER(5)), 'b'), ENDS_WITH(CAST('ab' AS CHARACTER(5)), 'b   '), STARTS_WITH('ab', CAST('ab' AS CHARACTER(3))), CAST('ab' AS CHARACTER(5)) = 'ab', ENDS_WITH('ab ', 'b'));
-- COL1: FALSE COL2: TRUE COL3: FALSE COL4: TRUE COL5: FALSE

-- # Either argument NULL is NULL (UNKNOWN).
/* types */
SELECT id, STARTS_WITH(s, p), ENDS_WITH(s, 'csv'), STARTS_WITH('report', p), ENDS_WITH(c, ' ') FROM t ORDER BY id;
-- ID: 1 (INTEGER) COL2: TRUE (BOOLEAN) COL3: TRUE (BOOLEAN) COL4: TRUE (BOOLEAN) COL5: TRUE (BOOLEAN)
-- ID: 2 (INTEGER) COL2: TRUE (BOOLEAN) COL3: FALSE (BOOLEAN) COL4: FALSE (BOOLEAN) COL5: TRUE (BOOLEAN)
-- ID: 3 (INTEGER) COL2: UNKNOWN (BOOLEAN) COL3: UNKNOWN (BOOLEAN) COL4: UNKNOWN (BOOLEAN) COL5: UNKNOWN (BOOLEAN)

-- # It can be a search condition, with a prefix from a column that has a %.
SELECT id FROM t WHERE STARTS_WITH(s, p) AND NOT ENDS_WITH(s, '.csv');
-- ID: 2

-- # Binary strings are compared by octet.
VALUES ROW(STARTS_WITH(X'010203', X'0102'), ENDS_WITH(X'010203', X'0203'), STARTS_WITH(X'010203', X'02'), ENDS_WITH(X'01', X''), STARTS_WITH(CAST(X'01' AS BINARY(2)), X'0100'));
-- COL1: TRUE COL2: TRUE COL3: FALSE COL4: TRUE COL5: TRUE

SELECT STARTS_WITH(b, f), ENDS_WITH(f, b), STARTS_WITH(f, f), ENDS_WITH(b, X'03') FROM t WHERE id = 1;
-- COL1: TRUE COL2: FALSE COL3: TRUE COL4: TRUE

-- # A character string isn't a binary string.
VALUES STARTS_WITH(X'0102', 'a');
VALUES ENDS_WITH('a', 1);
-- error 42883: function does not exist: STARTS_WITH(BINARY(2), CHARACTER(1))
-- error 42883: function does not exist: ENDS_WITH(CHARACTER(1), INTEGER)

-- # A dynamic parameter has the type of the other argument.
/* types */
/* params 'rep' */
SELECT STARTS_WITH(s, ?) FROM t WHERE id = 1;
-- sql: SELECT STARTS_WITH(s, 'rep') FROM t WHERE id = 1
-- COL1: TRUE (BOOLEAN)

-- # They're routines of the VSQL schema.
VALUES ROW(VSQL.STARTS_WITH('abc', 'a'), VSQL.ENDS_WITH('abc', 'c'));
-- COL1: TRUE COL2: TRUE

-- # The flagger. T021 is for the binary strings.
/* flags */
SELECT STARTS_WITH(s, p), ENDS_WITH(b, X'03') FROM t WHERE id = 1;
-- flags: T021, V404-12, V404-13
-- COL1: TRUE COL2: TRUE
