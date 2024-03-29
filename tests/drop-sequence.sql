EXPLAIN DROP SEQUENCE foo;
-- error 42601: syntax error: Cannot EXPLAIN DROP SEQUENCE

DROP SEQUENCE foo;
-- error 42P01: no such sequence: ":memory:".PUBLIC.FOO

CREATE SEQUENCE foo;
DROP SEQUENCE foo;
-- msg: CREATE SEQUENCE 1
-- msg: DROP SEQUENCE 1

CREATE SEQUENCE foo;
DROP SEQUENCE foo;
DROP SEQUENCE foo;
-- msg: CREATE SEQUENCE 1
-- msg: DROP SEQUENCE 1
-- error 42P01: no such sequence: ":memory:".PUBLIC.FOO

CREATE SEQUENCE foo;
VALUES NEXT VALUE FOR foo;
DROP SEQUENCE foo;
CREATE SEQUENCE foo;
VALUES NEXT VALUE FOR foo;
DROP SEQUENCE foo;
-- msg: CREATE SEQUENCE 1
-- COL1: 1
-- msg: DROP SEQUENCE 1
-- msg: CREATE SEQUENCE 1
-- COL1: 1
-- msg: DROP SEQUENCE 1
