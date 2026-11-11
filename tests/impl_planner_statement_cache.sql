-- # A statement that runs again with the same text is planned again, so it uses
-- # the current schema.
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
SELECT * FROM t;
ALTER TABLE t ADD COLUMN y INT;
SELECT * FROM t;
DROP TABLE t RESTRICT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- X: 1
-- msg: ALTER TABLE 1
-- X: 1 Y: NULL
-- msg: DROP TABLE 1
-- error 42P01: no such table: ":memory:".PUBLIC.T

-- # An index that's created after a statement first runs is used the next time.
/* extensions V001-01 V002-01 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1), (2);
EXPLAIN SELECT x FROM t WHERE x = 2;
CREATE INDEX t_x ON t (x);
EXPLAIN SELECT x FROM t WHERE x = 2;
SELECT x FROM t WHERE x = 2;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (X INTEGER)
-- EXPLAIN: WHERE X = 2
-- EXPLAIN: EXPR (X INTEGER)
-- msg: CREATE INDEX 1
-- EXPLAIN: INDEX ":memory:".PUBLIC.T_X ON ":memory:".PUBLIC.T (X INTEGER) RANGE X = 2
-- EXPLAIN: EXPR (X INTEGER)
-- X: 2

-- # The same applies when the schema is changed by another connection.
/* connection 1 */
CREATE TABLE t (x INT);
SELECT * FROM t;
/* connection 2 */
ALTER TABLE t ADD COLUMN y INT;
INSERT INTO t (x, y) VALUES (1, 2);
/* connection 1 */
SELECT * FROM t;
/* connection 2 */
DROP TABLE t RESTRICT;
/* connection 1 */
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 2: msg: ALTER TABLE 1
-- 2: msg: INSERT 1
-- 1: X: 1 Y: 2
-- 2: msg: DROP TABLE 1
-- 1: error 42P01: no such table: "test".PUBLIC.T

-- # A statement with a syntax error fails each time.
SELECT FROM;
SELECT FROM;
-- error 42601: syntax error: unexpected FROM at line 1, column 8 near "SELECT FROM"; hint: FROM is a reserved word, so it must be quoted to be used as a name, such as "FROM" (see https://vsql.readthedocs.io/en/latest/keywords.html)
-- error 42601: syntax error: unexpected FROM at line 1, column 8 near "SELECT FROM"; hint: FROM is a reserved word, so it must be quoted to be used as a name, such as "FROM" (see https://vsql.readthedocs.io/en/latest/keywords.html)
