-- # A CHARACTER LARGE OBJECT or BINARY LARGE OBJECT can't be an operand of an
-- # ordering operation (Part 2, 9.14, Syntax Rules, 3): ORDER BY, a comparison
-- # other than = and <>, a quantified comparison, BETWEEN, MAX, MIN, the ORDER
-- # BY of LISTAGG, GREATEST or LEAST.
/* setup */
CREATE TABLE t (a INT, c CLOB, b BLOB, v VARCHAR(10));
INSERT INTO t VALUES (1, 'x', X'01', 'x');

SELECT a FROM t ORDER BY c;
-- error 42601: syntax error: C in ORDER BY cannot be a CHARACTER LARGE OBJECT

SELECT a FROM t ORDER BY a, b DESC;
-- error 42601: syntax error: B in ORDER BY cannot be a BINARY LARGE OBJECT

SELECT a FROM t WHERE c < 'y';
-- error 42601: syntax error: operand of < cannot be a CHARACTER LARGE OBJECT

SELECT a FROM t WHERE X'00' >= b;
-- error 42601: syntax error: operand of >= cannot be a BINARY LARGE OBJECT

SELECT a FROM t WHERE (a, c) > (0, 'x');
-- error 42601: syntax error: operand of > cannot be a CHARACTER LARGE OBJECT

SELECT a FROM t WHERE c <= ALL (SELECT v FROM t);
-- error 42601: syntax error: operand of <= cannot be a CHARACTER LARGE OBJECT

SELECT a FROM t WHERE v > SOME (SELECT c FROM t);
-- error 42601: syntax error: operand of > cannot be a CHARACTER LARGE OBJECT

SELECT a FROM t WHERE c BETWEEN 'a' AND 'z';
-- error 42601: syntax error: operand of BETWEEN cannot be a CHARACTER LARGE OBJECT

SELECT MAX(c) FROM t;
-- error 42601: syntax error: argument of MAX cannot be a CHARACTER LARGE OBJECT

SELECT MIN(b) FROM t;
-- error 42601: syntax error: argument of MIN cannot be a BINARY LARGE OBJECT

SELECT LISTAGG(v, ',') WITHIN GROUP (ORDER BY c) FROM t;
-- error 42601: syntax error: C in WITHIN GROUP cannot be a CHARACTER LARGE OBJECT

SELECT GREATEST(v, c) FROM t;
-- error 42601: syntax error: argument 2 of GREATEST cannot be a CHARACTER LARGE OBJECT

-- # An ordering operation is still checked when there are no rows.
SELECT a FROM t WHERE a > 1 ORDER BY c;
-- error 42601: syntax error: C in ORDER BY cannot be a CHARACTER LARGE OBJECT

-- # = and <> are equality operations, not ordering operations, and a large
-- # object can be in the select list of an ordered query.
SELECT a, c, b FROM t WHERE c = 'x' AND c <> 'y' ORDER BY a;
-- A: 1 C: x B: 01
