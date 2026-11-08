-- # EXPLAIN only works for queries, not for schema statements such as CREATE
-- # SEQUENCE. NEXT VALUE FOR is always a BIGINT, the implementation-defined
-- # type of a sequence without AS (Syntax Rules, 6).
EXPLAIN CREATE SEQUENCE seq1;
-- error 42601: syntax error: Cannot EXPLAIN CREATE SEQUENCE

/* extensions V001-01 */
CREATE SEQUENCE seq1;
EXPLAIN SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
-- msg: CREATE SEQUENCE 1
-- EXPLAIN: T:
-- EXPLAIN:   VALUES (COL1 SMALLINT) = ROW(1)
-- EXPLAIN: TABLE T (COL1 SMALLINT)
-- EXPLAIN: EXPR (COL1 BIGINT)

-- # By default a sequence starts at 1 and goes up by 1, and each NEXT VALUE FOR
-- # returns the next value.
CREATE SEQUENCE seq1;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
-- msg: CREATE SEQUENCE 1
-- COL1: 1
-- COL1: 2

-- # The schema must exist. Without a schema the sequence is in PUBLIC, so
-- # PUBLIC.SEQ1 is the same sequence, and FOO.SEQ1 isn't found as SEQ1.
CREATE SEQUENCE foo.seq1;
-- error 3F000: invalid schema name: FOO

CREATE SEQUENCE public.seq1;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
SELECT NEXT VALUE FOR public.seq1 FROM (VALUES 1) AS t;
-- msg: CREATE SEQUENCE 1
-- COL1: 1
-- COL1: 2

CREATE SCHEMA foo;
CREATE SEQUENCE foo.seq1;
-- msg: CREATE SCHEMA 1
-- msg: CREATE SEQUENCE 1

SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
-- error 42P01: no such sequence: ":memory:".PUBLIC.SEQ1

-- # Each sequence has its own values.
CREATE SEQUENCE seq1;
CREATE SEQUENCE seq2;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
SELECT NEXT VALUE FOR seq2 FROM (VALUES 1) AS t;
-- msg: CREATE SEQUENCE 1
-- msg: CREATE SEQUENCE 1
-- COL1: 1
-- COL1: 1

-- # START WITH is the first value, and INCREMENT BY is added for each row, even
-- # rows of the same query. Without START WITH, an ascending sequence starts at
-- # its MINVALUE (9.30, Syntax Rules, 9.b.i). A negative INCREMENT BY counts
-- # down.
CREATE SEQUENCE seq1 START WITH 51;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
-- msg: CREATE SEQUENCE 1
-- COL1: 51
-- COL1: 52

CREATE SEQUENCE seq1 INCREMENT BY 2;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
-- msg: CREATE SEQUENCE 1
-- COL1: 1
-- COL1: 3

CREATE SEQUENCE seq1 INCREMENT BY 2;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
-- msg: CREATE SEQUENCE 1
-- COL1: 1
-- COL1: 3

CREATE SEQUENCE seq1 INCREMENT BY 2 START WITH 17;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
-- msg: CREATE SEQUENCE 1
-- COL1: 17
-- COL1: 19

CREATE SEQUENCE seq1 INCREMENT BY 2 MINVALUE 17;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
-- msg: CREATE SEQUENCE 1
-- COL1: 17
-- COL1: 19

CREATE SEQUENCE seq1 INCREMENT BY 3 MINVALUE 17 START WITH 24;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
-- msg: CREATE SEQUENCE 1
-- COL1: 24
-- COL1: 27

CREATE SEQUENCE seq1 START WITH -17 INCREMENT BY -2;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
-- msg: CREATE SEQUENCE 1
-- COL1: -17
-- COL1: -19

-- # Without a MAXVALUE, the maximum value of a descending sequence is -1.
CREATE SEQUENCE seq1 START WITH 17 INCREMENT BY -2;
-- error 42601: syntax error: START WITH (17) must not be greater than MAXVALUE (-1)

-- # A descending sequence starts at its implicit MAXVALUE, -1.
CREATE SEQUENCE seq1 INCREMENT BY -2;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
-- msg: CREATE SEQUENCE 1
-- COL1: -1
-- COL1: -3

