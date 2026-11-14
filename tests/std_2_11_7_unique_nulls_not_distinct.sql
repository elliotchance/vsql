-- # A UNIQUE constraint with NULLS NOT DISTINCT doesn't allow two rows with
-- # the same values, even when they have NULLs in the same columns (F292,
-- # Conformance Rules, 4 and General Rules, 2.d). NULLS DISTINCT is the same as
-- # without one.
/* flags */
CREATE TABLE t (a INT, b INT, CONSTRAINT u UNIQUE NULLS NOT DISTINCT (a, b), c INT, UNIQUE NULLS DISTINCT (c));
INSERT INTO t (a, b, c) VALUES (1, NULL, NULL);
INSERT INTO t (a, b, c) VALUES (1, NULL, NULL);
INSERT INTO t (a, b, c) VALUES (1, 2, NULL);
INSERT INTO t (a, b, c) VALUES (NULL, NULL, NULL);
INSERT INTO t (a, b, c) VALUES (NULL, NULL, 3);
SELECT * FROM t;
-- flags: F292, F491, T591
-- msg: CREATE TABLE 1
-- flags:
-- msg: INSERT 1
-- flags:
-- error 23505: violates unique constraint: UNIQUE (A, B) on ":memory:".PUBLIC.T
-- flags:
-- msg: INSERT 1
-- flags:
-- msg: INSERT 1
-- flags:
-- error 23505: violates unique constraint: UNIQUE (A, B) on ":memory:".PUBLIC.T
-- flags:
-- A: 1 B: NULL C: NULL
-- A: 1 B: 2 C: NULL
-- A: NULL B: NULL C: NULL

-- # An UPDATE is checked the same way.
CREATE TABLE t (a INT, b INT, UNIQUE NULLS NOT DISTINCT (a, b));
INSERT INTO t (a, b) VALUES (1, NULL), (2, NULL);
UPDATE t SET a = 1;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- error 23505: violates unique constraint: UNIQUE (A, B) on ":memory:".PUBLIC.T
-- A: 1 B: NULL
-- A: 2 B: NULL

-- # It can be added to a table that has rows, which must not already have
-- # duplicates.
CREATE TABLE t (a INT, b INT);
INSERT INTO t (a, b) VALUES (1, NULL), (1, NULL);
ALTER TABLE t ADD CONSTRAINT u UNIQUE NULLS NOT DISTINCT (a, b);
DELETE FROM t WHERE a = 1;
ALTER TABLE t ADD CONSTRAINT u UNIQUE NULLS NOT DISTINCT (a, b);
INSERT INTO t (a, b) VALUES (1, NULL), (1, NULL);
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- error 23505: violates unique constraint: UNIQUE (A, B) on ":memory:".PUBLIC.T
-- msg: DELETE 2
-- msg: ALTER TABLE 1
-- error 23505: violates unique constraint: UNIQUE (A, B) on ":memory:".PUBLIC.T

-- # A PRIMARY KEY can't have one (Syntax Rules, 5).
CREATE TABLE t (a INT, PRIMARY KEY NULLS NOT DISTINCT (a));
-- error 42601: syntax error: unexpected NULLS at line 1, column 36 near ", PRIMARY KEY NULLS NOT", expecting "("


-- # It's kept in the definition of the table.
CREATE TABLE t (a INT, b INT, CONSTRAINT u UNIQUE NULLS NOT DISTINCT (a, b));
SELECT constraint_name, constraint_type FROM information_schema.table_constraints WHERE table_name = 'T';
-- msg: CREATE TABLE 1
-- CONSTRAINT_NAME: U CONSTRAINT_TYPE: UNIQUE
