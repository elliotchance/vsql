-- # T581 Regular expression substring function: SUBSTRING(... SIMILAR ...
-- # ESCAPE ...) returns the part that matches between the two escaped double
-- # quotes.
/* define t */
CREATE TABLE t (x VARCHAR(20), p VARCHAR(20), e CHAR(1));
INSERT INTO t (x, p, e) VALUES ('foobar', '%#"o_b#"%', '#'), ('foobar', '#"o_b#"%', '#'), (NULL, '%#"o#"%', '#'), ('abc', NULL, '#'), ('abc', '%#"b#"%', NULL);

/* types */
VALUES SUBSTRING('abcdef' SIMILAR 'a#"bcd#"ef' ESCAPE '#');
-- COL1: bcd (CHARACTER VARYING(6))

VALUES SUBSTRING('foobar' SIMILAR '%#"o_b#"%' ESCAPE '#');
VALUES SUBSTRING('foobar' SIMILAR '#"o_b#"%' ESCAPE '#');
VALUES SUBSTRING('aaa' SIMILAR '%#"a+#"%' ESCAPE '#');
-- COL1: oob
-- COL1: NULL
-- COL1: aaa

-- # S1 is the shortest start that matches R1, and S3 the shortest end that
-- # matches R3.
VALUES SUBSTRING('aaabbb' SIMILAR 'a+#"%#"b*' ESCAPE '#');
VALUES SUBSTRING('abc' SIMILAR 'abc#"#"' ESCAPE '#');
-- COL1: aabbb
-- COL1: 

VALUES SUBSTRING('abc' SIMILAR '#"abc#"' ESCAPE '#');
VALUES SUBSTRING('abc' SIMILAR '#"#"' ESCAPE '#');
VALUES SUBSTRING('' SIMILAR '#"#"' ESCAPE '#');
-- COL1: abc
-- COL1: NULL
-- COL1: 

VALUES SUBSTRING('a%b' SIMILAR 'a#"#%#"b' ESCAPE '#');
VALUES SUBSTRING('a##b' SIMILAR 'a#"####b' ESCAPE '#');
VALUES SUBSTRING('a#b' SIMILAR 'a#"###"b' ESCAPE '#');
VALUES SUBSTRING('x2026-11-07y' SIMILAR '%#"[0-9]{4}#-[0-9]{2}#-[0-9]{2}#"%' ESCAPE '#');
VALUES SUBSTRING('Жabڣc' SIMILAR '_#"ab#"%' ESCAPE '#');
VALUES SUBSTRING('ab' SIMILAR '(a|b)#"(a|b)#"' ESCAPE '#');
VALUES SUBSTRING('abc' SIMILAR '%#"[[:ALPHA:]]+#"' ESCAPE '#');
VALUES SUBSTRING('abc' SIMILAR 'ABC#"#"' ESCAPE '#');
-- COL1: %
-- error 2200C: invalid use of escape character
-- COL1: #
-- COL1: 2026-11-07
-- COL1: ab
-- COL1: b
-- COL1: abc
-- COL1: NULL

-- # The parts are separate patterns, so R1 here is "a|b", and the whole
-- # pattern "a|bc" only matches when S1 can't be split from it.
VALUES SUBSTRING('a' SIMILAR 'a|b#"c#"' ESCAPE '#');
VALUES SUBSTRING('bc' SIMILAR 'a|b#"c#"' ESCAPE '#');
VALUES SUBSTRING('abc' SIMILAR '%!"b!"%' ESCAPE '!');
VALUES SUBSTRING('abc' SIMILAR '%""b""%' ESCAPE '"');
-- COL1: NULL
-- COL1: c
-- COL1: b
-- COL1: b

/* types */
VALUES SUBSTRING(CAST('abc' AS CHAR(5)) SIMILAR '%#"b#"%' ESCAPE '#');
-- COL1: b (CHARACTER VARYING(5))

/* types */
VALUES SUBSTRING(CAST(NULL AS VARCHAR(10)) SIMILAR '%#"b#"%' ESCAPE '#');
-- COL1: NULL (CHARACTER VARYING(10))

VALUES SUBSTRING('abc' SIMILAR CAST(NULL AS VARCHAR(10)) ESCAPE '#');
VALUES SUBSTRING('abc' SIMILAR '%#"b#"%' ESCAPE CAST(NULL AS CHAR(1)));
-- COL1: NULL
-- COL1: NULL

/* include t */
SELECT x, SUBSTRING(x SIMILAR p ESCAPE e) FROM t;
-- X: foobar COL2: oob
-- X: foobar COL2: NULL
-- X: NULL COL2: NULL
-- X: abc COL2: NULL
-- X: abc COL2: NULL

/* include t */
SELECT x FROM t WHERE SUBSTRING(x SIMILAR '%#"o+#"%' ESCAPE '#') = 'oo';
-- X: foobar
-- X: foobar

/* extensions V001-01 */
EXPLAIN VALUES SUBSTRING('foobar' SIMILAR '%#"o+#"%' ESCAPE '#');
-- EXPLAIN: VALUES (COL1 CHARACTER VARYING(6)) = ROW(SUBSTRING('foobar' SIMILAR '%#"o+#"%' ESCAPE '#'))

VALUES SUBSTRING('abc' SIMILAR '%#"b#"%' ESCAPE '##');
VALUES SUBSTRING('abc' SIMILAR '%#"b#"%' ESCAPE '');
VALUES SUBSTRING('abc' SIMILAR '%b%' ESCAPE '#');
VALUES SUBSTRING('abc' SIMILAR '%#"b%' ESCAPE '#');
VALUES SUBSTRING('abc' SIMILAR '#"a#"b#"c' ESCAPE '#');
VALUES SUBSTRING('abc' SIMILAR '(a#"b#"c)' ESCAPE '#');
VALUES SUBSTRING('abc' SIMILAR 'a#"(b#"c' ESCAPE '#');
VALUES SUBSTRING('abc' SIMILAR 'a#"b#"c(' ESCAPE '#');
VALUES SUBSTRING('abc' SIMILAR 'a#"%#"%' ESCAPE '%');
VALUES SUBSTRING(123 SIMILAR '%#"2#"%' ESCAPE '#');
-- error 22019: invalid escape character
-- error 22019: invalid escape character
-- error 2200C: invalid use of escape character
-- error 2200C: invalid use of escape character
-- error 2200C: invalid use of escape character
-- error 2201B: invalid regular expression
-- error 2201B: invalid regular expression
-- error 2201B: invalid regular expression
-- error 2200C: invalid use of escape character
-- error 42883: function does not exist: SUBSTRING(INTEGER SIMILAR CHARACTER(7) ESCAPE CHARACTER(1))

VALUES SUBSTRING('123' SIMILAR 2 ESCAPE '#');
VALUES SUBSTRING('123' SIMILAR '%#"2#"%' ESCAPE 1);
VALUES SUBSTRING('abc' SIMILAR '%#"b#"%');
-- error 42883: function does not exist: SUBSTRING(CHARACTER(3) SIMILAR INTEGER ESCAPE CHARACTER(1))
-- error 42883: function does not exist: SUBSTRING(CHARACTER(3) SIMILAR CHARACTER(7) ESCAPE INTEGER)
-- error 42601: syntax error: unexpected ")" at line 1, column 41 near "'abc' SIMILAR '%#"b#"%')", expecting ESCAPE or "||"
