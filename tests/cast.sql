/* types */
VALUES ROW(CAST('abc' AS CHARACTER(3)), CHARACTER_LENGTH(CAST('abc' AS CHARACTER(3))));
-- COL1: abc (CHARACTER(3)) COL2: 3 (INTEGER)

VALUES ROW(CAST('abcde' AS CHARACTER(3)), CHARACTER_LENGTH(CAST('abcde' AS CHARACTER(3))));
-- error 22001: string data right truncation for CHARACTER(3)

/* types */
VALUES ROW(CAST('abc ' AS CHARACTER(3)), CHARACTER_LENGTH(CAST('abc ' AS CHARACTER(3))));
-- COL1: abc (CHARACTER(3)) COL2: 3 (INTEGER)

/* types */
VALUES ROW(CAST('abc         ' AS CHARACTER(3)), CHARACTER_LENGTH(CAST('abc         ' AS CHARACTER(3))));
-- COL1: abc (CHARACTER(3)) COL2: 3 (INTEGER)

VALUES ROW(CAST('abc d' AS CHARACTER(3)), CHARACTER_LENGTH(CAST('abc d' AS CHARACTER(3))));
-- error 22001: string data right truncation for CHARACTER(3)

/* types */
VALUES ROW(CAST('abc' AS CHARACTER(4)), CHARACTER_LENGTH(CAST('abc' AS CHARACTER(4))));
-- COL1: abc  (CHARACTER(4)) COL2: 4 (INTEGER)

/* types */
VALUES CAST(123 AS CHARACTER(3));
-- COL1: 123 (CHARACTER(3))

VALUES CAST(1.23 AS CHARACTER(3));
-- error 22001: string data right truncation for CHARACTER(3)

/* types */
VALUES ROW(CAST('abc' AS VARCHAR(3)), CHARACTER_LENGTH(CAST('abc' AS VARCHAR(3))));
-- COL1: abc (CHARACTER VARYING(3)) COL2: 3 (INTEGER)

/* types */
VALUES ROW(CAST('abc ' AS VARCHAR(20)), CHARACTER_LENGTH(CAST('abc ' AS VARCHAR(20))));
-- COL1: abc  (CHARACTER VARYING(4)) COL2: 4 (INTEGER)

/* types */
VALUES CAST(123 AS SMALLINT);
-- COL1: 123 (SMALLINT)

VALUES CAST(123 AS BOOLEAN);
-- error 42846: cannot coerce SMALLINT to BOOLEAN

EXPLAIN VALUES CAST(123 AS SMALLINT);
-- EXPLAIN: VALUES (COL1 SMALLINT) = ROW(CAST(123 AS SMALLINT))

VALUES CAST('hello' AS DOUBLE PRECISION);
-- error 22003: numeric value out of range

VALUES CAST(TRUE AS FLOAT);
-- error 22003: numeric value out of range

VALUES CAST(TRUE AS INT);
-- error 22003: numeric value out of range

VALUES CAST(60000 AS SMALLINT);
-- error 22003: numeric value out of range

VALUES CAST(12345 AS VARCHAR(10));
-- COL1: 12345

VALUES CAST(12345 AS VARCHAR(3));
-- error 22001: string data right truncation for CHARACTER VARYING(3)

VALUES CAST(123456789 AS DOUBLE PRECISION);
-- COL1: 1.23456789e+08

VALUES CAST(1.23 AS NUMERIC);
-- COL1: 1.23
