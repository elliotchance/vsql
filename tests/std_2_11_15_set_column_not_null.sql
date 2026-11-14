-- # SET NOT NULL adds a NOT NULL constraint to a column, which every existing
-- # row must satisfy. It gets a name like the NOT NULL of a CREATE TABLE.
CREATE TABLE t (a INT, b INT);
INSERT INTO t (a, b) VALUES (1, 2);
ALTER TABLE t ALTER COLUMN b SET NOT NULL;
INSERT INTO t (a, b) VALUES (3, NULL);
SELECT constraint_name FROM information_schema.table_constraints WHERE table_name = 'T';
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: ALTER TABLE 1
-- error 23502: violates non-null constraint: column B
-- CONSTRAINT_NAME: T_NOT_NULL_2

-- # It's an error if a row is NULL, and nothing changes.
CREATE TABLE t (a INT, b INT);
INSERT INTO t (a, b) VALUES (1, NULL);
ALTER TABLE t ALTER b SET NOT NULL;
INSERT INTO t (a, b) VALUES (2, NULL);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 23502: violates non-null constraint: column B
-- msg: INSERT 1
-- A: 1 B: NULL
-- A: 2 B: NULL

-- # A column that's already NOT NULL doesn't change, and keeps the name of its
-- # constraint. A new name isn't the name of another constraint.
CREATE TABLE t (a INT CONSTRAINT a_nn NOT NULL, b INT, CONSTRAINT t_not_null_2 CHECK (b > 0));
ALTER TABLE t ALTER COLUMN a SET NOT NULL;
ALTER TABLE t ALTER COLUMN b SET NOT NULL;
SELECT constraint_name FROM information_schema.table_constraints WHERE table_name = 'T' ORDER BY constraint_name;
-- msg: CREATE TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- CONSTRAINT_NAME: A_NN
-- CONSTRAINT_NAME: T_NOT_NULL_2
-- CONSTRAINT_NAME: T_NOT_NULL_3

-- # The NOT NULL can be dropped like any other constraint.
CREATE TABLE t (a INT);
ALTER TABLE t ALTER COLUMN a SET NOT NULL;
ALTER TABLE t DROP CONSTRAINT t_not_null_1 RESTRICT;
INSERT INTO t (a) VALUES (NULL);
-- msg: CREATE TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: INSERT 1

-- # An identity column is always NOT NULL, so it can't be changed.
CREATE TABLE t (a INT GENERATED ALWAYS AS IDENTITY);
ALTER TABLE t ALTER COLUMN a SET NOT NULL;
-- msg: CREATE TABLE 1
-- error 42601: syntax error: cannot change the NOT NULL of identity column A

-- # It's rolled back with the transaction.
CREATE TABLE t (a INT);
START TRANSACTION;
ALTER TABLE t ALTER COLUMN a SET NOT NULL;
ROLLBACK;
INSERT INTO t (a) VALUES (NULL);
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: ALTER TABLE 1
-- msg: ROLLBACK
-- msg: INSERT 1

-- # The flagger.
/* flags */
CREATE TABLE t (a INT);
ALTER TABLE t ALTER COLUMN a SET NOT NULL;
-- flags:
-- msg: CREATE TABLE 1
-- flags: F383, F387
-- msg: ALTER TABLE 1