-- # A descending sequence without START WITH starts at its MAXVALUE (9.30,
-- # Syntax Rules, 9.b.ii).
CREATE SEQUENCE seq1 INCREMENT BY -2 MAXVALUE 50;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
-- msg: CREATE SEQUENCE 1
-- COL1: 50
-- COL1: 48

CREATE SEQUENCE seq1 START WITH 17 INCREMENT BY -2 MAXVALUE 50;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
-- msg: CREATE SEQUENCE 1
-- COL1: 17
-- COL1: 15

-- # With CYCLE, an ascending sequence that goes past its MAXVALUE starts again
-- # at its MINVALUE (1 by default), not at START WITH (9.29, General Rules,
-- # 3.b.i).
CREATE SEQUENCE seq1 START WITH 10 INCREMENT BY 5 MAXVALUE 20 CYCLE;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
-- msg: CREATE SEQUENCE 1
-- COL1: 10
-- COL1: 15
-- COL1: 20
-- COL1: 1
-- COL1: 6
-- COL1: 11

CREATE SEQUENCE seq1 MINVALUE 10 INCREMENT BY 5 MAXVALUE 20 CYCLE;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
-- msg: CREATE SEQUENCE 1
-- COL1: 10
-- COL1: 15
-- COL1: 20
-- COL1: 10
-- COL1: 15
-- COL1: 20

CREATE SEQUENCE seq1 MINVALUE 5 INCREMENT BY 5 MAXVALUE 20 CYCLE START WITH 7;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
-- msg: CREATE SEQUENCE 1
-- COL1: 7
-- COL1: 12
-- COL1: 17
-- COL1: 5
-- COL1: 10
-- COL1: 15

-- # NO CYCLE is the default (9.30, Syntax Rules, 13). Going past MAXVALUE (or
-- # MINVALUE when descending) is then an error (9.29, General Rules, 3.a).
CREATE SEQUENCE seq1 START WITH 10 INCREMENT BY 5 MAXVALUE 20 NO CYCLE;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
-- msg: CREATE SEQUENCE 1
-- COL1: 10
-- COL1: 15
-- COL1: 20
-- error 2200H: sequence generator limit exceeded: PUBLIC.SEQ1

CREATE SEQUENCE seq1 START WITH 30 INCREMENT BY -5 MINVALUE 20 MAXVALUE 30 NO CYCLE;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
-- msg: CREATE SEQUENCE 1
-- COL1: 30
-- COL1: 25
-- COL1: 20
-- error 2200H: sequence generator limit exceeded: PUBLIC.SEQ1

CREATE SEQUENCE seq1 START WITH 10 INCREMENT BY 5 MAXVALUE 20;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
-- msg: CREATE SEQUENCE 1
-- COL1: 10
-- COL1: 15
-- COL1: 20
-- error 2200H: sequence generator limit exceeded: PUBLIC.SEQ1

CREATE SEQUENCE seq1 START WITH 30 INCREMENT BY -5 MINVALUE 20 MAXVALUE 30;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
-- msg: CREATE SEQUENCE 1
-- COL1: 30
-- COL1: 25
-- COL1: 20
-- error 2200H: sequence generator limit exceeded: PUBLIC.SEQ1

-- # NO MAXVALUE and NO MINVALUE are the default limits, the end of the range of
-- # a BIGINT in the direction of the sequence (9.30, Syntax Rules, 7.a.i and
-- # 8.a.i).
CREATE SEQUENCE seq1 START WITH 10 INCREMENT BY 5 NO MAXVALUE;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
-- msg: CREATE SEQUENCE 1
-- COL1: 10
-- COL1: 15
-- COL1: 20
-- COL1: 25

CREATE SEQUENCE seq1 START WITH -10 INCREMENT BY -5 NO MINVALUE;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
-- msg: CREATE SEQUENCE 1
-- COL1: -10
-- COL1: -15
-- COL1: -20
-- COL1: -25

-- # INCREMENT BY must not be 0 (9.30, Syntax Rules, 5), MAXVALUE must be more
-- # than MINVALUE, not equal (9.30, Syntax Rules, 11), and START WITH must be
-- # between them (9.30, Syntax Rules, 12).
CREATE SEQUENCE seq1 INCREMENT BY 0;
-- error 42601: syntax error: INCREMENT BY must not be 0

