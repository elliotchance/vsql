-- # SET DATA TYPE changes the type of a column, and the existing values are
-- # cast to it. A CHARACTER value is padded to the new length.
CREATE TABLE t (a SMALLINT, b CHARACTER(3), c VARCHAR(5), d NUMERIC(5, 2));
INSERT INTO t (a, b, c, d) VALUES (1, 'ab', 'x', 1.5);
ALTER TABLE t ALTER COLUMN a SET DATA TYPE BIGINT;
ALTER TABLE t ALTER b SET DATA TYPE CHARACTER(6);
ALTER TABLE t ALTER COLUMN c SET DATA TYPE CHARACTER(10);
ALTER TABLE t ALTER COLUMN d SET DATA TYPE NUMERIC(8, 3);
SELECT a, '[' || b || ']' AS b, '[' || c || ']' AS c, d FROM t;
INSERT INTO t (a, b, c, d) VALUES (9223372036854775807, 'abcdef', 'abcdefghij', 12345.678);
SELECT a, d FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- A: 1 B: [ab    ] C: [x         ] D: 1.500
-- msg: INSERT 1
-- A: 1 D: 1.500
-- A: 9223372036854775807 D: 12345.678

-- # The new type must hold every value of the old type, so it's the same kind
-- # of type that's at least as big. Otherwise, it's an error and nothing
-- # changes.
CREATE TABLE t (a INTEGER, b NUMERIC(5, 2), c VARCHAR(10), d TIME(3), e REAL, f DATE, g BOOLEAN);
ALTER TABLE t ALTER COLUMN a SET DATA TYPE SMALLINT;
ALTER TABLE t ALTER COLUMN a SET DATA TYPE NUMERIC(9);
ALTER TABLE t ALTER COLUMN a SET DATA TYPE REAL;
ALTER TABLE t ALTER COLUMN b SET DATA TYPE NUMERIC(6, 1);
ALTER TABLE t ALTER COLUMN b SET DATA TYPE NUMERIC(5, 3);
ALTER TABLE t ALTER COLUMN b SET DATA TYPE INTEGER;
ALTER TABLE t ALTER COLUMN c SET DATA TYPE VARCHAR(9);
ALTER TABLE t ALTER COLUMN c SET DATA TYPE VARCHAR(39 OCTETS);
ALTER TABLE t ALTER COLUMN c SET DATA TYPE INTEGER;
ALTER TABLE t ALTER COLUMN d SET DATA TYPE TIME(2);
ALTER TABLE t ALTER COLUMN d SET DATA TYPE TIME(3) WITH TIME ZONE;
ALTER TABLE t ALTER COLUMN d SET DATA TYPE TIMESTAMP(3);
ALTER TABLE t ALTER COLUMN e SET DATA TYPE INTEGER;
ALTER TABLE t ALTER COLUMN f SET DATA TYPE TIMESTAMP;
ALTER TABLE t ALTER COLUMN g SET DATA TYPE CHARACTER(5);
-- msg: CREATE TABLE 1
-- error 42601: syntax error: cannot change the data type of column A from INTEGER to SMALLINT
-- error 42601: syntax error: cannot change the data type of column A from INTEGER to NUMERIC(9)
-- error 42601: syntax error: cannot change the data type of column A from INTEGER to REAL
-- error 42601: syntax error: cannot change the data type of column B from NUMERIC(5, 2) to NUMERIC(6, 1)
-- error 42601: syntax error: cannot change the data type of column B from NUMERIC(5, 2) to NUMERIC(5, 3)
-- error 42601: syntax error: cannot change the data type of column B from NUMERIC(5, 2) to INTEGER
-- error 42601: syntax error: cannot change the data type of column C from CHARACTER VARYING(10) to CHARACTER VARYING(9)
-- error 42601: syntax error: cannot change the data type of column C from CHARACTER VARYING(10) to CHARACTER VARYING(39 OCTETS)
-- error 42601: syntax error: cannot change the data type of column C from CHARACTER VARYING(10) to INTEGER
-- error 42601: syntax error: cannot change the data type of column D from TIME(3) WITHOUT TIME ZONE to TIME(2) WITHOUT TIME ZONE
-- error 42601: syntax error: cannot change the data type of column D from TIME(3) WITHOUT TIME ZONE to TIME(3) WITH TIME ZONE
-- error 42601: syntax error: cannot change the data type of column D from TIME(3) WITHOUT TIME ZONE to TIMESTAMP(3) WITHOUT TIME ZONE
-- error 42601: syntax error: cannot change the data type of column E from REAL to INTEGER
-- error 42601: syntax error: cannot change the data type of column F from DATE to TIMESTAMP(6) WITHOUT TIME ZONE
-- error 42601: syntax error: cannot change the data type of column G from BOOLEAN to CHARACTER(5)

