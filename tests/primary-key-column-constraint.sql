-- # A PRIMARY KEY on a column is the same as PRIMARY KEY (column), see #358.
CREATE TABLE t (id INT PRIMARY KEY, x INT);
INSERT INTO t (id, x) VALUES (1, 10);
INSERT INTO t (id, x) VALUES (1, 20);
INSERT INTO t (x) VALUES (30);
EXPLAIN SELECT * FROM t WHERE id = 1;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T
-- error 23502: violates non-null constraint: column ":memory:".PUBLIC.T.ID
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.T (ID INTEGER NOT NULL, X INTEGER) BETWEEN 1 AND 1
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.ID INTEGER NOT NULL, ":memory:".PUBLIC.T.X INTEGER)
-- ID: 1 X: 10

CREATE TABLE t (id INT NOT NULL PRIMARY KEY);
CREATE TABLE t2 (id INT PRIMARY KEY NOT NULL);
INSERT INTO t (id) VALUES (1);
INSERT INTO t2 (id) VALUES (1);
INSERT INTO t2 (id) VALUES (1);
SELECT * FROM t;
SELECT * FROM t2;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T2
-- ID: 1
-- ID: 1

CREATE TABLE t (x INT, id BIGINT PRIMARY KEY);
INSERT INTO t (x, id) VALUES (1, 2);
INSERT INTO t (x, id) VALUES (2, 1);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- X: 2 ID: 1
-- X: 1 ID: 2

CREATE TABLE t (id INT PRIMARY KEY, x INT);
INSERT INTO t (id, x) VALUES (1, 10);
UPDATE t SET id = 2;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: UPDATE 1
-- ID: 2 X: 10

-- # The definition is stored as a table constraint.
CREATE TABLE t (id INT PRIMARY KEY);
/* out */
-- msg: CREATE TABLE 1
-- out: CREATE TABLE "PUBLIC"."T" (
-- out:   "ID" INTEGER NOT NULL,
-- out:   PRIMARY KEY ("ID")
-- out: );

-- # A table still has only one PRIMARY KEY.
CREATE TABLE t (id INT PRIMARY KEY, x INT PRIMARY KEY);
-- error 42601: syntax error: only one PRIMARY KEY can be defined

CREATE TABLE t (id INT PRIMARY KEY, PRIMARY KEY (id));
-- error 42601: syntax error: only one PRIMARY KEY can be defined

CREATE TABLE t (id INT PRIMARY KEY PRIMARY KEY);
-- error 42601: syntax error: only one PRIMARY KEY can be defined
