/* types */
VALUES 'foo' || 'bar';
-- COL1: foobar (CHARACTER(6))

VALUES 123 || 'bar';
-- error 42883: operator does not exist: SMALLINT || CHARACTER

/* extensions V001-01 */
CREATE TABLE t (a VARCHAR(10), b CHAR(4));
INSERT INTO t (a, b) VALUES ('hello', 'abcd');
EXPLAIN SELECT a || b, b || b, a || 'xy' FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (A CHARACTER VARYING(10), B CHARACTER(4))
-- EXPLAIN: EXPR (COL1 CHARACTER VARYING(14), COL2 CHARACTER(8), COL3 CHARACTER VARYING(12))

/* types */
VALUES 'foo' || CAST(NULL AS VARCHAR(5));
-- COL1: NULL (CHARACTER VARYING(8))
