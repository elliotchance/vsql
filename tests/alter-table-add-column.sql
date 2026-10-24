-- # The new column is after the other columns, and is NULL for existing rows.
CREATE TABLE t (a INT);
INSERT INTO t (a) VALUES (1), (2);
ALTER TABLE t ADD COLUMN b VARCHAR(10);
INSERT INTO t (a, b) VALUES (3, 'x');
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: ALTER TABLE 1
-- msg: INSERT 1
-- A: 1 B: NULL
-- A: 2 B: NULL
-- A: 3 B: x

-- # COLUMN is optional.
CREATE TABLE t (a INT);
ALTER TABLE t ADD b BOOLEAN;
INSERT INTO t (a) VALUES (1);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: ALTER TABLE 1
-- msg: INSERT 1
-- A: 1 B: UNKNOWN

-- # Existing rows get the default.
CREATE TABLE t (a INT);
INSERT INTO t (a) VALUES (1), (2);
ALTER TABLE t ADD COLUMN b INT DEFAULT 5 NOT NULL;
ALTER TABLE t ADD COLUMN c VARCHAR(20) DEFAULT CURRENT_SCHEMA;
INSERT INTO t (a) VALUES (3);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: INSERT 1
-- A: 1 B: 5 C: PUBLIC
-- A: 2 B: 5 C: PUBLIC
-- A: 3 B: 5 C: PUBLIC

-- # Rows that existed before the column was added can be changed.
CREATE TABLE t (a INT);
INSERT INTO t (a) VALUES (1), (2);
ALTER TABLE t ADD COLUMN b INT;
UPDATE t SET b = a * 10 WHERE a = 2;
DELETE FROM t WHERE a = 1;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: ALTER TABLE 1
-- msg: UPDATE 1
-- msg: DELETE 1
-- A: 2 B: 20

-- # A NOT NULL column without a default can only be added to an empty table.
CREATE TABLE t (a INT);
ALTER TABLE t ADD COLUMN b INT NOT NULL;
INSERT INTO t (a) VALUES (1);
INSERT INTO t (a, b) VALUES (1, 2);
ALTER TABLE t ADD COLUMN c INT NOT NULL;
ALTER TABLE t ADD COLUMN c INT DEFAULT NULL NOT NULL;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: ALTER TABLE 1
-- error 23502: violates non-null constraint: column B
-- msg: INSERT 1
-- error 23502: violates non-null constraint: column C
-- error 23502: violates non-null constraint: column C
-- A: 1 B: 2

-- # The column name must be unique.
CREATE TABLE t (a INT);
ALTER TABLE t ADD COLUMN a INT;
ALTER TABLE t ADD COLUMN "A" INT;
ALTER TABLE t ADD COLUMN "a" INT;
INSERT INTO t (a) VALUES (1);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- error 42601: syntax error: column A is defined more than once
-- error 42601: syntax error: column A is defined more than once
-- msg: ALTER TABLE 1
-- msg: INSERT 1
-- A: 1 a: NULL

-- # The table must exist.
ALTER TABLE foo ADD COLUMN a INT;
ALTER TABLE foo.bar ADD COLUMN a INT;
ALTER TABLE information_schema.tables ADD COLUMN a INT;
-- error 42P01: no such table: ":memory:".PUBLIC.FOO
-- error 3F000: invalid schema name: FOO
-- error 42501: insufficient privilege: INFORMATION_SCHEMA is read-only

-- # The column is checked like a column of a CREATE TABLE.
CREATE TABLE t (a INT);
ALTER TABLE t ADD COLUMN b INT DEFAULT 'x';
ALTER TABLE t ADD COLUMN b VARCHAR(0);
ALTER TABLE t ADD COLUMN b INT CHECK (a > 0);
ALTER TABLE t ADD COLUMN b INT CHECK (b);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- error 42601: syntax error: DEFAULT 'x' is not valid for column B INTEGER
-- error 42601: syntax error: CHARACTER VARYING length must be greater than 0
-- error 42601: syntax error: CHECK on column B cannot use column A
-- error 42804: data type mismatch in CHECK constraint: expected BOOLEAN but got INTEGER

