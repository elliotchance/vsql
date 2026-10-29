-- # Any type can be in a PRIMARY KEY (#57). Equal values are the same key (such
-- # as -0 and 0, 1.5 and 1.50, 'a' and 'a ', or times that are the same in UTC)
-- # and the rows are in the order of the keys.

CREATE TABLE t (b BOOLEAN PRIMARY KEY);
INSERT INTO t (b) VALUES (TRUE), (FALSE);
INSERT INTO t (b) VALUES (TRUE);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T
-- B: FALSE
-- B: TRUE

CREATE TABLE t (r REAL PRIMARY KEY);
INSERT INTO t (r) VALUES (1.5), (-2.5), (0), (-0.5), (100), (-100), (3e38), (-3e38);
INSERT INTO t (r) VALUES (-0e0);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 8
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T
-- R: -3e+38
-- R: -100e0
-- R: -2.5e0
-- R: -0.5e0
-- R: 0e0
-- R: 1.5e0
-- R: 100e0
-- R: 3e+38

CREATE TABLE t (f DOUBLE PRECISION PRIMARY KEY);
INSERT INTO t (f) VALUES (1.5e0), (-2.5e0), (0e0), (-0.5e0), (1e300), (-1e300);
INSERT INTO t (f) VALUES (-0e0);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 6
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T
-- F: -1e+300
-- F: -2.5e0
-- F: -0.5e0
-- F: 0e0
-- F: 1.5e0
-- F: 1e+300

CREATE TABLE t (n NUMERIC(10, 3) PRIMARY KEY);
INSERT INTO t (n) VALUES (1.5), (-2.5), (0), (-0.05), (0.05), (100), (-100), (10), (1.25), (-1.25), (0.5), (-0.5), (99.999), (-99.999);
INSERT INTO t (n) VALUES (1.50);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 14
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T
-- N: -100.000
-- N: -99.999
-- N: -2.500
-- N: -1.250
-- N: -0.500
-- N: -0.050
-- N: 0.000
-- N: 0.050
-- N: 0.500
-- N: 1.250
-- N: 1.500
-- N: 10.000
-- N: 99.999
-- N: 100.000

CREATE TABLE t (d DECIMAL(10, 2) PRIMARY KEY);
INSERT INTO t (d) VALUES (1.5), (-2.5), (0), (100), (10);
INSERT INTO t (d) VALUES (10.00);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 5
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T
-- D: -2.50
-- D: 0.00
-- D: 1.50
-- D: 10.00
-- D: 100.00

-- # A DECIMAL can hold more digits than its scale (#223). 1.23 / 5 is shown as
-- # 0.24, but it isn't equal to 0.24, so it's a different key.
CREATE TABLE t (d DECIMAL(3, 2) PRIMARY KEY);
INSERT INTO t (d) VALUES (CAST(1.23 AS DECIMAL(3, 2)) / 5);
INSERT INTO t (d) VALUES (0.24), (0.25);
INSERT INTO t (d) VALUES (CAST(1.23 AS DECIMAL(3, 2)) / 5);
INSERT INTO t (d) VALUES (CAST(-1 AS DECIMAL(3, 2)) / 3), (CAST(-1 AS DECIMAL(3, 2)) / 4), (CAST(1 AS DECIMAL(3, 2)) / 3);
SELECT d, d * 5, d * 3 FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 2
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T
-- msg: INSERT 3
-- D: -0.33 COL2: -1.66 COL3: -1.00
-- D: -0.25 COL2: -1.25 COL3: -0.75
-- D: 0.24 COL2: 1.20 COL3: 0.72
-- D: 0.24 COL2: 1.23 COL3: 0.73
-- D: 0.25 COL2: 1.25 COL3: 0.75
-- D: 0.33 COL2: 1.66 COL3: 1.00

CREATE TABLE t (n NUMERIC PRIMARY KEY);
INSERT INTO t (n) VALUES (123456789012345678901234567890), (-5), (7);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- N: -5
-- N: 7
-- N: 123456789012345678901234567890

CREATE TABLE t (c CHAR(5) PRIMARY KEY);
INSERT INTO t (c) VALUES ('b'), ('a'), ('ab'), ('');
INSERT INTO t (c) VALUES ('a  ');
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 4
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T
-- C:
-- C: a
-- C: ab
-- C: b

CREATE TABLE t (v VARCHAR(10) PRIMARY KEY);
INSERT INTO t (v) VALUES ('b'), ('a'), ('ab'), (''), ('a b'), ('é');
INSERT INTO t (v) VALUES ('a ');
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 6
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T
-- V:
-- V: a
-- V: a b
-- V: ab
-- V: b
-- V: é

