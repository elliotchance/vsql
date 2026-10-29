/* extensions V001-01 */
EXPLAIN VALUES TRIM('aaababccaa');
-- EXPLAIN: VALUES (COL1 CHARACTER VARYING(10)) = ROW(TRIM(BOTH ' ' FROM 'aaababccaa'))

/* extensions V001-01 */
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
-- COL1: babcc (CHARACTER VARYING(10))

/* types */
VALUES TRIM(LEADING 'a' FROM 'aaababccaa');
-- COL1: babccaa (CHARACTER VARYING(10))

/* types */
VALUES TRIM(TRAILING 'a' FROM 'aaababccaa');
-- COL1: aaababcc (CHARACTER VARYING(10))

VALUES TRIM('ab' FROM 'abcab');
-- error 22027: trim error

VALUES TRIM(LEADING '' FROM 'abc');
-- error 22027: trim error

CREATE TABLE t (c VARCHAR(10));
INSERT INTO t (c) VALUES (NULL);
SELECT TRIM(TRAILING 'xx' FROM c) FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: NULL

VALUES TRIM('é' FROM 'ééãbcé');
-- COL1: ãbc

VALUES TRIM('a' FROM 'aaaa');
-- COL1: 
