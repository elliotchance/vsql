-- # UPPER and LOWER have the type of their argument, including its length
-- # (Syntax Rules, 9).
/* types */
VALUES UPPER('Hello');
-- COL1: HELLO (CHARACTER(5))

/* types */
VALUES LOWER('Hello');
-- COL1: hello (CHARACTER(5))

/* extensions V001-01 */
CREATE TABLE t (a VARCHAR(10));
INSERT INTO t (a) VALUES ('Hello');
EXPLAIN SELECT UPPER(a), LOWER(a) FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (A CHARACTER VARYING(10))
-- EXPLAIN: EXPR (COL1 CHARACTER VARYING(10), COL2 CHARACTER VARYING(10))

-- # The argument must be one character string.
VALUES UPPER(123);
-- error 42883: function does not exist: UPPER(SMALLINT)

VALUES LOWER(TRUE);
-- error 42883: function does not exist: LOWER(BOOLEAN)

VALUES UPPER();
-- error 42601: syntax error: unexpected ")" at line 1, column 14 near "VALUES UPPER()"

VALUES LOWER('abc', 123);
-- error 42601: syntax error: unexpected "," at line 1, column 19 near "LOWER('abc', 123", expecting ")" or "||"
