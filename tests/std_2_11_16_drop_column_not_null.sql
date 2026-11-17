-- # DROP NOT NULL drops the NOT NULL constraint of a column.
CREATE TABLE t (a INT, b INT NOT NULL);
INSERT INTO t (a, b) VALUES (1, 2);
ALTER TABLE t ALTER COLUMN b DROP NOT NULL;
INSERT INTO t (a, b) VALUES (3, NULL);
SELECT * FROM t;
SELECT constraint_name FROM information_schema.table_constraints WHERE table_name = 'T';
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: ALTER TABLE 1
-- msg: INSERT 1
-- A: 1 B: 2
-- A: 3 B: NULL

-- # A named NOT NULL is dropped too, and a column that isn't NOT NULL doesn't
-- # change.
CREATE TABLE t (a INT CONSTRAINT a_nn NOT NULL, b INT);
ALTER TABLE t ALTER a DROP NOT NULL;
ALTER TABLE t ALTER b DROP NOT NULL;
ALTER TABLE t DROP CONSTRAINT a_nn RESTRICT;
INSERT INTO t (a, b) VALUES (NULL, NULL);
-- msg: CREATE TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- error 42704: no such constraint: A_NN on ":memory:".PUBLIC.T
-- msg: INSERT 1

-- # A column of the PRIMARY KEY is always NOT NULL, and so is an identity
-- # column.
CREATE TABLE t (a INT PRIMARY KEY, b INT GENERATED ALWAYS AS IDENTITY);
ALTER TABLE t ALTER COLUMN a DROP NOT NULL;
ALTER TABLE t ALTER COLUMN b DROP NOT NULL;
-- msg: CREATE TABLE 1
-- error 42601: syntax error: column A is in the PRIMARY KEY, so its NOT NULL cannot be dropped
-- error 42601: syntax error: cannot change the NOT NULL of identity column B

-- # The flagger.
/* flags */
CREATE TABLE t (a INT NOT NULL);
ALTER TABLE t ALTER COLUMN a DROP NOT NULL;
-- flags:
-- msg: CREATE TABLE 1
-- flags: F383, F387
-- msg: ALTER TABLE 1