-- # The rows are in the same order as ORDER BY, which compares strings as if the
-- # shorter one is padded with spaces. So 'a' is after 'a' and a tab.
CREATE TABLE t (v VARCHAR(10), n INT, PRIMARY KEY (v, n));
INSERT INTO t (v, n) VALUES ('a', 1), ('a	', 2), ('a b', 3), ('a  b', 4), ('a 	', 5), ('ab', 6), ('', 7), ('a~', 8), (' ', 9), ('a 	b', 10), ('a ', 11);
SELECT n FROM t;
SELECT n FROM t ORDER BY v, n;
-- msg: CREATE TABLE 1
-- msg: INSERT 11
-- N: 7
-- N: 9
-- N: 2
-- N: 5
-- N: 10
-- N: 1
-- N: 11
-- N: 4
-- N: 3
-- N: 6
-- N: 8
-- N: 7
-- N: 9
-- N: 2
-- N: 5
-- N: 10
-- N: 1
-- N: 11
-- N: 4
-- N: 3
-- N: 6
-- N: 8

CREATE TABLE t (d DATE PRIMARY KEY);
INSERT INTO t (d) VALUES (DATE '2022-06-30'), (DATE '1999-01-01'), (DATE '2022-07-01');
INSERT INTO t (d) VALUES (DATE '2022-06-30');
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T
-- D: 1999-01-01
-- D: 2022-06-30
-- D: 2022-07-01

CREATE TABLE t (t TIME PRIMARY KEY);
INSERT INTO t (t) VALUES (TIME '12:00:00'), (TIME '01:00:00'), (TIME '23:59:59');
INSERT INTO t (t) VALUES (TIME '12:00:00');
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T
-- T: 01:00:00
-- T: 12:00:00
-- T: 23:59:59

CREATE TABLE t (t TIME(3) WITH TIME ZONE PRIMARY KEY);
INSERT INTO t (t) VALUES (TIME '12:00:00.123+05:00'), (TIME '08:00:00+00:00');
INSERT INTO t (t) VALUES (TIME '07:00:00.123+00:00');
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T
-- T: 12:00:00.123+0500
-- T: 08:00:00.000+0000

CREATE TABLE t (t TIMESTAMP PRIMARY KEY);
INSERT INTO t (t) VALUES (TIMESTAMP '2022-06-30 12:00:00'), (TIMESTAMP '2022-06-30 11:59:59.999999'), (TIMESTAMP '1970-01-01 00:00:00'), (TIMESTAMP '0001-01-01 00:00:00');
INSERT INTO t (t) VALUES (TIMESTAMP '2022-06-30 12:00:00');
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 4
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T
-- T: 0001-01-01T00:00:00.000000
-- T: 1970-01-01T00:00:00.000000
-- T: 2022-06-30T11:59:59.999999
-- T: 2022-06-30T12:00:00.000000

CREATE TABLE t (t TIMESTAMP WITH TIME ZONE PRIMARY KEY);
INSERT INTO t (t) VALUES (TIMESTAMP '2022-06-30 12:00:00+05:00'), (TIMESTAMP '2022-06-30 08:00:00+00:00');
INSERT INTO t (t) VALUES (TIMESTAMP '2022-06-30 07:00:00+00:00');
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T
-- T: 2022-06-30T12:00:00.000000+0500
-- T: 2022-06-30T08:00:00.000000+0000

-- # Each value of a PRIMARY KEY with several columns ends where the next one
-- # starts.
CREATE TABLE t (a VARCHAR(10), b INT, PRIMARY KEY (a, b));
INSERT INTO t (a, b) VALUES ('a', 2), ('ab', 1), ('a', 1), ('', 5);
INSERT INTO t (a, b) VALUES ('a ', 1);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 4
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T
-- A:  B: 5
-- A: a B: 1
-- A: a B: 2
-- A: ab B: 1

-- # A 0 byte isn't the end of a string, so 'a' and 'a' with a 0 byte are
-- # different keys. A 0 byte sorts before the space that 'a' is padded with.
CREATE TABLE t (s VARCHAR(10), x INT, PRIMARY KEY (s, x));
INSERT INTO t (s, x) VALUES ('a', 1), (U&'a\0000', 1), (U&'a\0000b', 1);
SELECT OCTET_LENGTH(s) FROM t;
INSERT INTO t (s, x) VALUES (U&'a\0000', 1);
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- COL1: 2
-- COL1: 3
-- COL1: 1
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T

-- # A PRIMARY KEY that isn't an integer is not used to find a row (yet).
/* extensions V001-01 */
CREATE TABLE t (id VARCHAR(10) PRIMARY KEY, x INT);
INSERT INTO t (id, x) VALUES ('a', 1), ('b', 2);
EXPLAIN SELECT * FROM t WHERE id = 'a';
SELECT * FROM t WHERE id = 'a';
UPDATE t SET id = 'b' WHERE id = 'a';
UPDATE t SET id = 'c' WHERE id = 'a';
DELETE FROM t WHERE id = 'b';
SELECT * FROM t;
SELECT * FROM t WHERE id = 1;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (ID CHARACTER VARYING(10) NOT NULL, X INTEGER)
-- EXPLAIN: WHERE ID = 'a'
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.ID CHARACTER VARYING(10) NOT NULL, ":memory:".PUBLIC.T.X INTEGER)
-- ID: a X: 1
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T
-- msg: UPDATE 1
-- msg: DELETE 1
-- ID: c X: 1
-- error 42883: cannot compare CHARACTER VARYING(10) and SMALLINT
