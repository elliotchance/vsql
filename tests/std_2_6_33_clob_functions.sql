-- # SUBSTRING, TRIM and SUBSTRING SIMILAR of a CHARACTER LARGE OBJECT are a
-- # CHARACTER LARGE OBJECT with the same maximum length (6.33, Syntax Rules,
-- # 4.a.ii, 7.b.ii and 14.b.ii). UPPER and LOWER have the type of their operand
-- # (6.33, Syntax Rules, 9).
/* types */
CREATE TABLE t (a CLOB(10), b CLOB);
INSERT INTO t VALUES ('  Hello ', 'abc');
SELECT SUBSTRING(a FROM 3 FOR 2), SUBSTRING(b FROM 2 USING OCTETS), TRIM(a), TRIM(LEADING 'a' FROM b), UPPER(a), LOWER(a), SUBSTRING(b SIMILAR 'a#"b#"c' ESCAPE '#') FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: He (CHARACTER LARGE OBJECT(10)) COL2: bc (CHARACTER LARGE OBJECT) COL3: Hello (CHARACTER LARGE OBJECT(10)) COL4: bc (CHARACTER LARGE OBJECT) COL5:   HELLO  (CHARACTER LARGE OBJECT(10)) COL6:   hello  (CHARACTER LARGE OBJECT(10)) COL7: b (CHARACTER LARGE OBJECT)

-- # OVERLAY of a CHARACTER LARGE OBJECT is the concatenation of SUBSTRINGs of
-- # it (6.33, Syntax Rules, 17.c), so it's also a CHARACTER LARGE OBJECT.
/* types */
VALUES OVERLAY(CAST('abcdef' AS CLOB(6)) PLACING 'xy' FROM 2);
-- COL1: axydef (CHARACTER LARGE OBJECT(14))

-- # A <fold>, <trim source> or <character substring function> of a CHARACTER
-- # LARGE OBJECT is Feature T050.
/* flags */
VALUES UPPER(CAST('ab' AS CLOB));
-- flags: F641, F661, T046, T050
-- COL1: AB

/* flags */
VALUES LOWER(CAST('AB' AS CLOB));
-- flags: F641, F661, T046, T050
-- COL1: ab

/* flags */
VALUES TRIM(CAST(' ab ' AS CLOB));
-- flags: F641, F661, T046, T050
-- COL1: ab

/* flags */
VALUES SUBSTRING(CAST('ab' AS CLOB) FROM 2);
-- flags: F641, F661, T046, T050
-- COL1: b
