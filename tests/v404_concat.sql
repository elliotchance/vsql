-- # CONCAT and CONCAT_WS are vsql extensions (V404-08 and V404-09) that join any
-- # number of character strings, leaving out the ones that are NULL. The
-- # standard way is ||, which is NULL if either side is.

/* setup */
CREATE TABLE t (id INT, s VARCHAR(10), c CHARACTER(5));
INSERT INTO t (id, s, c) VALUES (1, 'red', 'ab'), (2, NULL, 'x y'), (3, NULL, NULL);

-- # The result is a CHARACTER VARYING as long as all of the arguments.
/* types */
VALUES CONCAT('My', 'S', 'QL');
-- COL1: MySQL (CHARACTER VARYING(5))

VALUES CONCAT('abc');
-- COL1: abc

-- # A NULL is left out, rather than making the result NULL. (A NULL has to be
-- # CAST, as it does for every function.)
/* types */
VALUES CONCAT('abcde', CAST(NULL AS VARCHAR(1)), 'xy');
-- COL1: abcdexy (CHARACTER VARYING(8))

VALUES ROW(CONCAT(CAST(NULL AS VARCHAR(1))), CONCAT(CAST(NULL AS VARCHAR(1)), CAST(NULL AS VARCHAR(1))) IS NULL);
-- COL1:  COL2: FALSE

VALUES CONCAT(CAST(NULL AS VARCHAR(10)), 'a', CAST(NULL AS CLOB));
-- COL1: a

-- # A CHARACTER keeps its padding, like it does with ||, but the result is a
-- # CHARACTER VARYING.
/* types */
SELECT id, CONCAT('[', c, ']'), CONCAT(s, '-', c) FROM t ORDER BY id;
-- ID: 1 (INTEGER) COL2: [ab   ] (CHARACTER VARYING(7)) COL3: red-ab    (CHARACTER VARYING(16))
-- ID: 2 (INTEGER) COL2: [x y  ] (CHARACTER VARYING(7)) COL3: -x y   (CHARACTER VARYING(16))
-- ID: 3 (INTEGER) COL2: [] (CHARACTER VARYING(7)) COL3: - (CHARACTER VARYING(16))

-- # The separator goes between the values that aren't NULL, so there's never
-- # two next to each other.
/* types */
VALUES CONCAT_WS(', ', 'a', 'bc', 'def');
-- COL1: a, bc, def (CHARACTER VARYING(10))

VALUES CONCAT_WS(',', CAST(NULL AS VARCHAR(1)), 'a', CAST(NULL AS VARCHAR(1)), CAST(NULL AS VARCHAR(1)), 'b', CAST(NULL AS VARCHAR(1)));
-- COL1: a,b

VALUES CONCAT_WS(',', 'a');
-- COL1: a

SELECT id, CONCAT_WS('/', s, c, 'z') FROM t ORDER BY id;
-- ID: 1 COL2: red/ab   /z
-- ID: 2 COL2: x y  /z
-- ID: 3 COL2: z

VALUES ROW(CONCAT_WS(',', CAST(NULL AS VARCHAR(1)), CAST(NULL AS VARCHAR(1))), CONCAT_WS(',', CAST(NULL AS VARCHAR(1))) IS NULL);
-- COL1:  COL2: FALSE

-- # A NULL separator is the only NULL that isn't left out: the result is NULL,
-- # as it is in every other database.
VALUES ROW(CONCAT_WS(CAST(NULL AS VARCHAR(1)), 'a', 'b') IS NULL, CONCAT_WS(CAST(NULL AS VARCHAR(1)), 'a'));
-- COL1: TRUE COL2: NULL

-- # The length isn't known if any argument's length isn't, and it's no longer
-- # than the maximum length.
/* types */
VALUES ROW(CONCAT(REPLACE('a', 'a', 'b'), 'c'), CONCAT_WS(REPLACE(',', 'x', 'y'), 'a', 'b'), CONCAT_WS(',', 'a', REPLACE('b', 'x', 'y')));
-- COL1: bc (CHARACTER VARYING) COL2: a,b (CHARACTER VARYING) COL3: a,b (CHARACTER VARYING)

/* types */
VALUES CHAR_LENGTH(CONCAT(CAST('a' AS VARCHAR(10485760)), CAST('b' AS VARCHAR(10485760))));
-- COL1: 2 (INTEGER)

/* types */
VALUES CONCAT(CAST('a' AS VARCHAR(10485760)), CAST('b' AS VARCHAR(10485760)));
-- COL1: ab (CHARACTER VARYING(10485760))

VALUES CHAR_LENGTH(CONCAT(REPEAT('a', 10485760), 'b'));
-- error 22001: string data right truncation for CHARACTER VARYING(10485760)

-- # Only <truncating whitespace> can be cut from the end, like ||.
VALUES CHAR_LENGTH(CONCAT(REPEAT('a', 10485760), ' '));
-- COL1: 10485760

-- # A CHARACTER LARGE OBJECT argument makes the result one.
/* types */
VALUES ROW(CONCAT(CAST('a' AS CLOB), CAST(NULL AS VARCHAR(1)), 'b'), CONCAT_WS('-', 'a', CAST('b' AS CLOB)));
-- COL1: ab (CHARACTER LARGE OBJECT) COL2: a-b (CHARACTER LARGE OBJECT)

-- # Every argument must be a character string, a number has to be CAST first.
VALUES CONCAT('a', CAST(1 AS INTEGER));
-- error 42883: function does not exist: CONCAT(CHARACTER(1), INTEGER)

VALUES CONCAT('a', CAST(CAST(1 AS INTEGER) AS VARCHAR(11)));
-- COL1: a1

VALUES CONCAT_WS(TRUE, 'a');
-- error 42883: function does not exist: CONCAT_WS(BOOLEAN, CHARACTER(1))

VALUES CONCAT();
-- error 42883: CONCAT has 0 arguments but needs at least 1 argument

VALUES CONCAT_WS(',');
-- error 42883: CONCAT_WS has 1 argument but needs at least 2 arguments

SELECT CONCAT(DISTINCT s) FROM t;
-- error 42601: syntax error: CONCAT is not an aggregate function

-- # They can be used anywhere an expression can.
SELECT id FROM t WHERE CONCAT_WS('', s, c) = 'redab   ';
-- ID: 1

-- # Neither name is reserved.
CREATE TABLE concat (concat INT, concat_ws INT);
INSERT INTO concat (concat, concat_ws) VALUES (1, 2);
SELECT concat, concat_ws FROM concat;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- CONCAT: 1 CONCAT_WS: 2

-- # The flagger.
/* flags */
SELECT CONCAT(s, c), CONCAT_WS(',', s, c) FROM t WHERE id = 1;
-- flags: V404-08, V404-09
-- COL1: redab    COL2: red,ab
