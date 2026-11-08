-- # EXPLAIN only works for queries, not for schema statements.
EXPLAIN ALTER SEQUENCE seq1 RESTART;
-- error 42601: syntax error: Cannot EXPLAIN ALTER SEQUENCE

-- # RESTART goes back to START WITH (9.31, Syntax Rules, 9.c), and RESTART WITH
-- # sets the next value (9.31, Syntax Rules, 9.b), even below START WITH.
CREATE SEQUENCE seq1;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
ALTER SEQUENCE seq1 RESTART;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
-- msg: CREATE SEQUENCE 1
-- COL1: 1
-- msg: ALTER SEQUENCE 1
-- COL1: 1

CREATE SEQUENCE seq1;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
ALTER SEQUENCE seq1 RESTART WITH 25;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
-- msg: CREATE SEQUENCE 1
-- COL1: 1
-- msg: ALTER SEQUENCE 1
-- COL1: 25

CREATE SEQUENCE seq1 START WITH 51 INCREMENT BY 2;
ALTER SEQUENCE seq1 RESTART WITH 13;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
-- msg: CREATE SEQUENCE 1
-- msg: ALTER SEQUENCE 1
-- COL1: 13
-- COL1: 15

-- # Without RESTART, the sequence carries on from where it was (9.31, Syntax
-- # Rules, 9.a). A new INCREMENT BY is added to the last value returned.
CREATE SEQUENCE seq1 START WITH 51 INCREMENT BY 2;
ALTER SEQUENCE seq1 MAXVALUE 100;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
-- msg: CREATE SEQUENCE 1
-- msg: ALTER SEQUENCE 1
-- COL1: 51
-- COL1: 53

CREATE SEQUENCE seq1 INCREMENT BY 2;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
ALTER SEQUENCE seq1 INCREMENT BY 3;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
-- msg: CREATE SEQUENCE 1
-- COL1: 1
-- COL1: 3
-- msg: ALTER SEQUENCE 1
-- COL1: 6
-- COL1: 9

-- # CYCLE and NO CYCLE can be changed at any time. A query that fails part way
-- # still uses up the values it already got, so 20 isn't returned again after
-- # its query fails at 25.
CREATE SEQUENCE seq1 START WITH 10 INCREMENT BY 5 MAXVALUE 20 CYCLE;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
ALTER SEQUENCE seq1 NO CYCLE;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
-- msg: CREATE SEQUENCE 1
-- COL1: 10
-- COL1: 15
-- COL1: 20
-- COL1: 1
-- msg: ALTER SEQUENCE 1
-- COL1: 6
-- COL1: 11
-- error 2200H: sequence generator limit exceeded: PUBLIC.SEQ1

CREATE SEQUENCE seq1 START WITH 10 INCREMENT BY 5 MAXVALUE 20 NO CYCLE;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
ALTER SEQUENCE seq1 CYCLE;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
-- msg: CREATE SEQUENCE 1
-- COL1: 10
-- COL1: 15
-- error 2200H: sequence generator limit exceeded: PUBLIC.SEQ1
-- msg: ALTER SEQUENCE 1
-- COL1: 1
-- COL1: 6
-- COL1: 11
-- COL1: 16

-- # RESTART goes back to the start after several values too.
CREATE SEQUENCE seq1;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
ALTER SEQUENCE seq1 RESTART;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
-- msg: CREATE SEQUENCE 1
-- COL1: 1
-- COL1: 2
-- msg: ALTER SEQUENCE 1
-- COL1: 1
-- COL1: 2

-- # A new INCREMENT BY must not be 0 (9.31, Syntax Rules, 5.a.ii), MAXVALUE
-- # must be more than MINVALUE (9.31, Syntax Rules, 11), RESTART WITH must be
-- # between them (9.31, Syntax Rules, 12), each option can be given only once
-- # (9.31, Syntax Rules, 4) and values must be integers (9.31, Syntax Rules,
-- # 10).
CREATE SEQUENCE seq1;
ALTER SEQUENCE seq1 INCREMENT BY 0;
-- msg: CREATE SEQUENCE 1
-- error 42601: syntax error: INCREMENT BY must not be 0

CREATE SEQUENCE seq1 MINVALUE 1;
ALTER SEQUENCE seq1 MAXVALUE 0;
-- msg: CREATE SEQUENCE 1
-- error 42601: syntax error: MAXVALUE (0) must be greater than MINVALUE (1)

CREATE SEQUENCE seq1 MINVALUE 1;
ALTER SEQUENCE seq1 RESTART WITH 0;
-- msg: CREATE SEQUENCE 1
-- error 42601: syntax error: RESTART WITH (0) must not be less than MINVALUE (1)

CREATE SEQUENCE seq1;
ALTER SEQUENCE seq1 RESTART RESTART;
-- msg: CREATE SEQUENCE 1
-- error 42601: syntax error: RESTART is specified more than once

CREATE SEQUENCE seq1;
ALTER SEQUENCE seq1 RESTART WITH 2.5;
-- msg: CREATE SEQUENCE 1
-- error 42601: syntax error: RESTART must be an integer: 2.5

-- # NO MAXVALUE and NO MINVALUE go back to the default limits without changing
-- # the next value, so the sequence can go past its old MAXVALUE, and carries
-- # on from its old MINVALUE.
CREATE SEQUENCE seq1 MAXVALUE 2;
ALTER SEQUENCE seq1 NO MAXVALUE;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2, 3) AS t;
-- msg: CREATE SEQUENCE 1
-- msg: ALTER SEQUENCE 1
-- COL1: 1
-- COL1: 2
-- COL1: 3

CREATE SEQUENCE seq1 MINVALUE 5;
ALTER SEQUENCE seq1 NO MINVALUE;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
-- msg: CREATE SEQUENCE 1
-- msg: ALTER SEQUENCE 1
-- COL1: 5

-- # The restart value must be in the range of a BIGINT (#786).
CREATE SEQUENCE a;
ALTER SEQUENCE a RESTART WITH 1e20;
-- msg: CREATE SEQUENCE 1
-- error 42601: syntax error: RESTART is out of range for BIGINT: 1e+20