CREATE SEQUENCE seq1 MINVALUE 10 MAXVALUE 5;
-- error 42601: syntax error: MAXVALUE (5) must be greater than MINVALUE (10)

CREATE SEQUENCE seq1 MINVALUE 10 MAXVALUE 10;
-- error 42601: syntax error: MAXVALUE (10) must be greater than MINVALUE (10)

CREATE SEQUENCE seq1 START WITH 100 MAXVALUE 50;
-- error 42601: syntax error: START WITH (100) must not be greater than MAXVALUE (50)

CREATE SEQUENCE seq1 START WITH 1 MINVALUE 5;
-- error 42601: syntax error: START WITH (1) must not be less than MINVALUE (5)

-- # Each option can be given only once (Syntax Rules, 5). CYCLE and NO CYCLE
-- # are the same option, as are MAXVALUE and NO MAXVALUE.
CREATE SEQUENCE seq1 START WITH 1 START WITH 2;
-- error 42601: syntax error: START WITH is specified more than once

CREATE SEQUENCE seq1 CYCLE NO CYCLE;
-- error 42601: syntax error: CYCLE is specified more than once

CREATE SEQUENCE seq1 MAXVALUE 10 NO MAXVALUE;
-- error 42601: syntax error: MAXVALUE is specified more than once

-- # Each value must be an integer (9.30, Syntax Rules, 10), but it can be
-- # written as any number with an integer value, such as -1e2 or 2.0.
CREATE SEQUENCE seq1 INCREMENT BY 1.5;
-- error 42601: syntax error: INCREMENT BY must be an integer: 1.5

CREATE SEQUENCE seq1 START WITH 1.5;
-- error 42601: syntax error: START WITH must be an integer: 1.5

CREATE SEQUENCE seq1 START WITH -1e2 INCREMENT BY -1;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
-- msg: CREATE SEQUENCE 1
-- COL1: -100

CREATE SEQUENCE seq1 START WITH -5 INCREMENT BY 2.0 MINVALUE -10 MAXVALUE 0;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1, 2) AS t;
-- msg: CREATE SEQUENCE 1
-- COL1: -5
-- COL1: -3

-- # A sequence name can only be used once in a schema (Syntax Rules, 3). The
-- # failed CREATE leaves the existing sequence unchanged.
CREATE SEQUENCE seq1;
CREATE SEQUENCE seq1 START WITH 10;
SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;
-- msg: CREATE SEQUENCE 1
-- error 42P07: duplicate sequence: ":memory:".PUBLIC.SEQ1
-- COL1: 1

-- # A sequence with the same name in another schema, or a quoted name with
-- # different case, is a different sequence.
CREATE SCHEMA s;
CREATE SEQUENCE seq1;
CREATE SEQUENCE s.seq1;
CREATE SEQUENCE "seq1";
-- msg: CREATE SCHEMA 1
-- msg: CREATE SEQUENCE 1
-- msg: CREATE SEQUENCE 1
-- msg: CREATE SEQUENCE 1

-- # An option must be in the range of a BIGINT (#786).
CREATE SEQUENCE a START WITH 9223372036854775808;
CREATE SEQUENCE b START WITH 99999999999999999999;
CREATE SEQUENCE c MAXVALUE 1e30;
CREATE SEQUENCE d MINVALUE -1e30;
CREATE SEQUENCE e INCREMENT BY 9223372036854775808;
CREATE SEQUENCE f START WITH 9223372036854775807;
CREATE SEQUENCE g START WITH -9223372036854775808 MINVALUE -9223372036854775808;
-- error 42601: syntax error: START WITH is out of range for BIGINT: 9223372036854775808
-- error 42601: syntax error: START WITH is out of range for BIGINT: 99999999999999999999
-- error 42601: syntax error: MAXVALUE is out of range for BIGINT: 1e+30
-- error 42601: syntax error: MINVALUE is out of range for BIGINT: -1e+30
-- error 42601: syntax error: INCREMENT BY is out of range for BIGINT: 9223372036854775808
-- msg: CREATE SEQUENCE 1
-- msg: CREATE SEQUENCE 1
