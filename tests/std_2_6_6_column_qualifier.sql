-- # A column reference with a table qualifier must use a table in the FROM
-- # clause.
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
SELECT nope.x FROM t;
SELECT x FROM t WHERE nope.x > 0;
SELECT t.x FROM t WHERE t.x > 0;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.NOPE.X
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.NOPE.X
-- X: 1

CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
SELECT s.x FROM (SELECT x FROM t) AS s;
SELECT nope.x FROM (SELECT x FROM t) AS s;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- X: 1
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.NOPE.X
