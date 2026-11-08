-- # NULLIF(V1, V2) is CASE WHEN V1 = V2 THEN NULL ELSE V1 END (Syntax Rules,
-- # 1.c), so it's NULL when they're equal, and its type is the type of V1.
/* extensions V001-01 */
EXPLAIN VALUES NULLIF(TRUE, TRUE);
-- EXPLAIN: VALUES (COL1 BOOLEAN) = ROW(NULLIF(TRUE, TRUE))

/* types */
VALUES NULLIF(123, 123);
-- COL1: NULL (SMALLINT)

/* types */
VALUES NULLIF(123, 456);
-- COL1: 123 (SMALLINT)

-- # V1 and V2 must be comparable (8.2, Syntax Rules, 3).
VALUES NULLIF(123, 'hello');
-- error 42804: data type mismatch in NULLIF: expected SMALLINT but got CHARACTER(5)

-- # When V1 is NULL, V1 = V2 is UNKNOWN, so the result is V1, which is NULL.
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (NULL), (1), (2);
SELECT NULLIF(x, 1) FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- COL1: NULL
-- COL1: NULL
-- COL1: 2

-- # Numbers of different types, or strings of different types, can be compared,
-- # and the result keeps the type of V1. 2 is equal to 2e0, so that's NULL.
/* types */
VALUES ROW(NULLIF(2, 2e0), NULLIF(CAST(3 AS BIGINT), 1.5), NULLIF('a', CAST('b' AS VARCHAR(5))));
-- COL1: NULL (SMALLINT) COL2: 3 (BIGINT) COL3: a (CHARACTER(1))

-- # A BOOLEAN can't be compared with a number (8.2, Syntax Rules, 3).
VALUES NULLIF(TRUE, 1);
-- error 42804: data type mismatch in NULLIF: expected BOOLEAN but got SMALLINT