-- # A CHECK on the new column must be satisfied by the existing rows.
CREATE TABLE t (a INT);
INSERT INTO t (a) VALUES (1), (2);
ALTER TABLE t ADD COLUMN b INT DEFAULT 0 CHECK (b > 0);
ALTER TABLE t ADD COLUMN b INT CHECK (b > 0);
INSERT INTO t (a, b) VALUES (3, 0);
ALTER TABLE t ADD COLUMN c INT DEFAULT 1 CHECK (c > 0);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- error 23514: violates check constraint: CHECK (B > 0) on ":memory:".PUBLIC.T
-- msg: ALTER TABLE 1
-- error 23514: violates check constraint: CHECK (B > 0) on ":memory:".PUBLIC.T
-- msg: ALTER TABLE 1
-- A: 1 B: NULL C: 1
-- A: 2 B: NULL C: 1

-- # The existing CHECK constraints are kept.
CREATE TABLE t (a INT CHECK (a > 0));
ALTER TABLE t ADD COLUMN b INT;
INSERT INTO t (a, b) VALUES (0, 1);
-- msg: CREATE TABLE 1
-- msg: ALTER TABLE 1
-- error 23514: violates check constraint: CHECK (A > 0) on ":memory:".PUBLIC.T

-- # A table can only have one PRIMARY KEY.
CREATE TABLE t (a INT PRIMARY KEY);
INSERT INTO t (a) VALUES (1);
ALTER TABLE t ADD COLUMN b INT PRIMARY KEY;
ALTER TABLE t ADD COLUMN b INT;
INSERT INTO t (a) VALUES (1);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 42601: syntax error: only one PRIMARY KEY can be defined
-- msg: ALTER TABLE 1
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T
-- A: 1 B: NULL

-- # The new column can be the PRIMARY KEY.
CREATE TABLE t (a INT);
ALTER TABLE t ADD COLUMN b INT PRIMARY KEY;
INSERT INTO t (a, b) VALUES (1, 1);
INSERT INTO t (a, b) VALUES (2, 1);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: ALTER TABLE 1
-- msg: INSERT 1
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T
-- A: 1 B: 1

-- # Each existing row gets the same default, so only one row can get a new
-- # PRIMARY KEY.
CREATE TABLE t (a INT);
INSERT INTO t (a) VALUES (1);
ALTER TABLE t ADD COLUMN b INT DEFAULT 7 PRIMARY KEY;
INSERT INTO t (a, b) VALUES (2, 7);
INSERT INTO t (a, b) VALUES (2, 8);
SELECT * FROM t WHERE b = 7;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: ALTER TABLE 1
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T
-- msg: INSERT 1
-- A: 1 B: 7

CREATE TABLE t (a INT);
INSERT INTO t (a) VALUES (1), (2);
ALTER TABLE t ADD COLUMN b INT DEFAULT 7 PRIMARY KEY;
ALTER TABLE t ADD COLUMN b INT PRIMARY KEY;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T
-- error 23502: violates non-null constraint: column B
-- A: 1
-- A: 2

-- # A ROLLBACK removes the column.
CREATE TABLE t (a INT);
INSERT INTO t (a) VALUES (1);
START TRANSACTION;
ALTER TABLE t ADD COLUMN b INT DEFAULT 2;
SELECT * FROM t;
ROLLBACK;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: ALTER TABLE 1
-- A: 1 B: 2
-- msg: ROLLBACK
-- A: 1

-- # The column is in the INFORMATION_SCHEMA.
CREATE TABLE t (a INT);
ALTER TABLE t ADD COLUMN b SMALLINT;
SELECT column_name, ordinal_position, data_type FROM information_schema.columns WHERE table_name = 'T';
-- msg: CREATE TABLE 1
-- msg: ALTER TABLE 1
-- COLUMN_NAME: A ORDINAL_POSITION: 1 DATA_TYPE: INTEGER
-- COLUMN_NAME: B ORDINAL_POSITION: 2 DATA_TYPE: SMALLINT

EXPLAIN ALTER TABLE t ADD COLUMN b INT;
-- error 42601: syntax error: Cannot EXPLAIN ALTER TABLE
