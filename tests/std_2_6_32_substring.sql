-- # USING CHARACTERS is implicit (Syntax Rules, 6), as EXPLAIN shows. The
-- # result is a CHARACTER VARYING as long as the source (Syntax Rules, 4.a.i).
/* extensions V001-01 */
EXPLAIN VALUES SUBSTRING('hello' FROM 3);
-- EXPLAIN: VALUES (COL1 CHARACTER VARYING(5)) = ROW(SUBSTRING('hello' FROM 3 USING CHARACTERS))

/* extensions V001-01 */
EXPLAIN VALUES SUBSTRING('hello world' FROM 3 FOR 5);
-- EXPLAIN: VALUES (COL1 CHARACTER VARYING(11)) = ROW(SUBSTRING('hello world' FROM 3 FOR 5 USING CHARACTERS))

/* extensions V001-01 */
EXPLAIN VALUES SUBSTRING('hello world' FROM 3 USING CHARACTERS);
-- EXPLAIN: VALUES (COL1 CHARACTER VARYING(11)) = ROW(SUBSTRING('hello world' FROM 3 USING CHARACTERS))

/* extensions V001-01 */
EXPLAIN VALUES SUBSTRING('hello world' FROM 3 FOR 5 USING CHARACTERS);
-- EXPLAIN: VALUES (COL1 CHARACTER VARYING(11)) = ROW(SUBSTRING('hello world' FROM 3 FOR 5 USING CHARACTERS))

/* extensions V001-01 */
EXPLAIN VALUES SUBSTRING('hello world' FROM 3 FOR 2 + 3 USING OCTETS);
-- EXPLAIN: VALUES (COL1 CHARACTER VARYING(11)) = ROW(SUBSTRING('hello world' FROM 3 FOR 2 + 3 USING OCTETS))

-- # Without FOR, the result goes to the end of the string. A start before 1
-- # still starts at the first character, and one after the end gives an empty
-- # string (General Rules, 3.c and 3.f).
/* types */
VALUES SUBSTRING('hello' FROM 0);
-- COL1: hello (CHARACTER VARYING(5))

/* types */
VALUES SUBSTRING('hello' FROM 2);
-- COL1: ello (CHARACTER VARYING(5))

/* types */
VALUES SUBSTRING('hello' FROM 4);
-- COL1: lo (CHARACTER VARYING(5))

/* types */
VALUES SUBSTRING('hello' FROM 5);
-- COL1: o (CHARACTER VARYING(5))

/* types */
VALUES SUBSTRING('hello' FROM 6);
-- COL1:  (CHARACTER VARYING(5))

/* types */
VALUES SUBSTRING('hello' FROM 20);
-- COL1:  (CHARACTER VARYING(5))

/* types */
VALUES SUBSTRING('hello' FROM -1);
-- COL1: hello (CHARACTER VARYING(5))

-- # FOR is the number of characters to take.
/* types */
VALUES SUBSTRING('hello world' FROM 3 FOR 5);
-- COL1: llo w (CHARACTER VARYING(11))

/* types */
VALUES SUBSTRING('hello world' FROM 3 USING CHARACTERS);
-- COL1: llo world (CHARACTER VARYING(11))

/* types */
VALUES SUBSTRING('hello world' FROM 3 FOR 5 USING CHARACTERS);
-- COL1: llo w (CHARACTER VARYING(11))

-- # Positions and lengths count characters, or octets with USING OCTETS
-- # (General Rules, 3.a). The type is still in characters.
/* types */
VALUES SUBSTRING('Жabڣc' FROM 1);
-- COL1: Жabڣc (CHARACTER VARYING(5))

/* types */
VALUES SUBSTRING('Жabڣc' FROM 2);
-- COL1: abڣc (CHARACTER VARYING(5))

/* types */
VALUES SUBSTRING('Жabڣc' FROM 1 FOR 1);
-- COL1: Ж (CHARACTER VARYING(5))

/* types */
VALUES SUBSTRING('Жabڣc' FROM 1 FOR 2);
-- COL1: Жa (CHARACTER VARYING(5))

/* types */
VALUES SUBSTRING('Жabڣc' FROM 3 USING OCTETS);
-- COL1: abڣc (CHARACTER VARYING(5))

/* types */
VALUES SUBSTRING('Жabڣc' FROM 4 USING OCTETS);
-- COL1: bڣc (CHARACTER VARYING(5))

/* types */
VALUES SUBSTRING('Жabڣc' FROM 1 FOR 2 USING OCTETS);
-- COL1: Ж (CHARACTER VARYING(5))

/* types */
VALUES SUBSTRING('Жabڣc' FROM 3 FOR 2 USING OCTETS);
-- COL1: ab (CHARACTER VARYING(5))

-- # With FOR, the end is the start plus the length (General Rules, 3.c), so a
-- # start before 1 uses up some of the length, and the result is empty when the
-- # end is 1 or less, or the start is after the string (General Rules, 3.f.i).
-- # The end can be past the largest BIGINT. A negative length is an error
-- # (General Rules, 3.e).
VALUES SUBSTRING('hello' FROM 0 FOR 3);
-- COL1: he

VALUES SUBSTRING('hello' FROM -1 FOR 3);
-- COL1: h

VALUES SUBSTRING('hello' FROM -5 FOR 3);
-- COL1: 

VALUES SUBSTRING('hello' FROM 2 FOR 0);
-- COL1: 

VALUES SUBSTRING('hello' FROM 2 FOR 10);
-- COL1: ello

VALUES SUBSTRING('hello' FROM 6 FOR 2);
-- COL1: 

VALUES SUBSTRING('hello' FROM 4 FOR 9223372036854775807);
-- COL1: lo

VALUES SUBSTRING('hello' FROM 2 FOR -1);
-- error 22011: substring error

VALUES SUBSTRING('hello' FROM 0 FOR 3 USING OCTETS);
-- COL1: he

VALUES SUBSTRING('hello' FROM 2 FOR 10 USING OCTETS);
-- COL1: ello

VALUES SUBSTRING('hello' FROM 2 FOR -1 USING OCTETS);
-- error 22011: substring error
