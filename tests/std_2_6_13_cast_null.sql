-- # CAST(NULL AS T) is the null value with the declared type T (General Rules,
-- # 2.a). A null BOOLEAN is UNKNOWN.
/* types */
VALUES CAST(NULL AS INT);
-- COL1: NULL (INTEGER)

/* types */
VALUES CAST(NULL AS VARCHAR(10));
-- COL1: NULL (CHARACTER VARYING(10))

/* types */
VALUES CAST(NULL AS DECIMAL(5, 2));
-- COL1: NULL (DECIMAL(5, 2))

/* types */
VALUES CAST(NULL AS DATE);
-- COL1: NULL (DATE)

/* types */
VALUES CAST(NULL AS BOOLEAN);
-- COL1: UNKNOWN (BOOLEAN)

-- # A typed NULL is like any other null value in expressions, predicates and
-- # functions.
/* types */
VALUES CAST(NULL AS INT) + 1;
-- COL1: NULL (INTEGER)

VALUES CAST(NULL AS INT) IS NULL;
-- COL1: TRUE

VALUES CAST(NULL AS VARCHAR(10)) LIKE 'a';
-- COL1: UNKNOWN

VALUES 1 BETWEEN CAST(NULL AS INT) AND 2;
-- COL1: UNKNOWN

/* types */
VALUES COALESCE(CAST(NULL AS INT), CAST(NULL AS INT));
-- COL1: NULL (INTEGER)

VALUES COALESCE(CAST(NULL AS INT), CAST(3 AS INT));
-- COL1: 3

VALUES UPPER(CAST(NULL AS VARCHAR(10)));
-- COL1: NULL

-- # A typed NULL can be inserted, compared (which matches no rows) and set by
-- # an UPDATE.
CREATE TABLE t1 (x INT, y VARCHAR(10));
INSERT INTO t1 (x, y) VALUES (CAST(NULL AS INT), CAST(NULL AS VARCHAR(5)));
INSERT INTO t1 (x, y) VALUES (1, 'a');
SELECT * FROM t1 WHERE x = CAST(NULL AS INT);
UPDATE t1 SET y = CAST(NULL AS VARCHAR(10)) WHERE x = 1;
SELECT * FROM t1;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: UPDATE 1
-- X: NULL Y: NULL
-- X: 1 Y: NULL
