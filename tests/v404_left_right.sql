-- # LEFT and RIGHT are vsql extensions (V404-16 and V404-17) for the first or
-- # last n characters of a character string, or octets of a binary string. Like
-- # PostgreSQL, a negative n is all but the last (LEFT) or first (RIGHT) -n.

/* setup */
CREATE TABLE t (id INT, s VARCHAR(10), c CHARACTER(5), b VARBINARY(10), f BLOB);
INSERT INTO t (id, s, c, b, f) VALUES (1, 'hello', 'ab', X'010203', X'0A0B'), (2, '', 'x y', X'', X''), (3, NULL, NULL, NULL, NULL);

/* types */
VALUES ROW(LEFT('hello', 2), RIGHT('hello', 3));
-- COL1: he (CHARACTER VARYING(5)) COL2: llo (CHARACTER VARYING(5))

VALUES ROW(LEFT('hello', -2), RIGHT('hello', -2));
-- COL1: hel COL2: llo

-- # n past the end is the whole string, and -n past the end is empty.
VALUES ROW(LEFT('abc', 10), RIGHT('abc', 10), LEFT('abc', -10), RIGHT('abc', -3), LEFT('abc', 0), RIGHT('', 1));
-- COL1: abc COL2: abc COL3:  COL4:  COL5:  COL6:

-- # They count characters, not bytes.
VALUES ROW(LEFT('😊£ab', 2), RIGHT('😊£ab', 3), LEFT('😊£ab', -1));
-- COL1: 😊£ COL2: £ab COL3: 😊£a

-- # A large object is a large object.
/* types */
VALUES ROW(LEFT(CAST('abc' AS CHARACTER LARGE OBJECT), 2), RIGHT(CAST('abc' AS CHARACTER LARGE OBJECT), -1));
-- COL1: ab (CHARACTER LARGE OBJECT) COL2: bc (CHARACTER LARGE OBJECT)

-- # A binary string is counted in octets, and keeps its type.
/* types */
VALUES ROW(LEFT(X'010203', 2), RIGHT(X'010203', -1), LEFT(CAST(X'0102' AS BLOB), 1), RIGHT(CAST(X'0102' AS BLOB), 5));
-- COL1: 0102 (BINARY VARYING(3)) COL2: 0203 (BINARY VARYING(3)) COL3: 01 (BINARY LARGE OBJECT) COL4: 0102 (BINARY LARGE OBJECT)

-- # A column is a varying string with the same length. A CHARACTER keeps its
-- # padding. NULL is NULL.
/* types */
SELECT id, LEFT(s, 2), RIGHT(c, 3) || '|', LEFT(b, -1), RIGHT(f, 1), LEFT(s, CAST(NULL AS INTEGER)) FROM t ORDER BY id;
-- ID: 1 (INTEGER) COL2: he (CHARACTER VARYING(10)) COL3:    | (CHARACTER VARYING(6)) COL4: 0102 (BINARY VARYING(10)) COL5: 0B (BINARY LARGE OBJECT) COL6: NULL (CHARACTER VARYING(10))
-- ID: 2 (INTEGER) COL2:  (CHARACTER VARYING(10)) COL3: y  | (CHARACTER VARYING(6)) COL4:  (BINARY VARYING(10)) COL5:  (BINARY LARGE OBJECT) COL6: NULL (CHARACTER VARYING(10))
-- ID: 3 (INTEGER) COL2: NULL (CHARACTER VARYING(10)) COL3: NULL (CHARACTER VARYING(6)) COL4: NULL (BINARY VARYING(10)) COL5: NULL (BINARY LARGE OBJECT) COL6: NULL (CHARACTER VARYING(10))

-- # LEFT and RIGHT are still joins.
SELECT * FROM (VALUES 1, 2) AS a (x) LEFT JOIN (VALUES 1) AS b (y) ON x = y RIGHT JOIN (VALUES 1, 2) AS c (z) ON x = z ORDER BY z;
-- X: 1 Y: 1 Z: 1
-- X: 2 Y: NULL Z: 2

-- # They're routines of the VSQL schema.
VALUES ROW(VSQL.LEFT('abc', 1), VSQL.RIGHT('abc', 1));
-- COL1: a COL2: c

-- # A dynamic parameter is a CHARACTER VARYING, and n is a BIGINT.
/* types */
/* params 'abc' 2 */
VALUES LEFT(?, ?);
-- sql: VALUES LEFT('abc', 2.0e0)
-- COL1: ab (CHARACTER VARYING(10485760))

-- # n must be an integer.
VALUES LEFT(123, 1);
VALUES RIGHT('abc', 1.5);
VALUES LEFT('abc');
-- error 42883: function does not exist: LEFT(INTEGER, INTEGER)
-- error 42883: function does not exist: RIGHT(CHARACTER(3), NUMERIC(2, 1))
-- error 42883: function does not exist: LEFT(CHARACTER(3))

-- # The flagger.
/* flags */
SELECT LEFT(s, 1), RIGHT(b, 1) FROM t WHERE id = 1;
-- flags: V404-16, V404-17
-- COL1: h COL2: 03
