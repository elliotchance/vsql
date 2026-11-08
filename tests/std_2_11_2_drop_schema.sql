-- # DROP SCHEMA can't be used with EXPLAIN.
EXPLAIN DROP SCHEMA foo RESTRICT;
-- error 42601: syntax error: Cannot EXPLAIN DROP SCHEMA

-- # The schema must exist (Syntax Rules, 2), so it can't be dropped twice.
DROP SCHEMA foo RESTRICT;
-- error 3F000: invalid schema name: FOO

CREATE SCHEMA foo;
DROP SCHEMA foo RESTRICT;
-- msg: CREATE SCHEMA 1
-- msg: DROP SCHEMA 1

CREATE SCHEMA foo;
DROP SCHEMA foo RESTRICT;
DROP SCHEMA foo RESTRICT;
-- msg: CREATE SCHEMA 1
-- msg: DROP SCHEMA 1
-- error 3F000: invalid schema name: FOO

-- # RESTRICT can't drop a schema that still has a table (Syntax Rules, 4), so
-- # the table can still be used. CASCADE drops the table as well (General
-- # Rules, 1).
CREATE SCHEMA foo;
CREATE TABLE foo.bar (baz INT);
DROP SCHEMA foo RESTRICT;
INSERT INTO foo.bar (baz) VALUES (123);
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- error 2BP01: dependent objects still exist on FOO
-- msg: INSERT 1

CREATE SCHEMA foo;
CREATE TABLE foo.bar (baz INT);
DROP SCHEMA foo CASCADE;
INSERT INTO foo.bar (baz) VALUES (123);
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: DROP SCHEMA 1
-- error 3F000: invalid schema name: FOO

-- # The same for a sequence: CASCADE drops the sequences of the schema (General
-- # Rules, 12), but not a sequence with the same name in another schema.
CREATE SCHEMA foo;
CREATE SEQUENCE foo.seq1;
DROP SCHEMA foo RESTRICT;
SELECT NEXT VALUE FOR foo.seq1 FROM (VALUES 1) AS t;
-- msg: CREATE SCHEMA 1
-- msg: CREATE SEQUENCE 1
-- error 2BP01: dependent objects still exist on FOO
-- COL1: 1

CREATE SCHEMA foo;
CREATE SEQUENCE foo.seq1;
CREATE SEQUENCE seq1;
SELECT NEXT VALUE FOR foo.seq1 FROM (VALUES 1) AS t;
DROP SCHEMA foo CASCADE;
SELECT NEXT VALUE FOR foo.seq1 FROM (VALUES 1) AS t;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
-- msg: CREATE SCHEMA 1
-- msg: CREATE SEQUENCE 1
-- msg: CREATE SEQUENCE 1
-- COL1: 1
-- msg: DROP SCHEMA 1
-- error 42P01: no such sequence: ":memory:".FOO.SEQ1
-- COL1: 1

-- # A sequence of a schema that's created again with the same name starts from
-- # the beginning, not from the value of the dropped sequence.
CREATE SCHEMA foo;
CREATE SEQUENCE foo.seq1;
SELECT NEXT VALUE FOR foo.seq1 FROM (VALUES 1) AS t;
DROP SCHEMA foo CASCADE;
CREATE SCHEMA foo;
CREATE SEQUENCE foo.seq1;
SELECT NEXT VALUE FOR foo.seq1 FROM (VALUES 1) AS t;
-- msg: CREATE SCHEMA 1
-- msg: CREATE SEQUENCE 1
-- COL1: 1
-- msg: DROP SCHEMA 1
-- msg: CREATE SCHEMA 1
-- msg: CREATE SEQUENCE 1
-- COL1: 1
