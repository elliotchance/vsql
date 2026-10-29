/* setup */
CREATE TABLE t1 (id INT, parent_id INT, name VARCHAR(10));
INSERT INTO t1 (id, parent_id, name) VALUES (1, NULL, 'root');
INSERT INTO t1 (id, parent_id, name) VALUES (2, 1, 'left');
INSERT INTO t1 (id, parent_id, name) VALUES (3, 1, 'right');

SELECT x.name FROM t1 AS x;
-- NAME: root
-- NAME: left
-- NAME: right

-- # AS is optional.
SELECT x.name FROM t1 x WHERE x.id = 2;
-- NAME: left

SELECT name FROM t1 AS x WHERE id > 1 ORDER BY x.name;
-- NAME: left
-- NAME: right

SELECT x.* FROM t1 AS x WHERE x.id = 1;
-- ID: 1 PARENT_ID: NULL NAME: root

/* extensions V001-01 */
EXPLAIN SELECT x.name FROM t1 AS x;
-- EXPLAIN: X:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.T1 (ID INTEGER, PARENT_ID INTEGER, NAME CHARACTER VARYING(10))
-- EXPLAIN: TABLE X (ID INTEGER, PARENT_ID INTEGER, NAME CHARACTER VARYING(10))
-- EXPLAIN: EXPR (NAME CHARACTER VARYING(10))

-- # A derived column list renames the columns.
SELECT * FROM t1 AS x (a, b, c);
-- A: 1 B: NULL C: root
-- A: 2 B: 1 C: left
-- A: 3 B: 1 C: right

SELECT x.c FROM t1 AS x (a, b, c) WHERE b = 1;
-- C: left
-- C: right

SELECT x.id FROM t1 AS x (a, b, c);
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.X.ID

SELECT * FROM t1 AS x (a, b);
-- error 42601: syntax error: ROW provides the wrong number of columns for the correlation

SELECT * FROM t1 AS x (a, b, a);
-- error 42601: syntax error: column A is specified more than once

SELECT * FROM (SELECT id, name FROM t1) AS x (a, a);
-- error 42601: syntax error: column A is specified more than once

-- # The correlation name replaces the table name.
SELECT t1.name FROM t1 AS x;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.T1.NAME

-- # Correlation names allow a table to be joined to itself.
SELECT c.name, p.name FROM t1 AS c JOIN t1 AS p ON c.parent_id = p.id;
-- NAME: left NAME: root
-- NAME: right NAME: root

SELECT c.name, p.name FROM t1 AS c LEFT JOIN t1 AS p ON c.parent_id = p.id;
-- NAME: root NAME: NULL
-- NAME: left NAME: root
-- NAME: right NAME: root

SELECT t1.name, p.name FROM t1 JOIN t1 AS p ON t1.parent_id = p.id;
-- NAME: left NAME: root
-- NAME: right NAME: root

SELECT * FROM t1 AS x JOIN t1 AS x ON TRUE;
-- error 42601: syntax error: table name X specified more than once

SELECT p.name, COUNT(*) FROM t1 AS c JOIN t1 AS p ON c.parent_id = p.id GROUP BY p.name;
-- NAME: root COL2: 2

-- # The WHERE is checked even when there are no rows.
CREATE TABLE t2 (x INT);
SELECT * FROM t2 AS y WHERE y.z = 1;
-- msg: CREATE TABLE 1
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.Y.Z
