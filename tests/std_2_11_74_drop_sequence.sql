-- # EXPLAIN only works for queries, not for schema statements.
EXPLAIN DROP SEQUENCE foo RESTRICT;
-- error 42601: syntax error: Cannot EXPLAIN DROP SEQUENCE

-- # The sequence must exist (Syntax Rules, 2), so it can't be dropped twice.
DROP SEQUENCE foo RESTRICT;
-- error 42P01: no such sequence: ":memory:".PUBLIC.FOO

CREATE SEQUENCE foo;
DROP SEQUENCE foo RESTRICT;
-- msg: CREATE SEQUENCE 1
-- msg: DROP SEQUENCE 1

CREATE SEQUENCE foo;
DROP SEQUENCE foo RESTRICT;
DROP SEQUENCE foo RESTRICT;
-- msg: CREATE SEQUENCE 1
-- msg: DROP SEQUENCE 1
-- error 42P01: no such sequence: ":memory:".PUBLIC.FOO

-- # Dropping a sequence destroys it (General Rules, 2), so a new one with the
-- # same name starts again, and NEXT VALUE FOR can't find a dropped one.
CREATE SEQUENCE foo;
SELECT NEXT VALUE FOR foo FROM (VALUES 1) AS t;
DROP SEQUENCE foo RESTRICT;
CREATE SEQUENCE foo;
SELECT NEXT VALUE FOR foo FROM (VALUES 1) AS t;
DROP SEQUENCE foo RESTRICT;
-- msg: CREATE SEQUENCE 1
-- COL1: 1
-- msg: DROP SEQUENCE 1
-- msg: CREATE SEQUENCE 1
-- COL1: 1
-- msg: DROP SEQUENCE 1

CREATE SEQUENCE foo;
DROP SEQUENCE foo RESTRICT;
SELECT NEXT VALUE FOR foo FROM (VALUES 1) AS t;
-- msg: CREATE SEQUENCE 1
-- msg: DROP SEQUENCE 1
-- error 42P01: no such sequence: ":memory:".PUBLIC.FOO

-- # CASCADE works the same as RESTRICT. Nothing can depend on a sequence yet,
-- # because routines and triggers aren't supported (Syntax Rules, 3). Either
-- # way the sequence must exist.
CREATE SEQUENCE foo;
SELECT NEXT VALUE FOR foo FROM (VALUES 1) AS t;
DROP SEQUENCE foo CASCADE;
SELECT NEXT VALUE FOR foo FROM (VALUES 1) AS t;
-- msg: CREATE SEQUENCE 1
-- COL1: 1
-- msg: DROP SEQUENCE 1
-- error 42P01: no such sequence: ":memory:".PUBLIC.FOO

DROP SEQUENCE foo RESTRICT;
-- error 42P01: no such sequence: ":memory:".PUBLIC.FOO

DROP SEQUENCE foo CASCADE;
-- error 42P01: no such sequence: ":memory:".PUBLIC.FOO

EXPLAIN DROP SEQUENCE foo RESTRICT;
-- error 42601: syntax error: Cannot EXPLAIN DROP SEQUENCE
