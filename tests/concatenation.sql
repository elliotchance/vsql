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

-- # The result can't be longer than the maximum length of a character string,
-- # so a CHARACTER VARYING has the maximum length, and a CHARACTER is an error.
/* extensions V001-01 */
CREATE TABLE t (a VARCHAR(10485760), b CHAR(10485760), c CHAR(5242880));
EXPLAIN SELECT a || a, c || c FROM t;
SELECT b || b FROM t;
SELECT b || 'x' FROM t;
-- msg: CREATE TABLE 1
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (A CHARACTER VARYING(10485760), B CHARACTER(10485760), C CHARACTER(5242880))
-- EXPLAIN: EXPR (COL1 CHARACTER VARYING(10485760), COL2 CHARACTER(10485760))
-- error 42601: syntax error: CHARACTER(20971520) is longer than the maximum length of 10485760
-- error 42601: syntax error: CHARACTER(10485761) is longer than the maximum length of 10485760

-- # 10485760 characters is the longest value, and only spaces are removed from
-- # the end of one that's longer.
SELECT CHAR_LENGTH(a) FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (VALUES CAST('xxxxxxxxxx' AS VARCHAR(10))) AS t0 (a)) AS t1 (a)) AS t2 (a)) AS t3 (a)) AS t4 (a)) AS s (a);
SELECT CHAR_LENGTH(a) FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (VALUES CAST('xxxxxxxxxé' AS VARCHAR(10))) AS t0 (a)) AS t1 (a)) AS t2 (a)) AS t3 (a)) AS t4 (a)) AS s (a);
SELECT CHAR_LENGTH(a || '  ') FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (VALUES CAST('xxxxxxxxxx' AS VARCHAR(10))) AS t0 (a)) AS t1 (a)) AS t2 (a)) AS t3 (a)) AS t4 (a)) AS s (a);
SELECT CHAR_LENGTH(a || 'x') FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (VALUES CAST('xxxxxxxxxx' AS VARCHAR(10))) AS t0 (a)) AS t1 (a)) AS t2 (a)) AS t3 (a)) AS t4 (a)) AS s (a);
SELECT CHAR_LENGTH(a || '  x') FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (VALUES CAST('xxxxxxxxxx' AS VARCHAR(10))) AS t0 (a)) AS t1 (a)) AS t2 (a)) AS t3 (a)) AS t4 (a)) AS s (a);
-- COL1: 10485760
-- COL1: 10485760
-- COL1: 10485760
-- error 22001: string data right truncation for CHARACTER VARYING(10485760)
-- error 22001: string data right truncation for CHARACTER VARYING(10485760)