-- # Each kind of type can be made bigger. An integer type can be a NUMERIC or
-- # DECIMAL that has room for all of its digits, and the other way around.
CREATE TABLE t (a SMALLINT, b INTEGER, c NUMERIC(4), d NUMERIC(5, 2), e DECIMAL(3), f VARCHAR(10 OCTETS), g VARCHAR(10), h TIME(3) WITH TIME ZONE, i TIMESTAMP(0), j REAL, k DOUBLE PRECISION, l DATE, m BOOLEAN);
ALTER TABLE t ALTER COLUMN a SET DATA TYPE NUMERIC(5);
ALTER TABLE t ALTER COLUMN b SET DATA TYPE DECIMAL(12, 2);
ALTER TABLE t ALTER COLUMN c SET DATA TYPE SMALLINT;
ALTER TABLE t ALTER COLUMN d SET DATA TYPE NUMERIC(10, 2);
ALTER TABLE t ALTER COLUMN e SET DATA TYPE NUMERIC(3);
ALTER TABLE t ALTER COLUMN f SET DATA TYPE CHARACTER(10);
ALTER TABLE t ALTER COLUMN g SET DATA TYPE VARCHAR(40 OCTETS);
ALTER TABLE t ALTER COLUMN h SET DATA TYPE TIME(6) WITH TIME ZONE;
ALTER TABLE t ALTER COLUMN i SET DATA TYPE TIMESTAMP;
ALTER TABLE t ALTER COLUMN j SET DATA TYPE DOUBLE PRECISION;
ALTER TABLE t ALTER COLUMN k SET DATA TYPE DOUBLE PRECISION;
ALTER TABLE t ALTER COLUMN l SET DATA TYPE DATE;
ALTER TABLE t ALTER COLUMN m SET DATA TYPE BOOLEAN;
-- msg: CREATE TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1

-- # A column of the PRIMARY KEY, UNIQUE, a FOREIGN KEY or an index can be
-- # changed, and they still work. The rows are stored by their PRIMARY KEY, so
-- # they're moved.
/* extensions V002-01 */
CREATE TABLE p (id SMALLINT PRIMARY KEY, code CHARACTER(2) UNIQUE, name VARCHAR(10));
CREATE TABLE c (pid SMALLINT REFERENCES p (id));
CREATE INDEX p_name ON p (name);
INSERT INTO p (id, code, name) VALUES (1, 'a', 'one'), (2, 'b', 'two');
INSERT INTO c (pid) VALUES (2);
ALTER TABLE p ALTER COLUMN id SET DATA TYPE BIGINT;
ALTER TABLE p ALTER COLUMN code SET DATA TYPE CHARACTER(4);
ALTER TABLE p ALTER COLUMN name SET DATA TYPE VARCHAR(20);
ALTER TABLE c ALTER COLUMN pid SET DATA TYPE INTEGER;
SELECT id, name FROM p WHERE id = 2;
SELECT id, name FROM p WHERE name = 'one';
INSERT INTO p (id, code, name) VALUES (3, 'a', 'three');
INSERT INTO c (pid) VALUES (3);
DELETE FROM p WHERE id = 2;
INSERT INTO c (pid) VALUES (1);
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: CREATE INDEX 1
-- msg: INSERT 2
-- msg: INSERT 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- ID: 2 NAME: two
-- ID: 1 NAME: one
-- error 23505: violates unique constraint: UNIQUE (CODE) on ":memory:".PUBLIC.P
-- error 23503: violates foreign key constraint: FOREIGN KEY (PID) REFERENCES ":memory:".PUBLIC.P (ID) on ":memory:".PUBLIC.C
-- error 23503: violates foreign key constraint: FOREIGN KEY (PID) REFERENCES ":memory:".PUBLIC.P (ID) on ":memory:".PUBLIC.C
-- msg: INSERT 1

-- # The column can't be used by a CHECK constraint that uses other columns, or
-- # by a generated column. A CHECK constraint of only the column is checked
-- # again.
CREATE TABLE t (a INT, b INT, c INT GENERATED ALWAYS AS (a + 1), CONSTRAINT ab CHECK (a < b), CONSTRAINT bb CHECK (b > 0));
ALTER TABLE t ALTER COLUMN a SET DATA TYPE BIGINT;
ALTER TABLE t ALTER COLUMN b SET DATA TYPE BIGINT;
ALTER TABLE t DROP CONSTRAINT ab RESTRICT;
ALTER TABLE t ALTER COLUMN a SET DATA TYPE BIGINT;
ALTER TABLE t ALTER COLUMN b SET DATA TYPE BIGINT;
ALTER TABLE t ALTER COLUMN c SET DATA TYPE BIGINT;
-- msg: CREATE TABLE 1
-- error 42601: syntax error: cannot change the data type of column A, it is used by constraint AB
-- error 42601: syntax error: cannot change the data type of column B, it is used by constraint AB
-- msg: ALTER TABLE 1
-- error 42601: syntax error: cannot change the data type of column A, it is used by generated column C
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1

-- # An identity column can only be changed by an <alter identity column
-- # specification>, and NOT NULL and the default stay.
CREATE TABLE t (a INT GENERATED ALWAYS AS IDENTITY, b INT DEFAULT 3 NOT NULL);
ALTER TABLE t ALTER COLUMN a SET DATA TYPE BIGINT;
ALTER TABLE t ALTER COLUMN b SET DATA TYPE BIGINT;
INSERT INTO t (b) VALUES (NULL);
INSERT INTO t DEFAULT VALUES;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- error 42601: syntax error: cannot change the data type of identity column A
-- msg: ALTER TABLE 1
-- error 23502: violates non-null constraint: column B
-- msg: INSERT 1
-- A: 1 B: 3

-- # It's rolled back with the transaction.
CREATE TABLE t (a SMALLINT PRIMARY KEY);
INSERT INTO t (a) VALUES (1);
START TRANSACTION;
ALTER TABLE t ALTER COLUMN a SET DATA TYPE BIGINT;
INSERT INTO t (a) VALUES (100000);
ROLLBACK;
INSERT INTO t (a) VALUES (100000);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: ALTER TABLE 1
-- msg: INSERT 1
-- msg: ROLLBACK
-- error 22003: numeric value out of range
-- A: 1

-- # The flagger.
/* flags */
CREATE TABLE t (a SMALLINT);
ALTER TABLE t ALTER COLUMN a SET DATA TYPE INTEGER;
-- flags:
-- msg: CREATE TABLE 1
-- flags: F382, F387
-- msg: ALTER TABLE 1
