EXPLAIN VALUES TRIM('aaababccaa');
-- EXPLAIN: VALUES (COL1 CHARACTER VARYING) = ROW(TRIM(BOTH ' ' FROM 'aaababccaa'))

EXPLAIN VALUES TRIM(FROM 'aaababccaa');
-- EXPLAIN: VALUES (COL1 CHARACTER VARYING) = ROW(TRIM(BOTH ' ' FROM 'aaababccaa'))

EXPLAIN VALUES TRIM(LEADING FROM 'aaababccaa');
-- EXPLAIN: VALUES (COL1 CHARACTER VARYING) = ROW(TRIM(LEADING ' ' FROM 'aaababccaa'))

EXPLAIN VALUES TRIM(TRAILING FROM 'aaababccaa');
-- EXPLAIN: VALUES (COL1 CHARACTER VARYING) = ROW(TRIM(TRAILING ' ' FROM 'aaababccaa'))

EXPLAIN VALUES TRIM(BOTH FROM 'aaababccaa');
-- EXPLAIN: VALUES (COL1 CHARACTER VARYING) = ROW(TRIM(BOTH ' ' FROM 'aaababccaa'))

EXPLAIN VALUES TRIM('a' FROM 'aaababccaa');
-- EXPLAIN: VALUES (COL1 CHARACTER VARYING) = ROW(TRIM(BOTH 'a' FROM 'aaababccaa'))

EXPLAIN VALUES TRIM(LEADING 'a' FROM 'aaababccaa');
-- EXPLAIN: VALUES (COL1 CHARACTER VARYING) = ROW(TRIM(LEADING 'a' FROM 'aaababccaa'))

/* types */
VALUES TRIM('aaababccaa');
-- COL1: aaababccaa (CHARACTER VARYING(10))

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

/* types */
VALUES TRIM('a' FROM 'aaababccaa');
-- COL1: babcc (CHARACTER VARYING(5))

/* types */
VALUES TRIM(LEADING 'a' FROM 'aaababccaa');
-- COL1: babccaa (CHARACTER VARYING(7))

/* types */
VALUES TRIM(TRAILING 'a' FROM 'aaababccaa');
-- COL1: aaababcc (CHARACTER VARYING(8))
