-- # Without a trim specification TRIM is BOTH, and without a trim character
-- # it removes spaces (Syntax Rules, 13.a), as EXPLAIN shows. TRIM(FROM x) is a
-- # vsql extension (V404-01).
/* extensions V001-01 */
EXPLAIN VALUES TRIM('aaababccaa');
-- EXPLAIN: VALUES (COL1 CHARACTER VARYING(10)) = ROW(TRIM(BOTH ' ' FROM 'aaababccaa'))

/* extensions V001-01 V404-01 */
EXPLAIN VALUES TRIM(FROM 'aaababccaa');
-- EXPLAIN: VALUES (COL1 CHARACTER VARYING(10)) = ROW(TRIM(BOTH ' ' FROM 'aaababccaa'))

/* extensions V001-01 */
EXPLAIN VALUES TRIM(LEADING FROM 'aaababccaa');
-- EXPLAIN: VALUES (COL1 CHARACTER VARYING(10)) = ROW(TRIM(LEADING ' ' FROM 'aaababccaa'))

/* extensions V001-01 */
EXPLAIN VALUES TRIM(TRAILING FROM 'aaababccaa');
-- EXPLAIN: VALUES (COL1 CHARACTER VARYING(10)) = ROW(TRIM(TRAILING ' ' FROM 'aaababccaa'))

/* extensions V001-01 */
EXPLAIN VALUES TRIM(BOTH FROM 'aaababccaa');
-- EXPLAIN: VALUES (COL1 CHARACTER VARYING(10)) = ROW(TRIM(BOTH ' ' FROM 'aaababccaa'))

/* extensions V001-01 */
EXPLAIN VALUES TRIM('a' FROM 'aaababccaa');
-- EXPLAIN: VALUES (COL1 CHARACTER VARYING(10)) = ROW(TRIM(BOTH 'a' FROM 'aaababccaa'))

/* extensions V001-01 */
EXPLAIN VALUES TRIM(LEADING 'a' FROM 'aaababccaa');
-- EXPLAIN: VALUES (COL1 CHARACTER VARYING(10)) = ROW(TRIM(LEADING 'a' FROM 'aaababccaa'))

-- # The result is a CHARACTER VARYING as long as the source (Syntax Rules,
-- # 13.b.i). This source has no spaces, so removing spaces doesn't change it.
/* types */
VALUES TRIM('aaababccaa');
-- COL1: aaababccaa (CHARACTER VARYING(10))

-- # Only TRIM(FROM ...) is flagged as an extension. F641 and F661 are for the
-- # VALUES.
/* extensions V404-01 */
/* flags */
VALUES TRIM(FROM 'aaababccaa');
-- flags: F641, F661, V404-01
-- COL1: aaababccaa

/* flags */
VALUES TRIM(LEADING FROM 'aaababccaa');
-- flags: F641, F661
-- COL1: aaababccaa

/* extensions V404-01 */
/* types */
VALUES TRIM(FROM 'aaababccaa');
-- COL1: aaababccaa (CHARACTER VARYING(10))

/* types */
VALUES TRIM(LEADING FROM 'aaababccaa');
-- COL1: aaababccaa (CHARACTER VARYING(10))

/* types */
VALUES TRIM(TRAILING FROM 'aaababccaa');
-- COL1: aaababccaa (CHARACTER VARYING(10))

/* types */
VALUES TRIM(BOTH FROM 'aaababccaa');
-- COL1: aaababccaa (CHARACTER VARYING(10))

-- # With 'a', BOTH removes it from both ends, and LEADING and TRAILING from
-- # only one (General Rules, 11.e).
/* types */
VALUES TRIM('a' FROM 'aaababccaa');
-- COL1: babcc (CHARACTER VARYING(10))

/* types */
VALUES TRIM(LEADING 'a' FROM 'aaababccaa');
-- COL1: babccaa (CHARACTER VARYING(10))

/* types */
VALUES TRIM(TRAILING 'a' FROM 'aaababccaa');
-- COL1: aaababcc (CHARACTER VARYING(10))

-- # The trim character must be one character (General Rules, 11.d).
VALUES TRIM('ab' FROM 'abcab');
-- error 22027: trim error

VALUES TRIM(LEADING '' FROM 'abc');
-- error 22027: trim error

-- # A NULL source gives NULL (General Rules, 11.c), before the length of the
-- # trim character is checked.
CREATE TABLE t (c VARCHAR(10));
INSERT INTO t (c) VALUES (NULL);
SELECT TRIM(TRAILING 'xx' FROM c) FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: NULL

-- # Characters, not octets, are removed, and removing all of them gives an
-- # empty string.
VALUES TRIM('é' FROM 'ééãbcé');
-- COL1: ãbc

VALUES TRIM('a' FROM 'aaaa');
-- COL1: 
