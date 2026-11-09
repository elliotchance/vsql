-- # COALESCE needs at least two values.
VALUES COALESCE(1);
-- error 42601: syntax error: unexpected ")" at line 1, column 18 near "COALESCE(1)", expecting ","

-- # COALESCE of three or more values is a nested COALESCE (Syntax Rules, 1.e),
-- # but EXPLAIN shows it as it was written.
/* extensions V001-01 */
EXPLAIN VALUES COALESCE(1, 2);
-- EXPLAIN: VALUES (COL1 SMALLINT) = ROW(COALESCE(1, 2))

/* extensions V001-01 */
EXPLAIN VALUES COALESCE(1, 2, 3);
-- EXPLAIN: VALUES (COL1 SMALLINT) = ROW(COALESCE(1, 2, 3))

VALUES COALESCE(1);
-- error 42601: syntax error: unexpected ")" at line 1, column 18 near "COALESCE(1)", expecting ","

-- # The type combines the types of all the values (Syntax Rules, 5), and the
-- # first value that isn't NULL is cast to it, so 1 becomes INTEGER or 1e0.
/* types */
VALUES COALESCE(1, 2);
-- COL1: 1 (SMALLINT)

/* types */
VALUES COALESCE(1, 200000000);
-- COL1: 1 (INTEGER)

/* extensions V001-01 */
EXPLAIN VALUES COALESCE(NULLIF(1, 1), 1.5, 200000000);
-- EXPLAIN: VALUES (COL1 NUMERIC(11, 1)) = ROW(COALESCE(NULLIF(1, 1), 1.5, 200000000))

/* types */
VALUES COALESCE(1, 2.5e0);
-- COL1: 1e0 (DOUBLE PRECISION)

/* extensions V001-01 */
EXPLAIN VALUES COALESCE('a', CAST('bcd' AS VARCHAR(10)));
-- EXPLAIN: VALUES (COL1 CHARACTER VARYING(10)) = ROW(COALESCE('a', CAST('bcd' AS CHARACTER VARYING(10))))

/* types */
VALUES COALESCE(CAST(NULL AS INTEGER), 1);
-- COL1: 1 (INTEGER)

-- # TIMESTAMP(0) and TIMESTAMP(3) WITH TIME ZONE combine to the larger
-- # precision with a time zone, but a DATE and a TIMESTAMP have different
-- # fields so they can't be combined (9.5, Syntax Rules, 3.d).
/* extensions V001-01 */
CREATE TABLE t (a TIMESTAMP(0), b TIMESTAMP(3) WITH TIME ZONE);
EXPLAIN SELECT COALESCE(a, b) FROM t;
-- msg: CREATE TABLE 1
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (A TIMESTAMP(0) WITHOUT TIME ZONE, B TIMESTAMP(3) WITH TIME ZONE)
-- EXPLAIN: EXPR (COL1 TIMESTAMP(3) WITH TIME ZONE)

VALUES COALESCE(DATE '2022-06-30', TIMESTAMP '2022-06-30 21:47:32');
-- error 42804: data type mismatch in argument 2 of COALESCE: expected DATE but got TIMESTAMP(0) WITHOUT TIME ZONE

-- # On rows, a NULL is replaced by the next value, and COALESCE(f1, f1) is NULL
-- # when F1 is NULL.
CREATE TABLE foo (f1 BIGINT);
INSERT INTO foo (f1) VALUES (NULL);
INSERT INTO foo (f1) VALUES (3);
SELECT COALESCE(f1, CAST(2 AS BIGINT)) FROM foo;
SELECT COALESCE(f1, f1) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- COL1: 2
-- COL1: 3
-- COL1: NULL
-- COL1: 3

-- # A number and a string can't be combined (9.5, Syntax Rules, 3.c.i).
VALUES COALESCE(1, 'hello');
-- error 42804: data type mismatch in argument 2 of COALESCE: expected SMALLINT but got CHARACTER(5)
