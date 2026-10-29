CREATE TABLE t (a INT CHECK (a > 0));
INSERT INTO t (a) VALUES (1);
INSERT INTO t (a) VALUES (0);
INSERT INTO t (a) VALUES (-5);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 23514: violates check constraint: CHECK (A > 0) on ":memory:".PUBLIC.T
-- error 23514: violates check constraint: CHECK (A > 0) on ":memory:".PUBLIC.T
-- A: 1

-- # A constraint is only violated when it's FALSE, so UNKNOWN satisfies it.
CREATE TABLE t (a INT CHECK (a > 0), b INT);
INSERT INTO t (a) VALUES (NULL);
INSERT INTO t (b) VALUES (2);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- A: NULL B: NULL
-- A: NULL B: 2

-- # A table constraint can use any of the columns.
CREATE TABLE t (lo INT, hi INT, CHECK (lo <= hi));
INSERT INTO t (lo, hi) VALUES (1, 2), (3, 3);
INSERT INTO t (lo, hi) VALUES (5, 4);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- error 23514: violates check constraint: CHECK (LO <= HI) on ":memory:".PUBLIC.T
-- LO: 1 HI: 2
-- LO: 3 HI: 3

-- # The first constraint that's violated is reported.
CREATE TABLE t (a INT CHECK (a > 0) CHECK (a < 10), b INT, CHECK (a <> b), CHECK (b IS NOT NULL));
INSERT INTO t (a, b) VALUES (5, 6);
INSERT INTO t (a, b) VALUES (0, 6);
INSERT INTO t (a, b) VALUES (10, 6);
INSERT INTO t (a, b) VALUES (6, 6);
INSERT INTO t (a, b) VALUES (6, NULL);
INSERT INTO t (a, b) VALUES (-6, NULL);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 23514: violates check constraint: CHECK (A > 0) on ":memory:".PUBLIC.T
-- error 23514: violates check constraint: CHECK (A < 10) on ":memory:".PUBLIC.T
-- error 23514: violates check constraint: CHECK (A <> B) on ":memory:".PUBLIC.T
-- error 23514: violates check constraint: CHECK (B IS NOT NULL) on ":memory:".PUBLIC.T
-- error 23514: violates check constraint: CHECK (A > 0) on ":memory:".PUBLIC.T
-- A: 5 B: 6

-- # None of the rows are inserted if one of them violates a constraint.
CREATE TABLE t (a INT CHECK (a > 0));
INSERT INTO t (a) VALUES (1), (2), (0), (3);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- error 23514: violates check constraint: CHECK (A > 0) on ":memory:".PUBLIC.T

-- # A default is checked when it's used.
CREATE TABLE t (a INT DEFAULT 0 CHECK (a > 0), b INT);
INSERT INTO t (a, b) VALUES (1, 1);
INSERT INTO t (b) VALUES (2);
INSERT INTO t (a, b) VALUES (DEFAULT, 3);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 23514: violates check constraint: CHECK (A > 0) on ":memory:".PUBLIC.T
-- error 23514: violates check constraint: CHECK (A > 0) on ":memory:".PUBLIC.T
-- A: 1 B: 1

-- # The value is checked after it's converted to the type of the column.
CREATE TABLE t (a NUMERIC(3, 1) CHECK (a < 1.5), b CHAR(3) CHECK (b = 'ab '));
INSERT INTO t (a) VALUES (1.49);
INSERT INTO t (a) VALUES (1.51);
INSERT INTO t (b) VALUES ('ab');
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 23514: violates check constraint: CHECK (A < 1.5) on ":memory:".PUBLIC.T
-- msg: INSERT 1
-- A: 1.4 B: NULL
-- A: NULL B: ab

CREATE TABLE t (a INT, b INT, CHECK (a < b));
INSERT INTO t (a, b) VALUES (1, 5), (2, 6);
UPDATE t SET a = 5 WHERE b = 5;
UPDATE t SET a = a + 3;
SELECT * FROM t;
UPDATE t SET a = a + 1;
SELECT * FROM t;
UPDATE t SET b = NULL;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- error 23514: violates check constraint: CHECK (A < B) on ":memory:".PUBLIC.T
-- msg: UPDATE 2
-- A: 4 B: 5
-- A: 5 B: 6
-- error 23514: violates check constraint: CHECK (A < B) on ":memory:".PUBLIC.T
-- A: 4 B: 5
-- A: 5 B: 6
-- msg: UPDATE 2
-- A: 4 B: NULL
-- A: 5 B: NULL

-- # A row that moves to a new PRIMARY KEY is also checked.
CREATE TABLE t (id INT PRIMARY KEY CHECK (id < 3));
INSERT INTO t (id) VALUES (1), (2);
UPDATE t SET id = id + 1;
UPDATE t SET id = id - 1;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- error 23514: violates check constraint: CHECK (ID < 3) on ":memory:".PUBLIC.T
-- msg: UPDATE 2
-- ID: 0
-- ID: 1

-- # An error while evaluating the constraint fails the statement.
CREATE TABLE t (a INT, b INT, CHECK (a / b > 0));
INSERT INTO t (a, b) VALUES (2, 1);
INSERT INTO t (a, b) VALUES (2, 0);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 22012: division by zero
-- A: 2 B: 1

-- # The transaction continues after a constraint is violated.
CREATE TABLE t (a INT CHECK (a > 0));
START TRANSACTION;
INSERT INTO t (a) VALUES (1);
INSERT INTO t (a) VALUES (0);
INSERT INTO t (a) VALUES (2);
COMMIT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- error 23514: violates check constraint: CHECK (A > 0) on ":memory:".PUBLIC.T
-- msg: INSERT 1
-- msg: COMMIT
-- A: 1
-- A: 2

-- # A column may be qualified with its table. Like any other table name, the
-- # schema is the current schema if it's not given.
CREATE TABLE t (a INT CHECK (t.a > 0), b INT CHECK (public.t.b > 0), CHECK (":memory:".public.t.a < t.b));
INSERT INTO t (a, b) VALUES (1, 2);
INSERT INTO t (a, b) VALUES (0, 2);
INSERT INTO t (a, b) VALUES (1, 0);
INSERT INTO t (a, b) VALUES (2, 1);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 23514: violates check constraint: CHECK (T.A > 0) on ":memory:".PUBLIC.T
-- error 23514: violates check constraint: CHECK (PUBLIC.T.B > 0) on ":memory:".PUBLIC.T
-- error 23514: violates check constraint: CHECK (":memory:".PUBLIC.T.A < T.B) on ":memory:".PUBLIC.T
-- A: 1 B: 2

CREATE SCHEMA s;
CREATE TABLE s.t (a INT CHECK (t.a > 0));
CREATE TABLE s.t (a INT CHECK (s.t.a > 0), b INT CHECK (b > 0));
INSERT INTO s.t (a, b) VALUES (1, 1);
INSERT INTO s.t (a, b) VALUES (0, 1);
INSERT INTO s.t (a, b) VALUES (1, 0);
-- msg: CREATE SCHEMA 1
-- error 42P01: no such table: ":memory:".PUBLIC.T
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 23514: violates check constraint: CHECK (S.T.A > 0) on ":memory:".S.T
-- error 23514: violates check constraint: CHECK (B > 0) on ":memory:".S.T

-- # Only the columns of the table can be used.
CREATE TABLE u (b INT);
CREATE TABLE t (a INT CHECK (b > 0));
CREATE TABLE t (a INT, CHECK (b > 0));
CREATE TABLE t (a INT, CHECK (u.b > 0));
CREATE TABLE t (a INT, CHECK (u.a > 0));
CREATE TABLE t (a INT, CHECK (public.u.a > 0));
CREATE TABLE t (a INT, CHECK (x.t.a > 0));
-- msg: CREATE TABLE 1
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.B
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.B
-- error 42P01: no such table: ":memory:".PUBLIC.U
-- error 42P01: no such table: ":memory:".PUBLIC.U
-- error 42P01: no such table: ":memory:".PUBLIC.U
-- error 42P01: no such table: ":memory:".X.T

-- # A constraint on a column can only use that column.
CREATE TABLE t (a INT, b INT CHECK (a < b));
CREATE TABLE t (a INT CHECK (a > 0) NOT NULL, b INT CHECK (t.b > 0) CHECK (b < 10));
-- error 42601: syntax error: CHECK on column B cannot use column A
-- msg: CREATE TABLE 1

CREATE TABLE t (a INT CHECK (a));
CREATE TABLE t (a VARCHAR(10) CHECK (a));
-- error 42804: data type mismatch in CHECK constraint: expected BOOLEAN but got INTEGER
-- error 42804: data type mismatch in CHECK constraint: expected BOOLEAN but got CHARACTER VARYING(10)

CREATE TABLE t (a BOOLEAN CHECK (a), b BOOLEAN CHECK (b IS NOT FALSE));
INSERT INTO t (a, b) VALUES (TRUE, TRUE);
INSERT INTO t (a, b) VALUES (FALSE, TRUE);
INSERT INTO t (a, b) VALUES (TRUE, FALSE);
INSERT INTO t (a, b) VALUES (NULL, NULL);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 23514: violates check constraint: CHECK (A) on ":memory:".PUBLIC.T
-- error 23514: violates check constraint: CHECK (B IS NOT FALSE) on ":memory:".PUBLIC.T
-- msg: INSERT 1
-- A: TRUE B: TRUE
-- A: UNKNOWN B: UNKNOWN

-- # An aggregate function can't be used.
CREATE TABLE t (a INT CHECK (COUNT(*) > 0));
CREATE TABLE t (a INT CHECK (MAX(a) > 0));
CREATE TABLE t (a INT CHECK (ABS(a) > 0));
-- error 42601: syntax error: an aggregate function cannot be used in a CHECK constraint
-- error 42601: syntax error: an aggregate function cannot be used in a CHECK constraint
-- msg: CREATE TABLE 1

-- # A parameter can't be used.
/* params 1 */
CREATE TABLE t (a INT CHECK (a > ?));
-- sql: CREATE TABLE t (a INT CHECK (a > 1.0e0))
-- error 42601: syntax error: parameter ?1 cannot be used in a CHECK constraint

-- # The constraint must be deterministic.
CREATE SEQUENCE seq;
CREATE TABLE t (a INT CHECK (a > NEXT VALUE FOR seq));
CREATE TABLE t (a DATE CHECK (a < CURRENT_DATE));
CREATE TABLE t (a TIMESTAMP WITH TIME ZONE CHECK (a < CURRENT_TIMESTAMP));
CREATE TABLE t (a TIMESTAMP CHECK (a < LOCALTIMESTAMP));
CREATE TABLE t (a TIME CHECK (a < LOCALTIME));
CREATE TABLE t (a TIME WITH TIME ZONE CHECK (a < CURRENT_TIME));
CREATE TABLE t (a VARCHAR(10) CHECK (a = CURRENT_SCHEMA));
CREATE TABLE t (a VARCHAR(10) CHECK (a = CURRENT_CATALOG));
-- msg: CREATE SEQUENCE 1
-- error 42601: syntax error: NEXT VALUE FOR cannot be used in a CHECK constraint
-- error 42601: syntax error: CURRENT_DATE cannot be used in a CHECK constraint
-- error 42601: syntax error: CURRENT_TIMESTAMP(6) cannot be used in a CHECK constraint
-- error 42601: syntax error: LOCALTIMESTAMP(6) cannot be used in a CHECK constraint
-- error 42601: syntax error: LOCALTIME(0) cannot be used in a CHECK constraint
-- error 42601: syntax error: CURRENT_TIME(0) cannot be used in a CHECK constraint
-- error 42601: syntax error: CURRENT_SCHEMA cannot be used in a CHECK constraint
-- error 42601: syntax error: CURRENT_CATALOG cannot be used in a CHECK constraint

-- # A datetime without a time zone depends on the time zone of the session when
-- # it's compared with (or cast to) one with a time zone.
CREATE TABLE t (a TIMESTAMP WITH TIME ZONE, b TIMESTAMP, CHECK (a < b));
CREATE TABLE t (a TIMESTAMP WITH TIME ZONE CHECK (a < TIMESTAMP '2020-01-01 00:00:00'));
CREATE TABLE t (a TIMESTAMP WITH TIME ZONE CHECK (a BETWEEN TIMESTAMP '2020-01-01 00:00:00+00:00' AND TIMESTAMP '2021-01-01 00:00:00'));
CREATE TABLE t (a TIMESTAMP WITH TIME ZONE CHECK (a IN (TIMESTAMP '2020-01-01 00:00:00')));
CREATE TABLE t (a TIMESTAMP WITH TIME ZONE CHECK (CASE a WHEN TIMESTAMP '2020-01-01 00:00:00' THEN TRUE END));
CREATE TABLE t (a TIMESTAMP WITH TIME ZONE CHECK (NULLIF(a, TIMESTAMP '2020-01-01 00:00:00') IS NULL));
CREATE TABLE t (a TIMESTAMP CHECK (CAST(a AS TIMESTAMP WITH TIME ZONE) IS NOT NULL));
CREATE TABLE t (a TIME CHECK (CAST(a AS TIMESTAMP) IS NOT NULL));
CREATE TABLE t (a VARCHAR(30) CHECK (CAST(a AS TIME WITH TIME ZONE) IS NOT NULL));
-- error 42601: syntax error: comparing TIMESTAMP(6) WITH TIME ZONE with TIMESTAMP(6) WITHOUT TIME ZONE cannot be used in a CHECK constraint
-- error 42601: syntax error: comparing TIMESTAMP(6) WITH TIME ZONE with TIMESTAMP(0) WITHOUT TIME ZONE cannot be used in a CHECK constraint
-- error 42601: syntax error: comparing TIMESTAMP(6) WITH TIME ZONE with TIMESTAMP(0) WITHOUT TIME ZONE cannot be used in a CHECK constraint
-- error 42601: syntax error: comparing TIMESTAMP(6) WITH TIME ZONE with TIMESTAMP(0) WITHOUT TIME ZONE cannot be used in a CHECK constraint
-- error 42601: syntax error: comparing TIMESTAMP(6) WITH TIME ZONE with TIMESTAMP(0) WITHOUT TIME ZONE cannot be used in a CHECK constraint
-- error 42601: syntax error: comparing TIMESTAMP(6) WITH TIME ZONE with TIMESTAMP(0) WITHOUT TIME ZONE cannot be used in a CHECK constraint
-- error 42601: syntax error: CAST from TIMESTAMP(6) WITHOUT TIME ZONE to TIMESTAMP(6) WITH TIME ZONE cannot be used in a CHECK constraint
-- error 42601: syntax error: CAST from TIME(0) WITHOUT TIME ZONE to TIMESTAMP(6) WITHOUT TIME ZONE cannot be used in a CHECK constraint
-- error 42601: syntax error: CAST from CHARACTER VARYING(30) to TIME(0) WITH TIME ZONE cannot be used in a CHECK constraint

CREATE TABLE t (a TIMESTAMP WITH TIME ZONE CHECK (a > TIMESTAMP '2020-01-01 00:00:00+05:00'), b TIMESTAMP CHECK (CAST(b AS DATE) > DATE '2020-01-01'), c VARCHAR(30) CHECK (CAST(c AS TIMESTAMP) > TIMESTAMP '2020-01-01 00:00:00'));
INSERT INTO t (a, b, c) VALUES (TIMESTAMP '2020-01-01 00:00:00+04:00', TIMESTAMP '2020-01-02 00:00:00', '2020-01-02 00:00:00');
INSERT INTO t (a) VALUES (TIMESTAMP '2020-01-01 00:00:00+06:00');
INSERT INTO t (b) VALUES (TIMESTAMP '2020-01-01 23:00:00');
INSERT INTO t (c) VALUES ('2020-01-01 00:00:00');
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 23514: violates check constraint: CHECK (A > TIMESTAMP '2020-01-01 00:00:00+05:00') on ":memory:".PUBLIC.T
-- error 23514: violates check constraint: CHECK (CAST(B AS DATE) > DATE '2020-01-01') on ":memory:".PUBLIC.T
-- error 23514: violates check constraint: CHECK (CAST(C AS TIMESTAMP(6) WITHOUT TIME ZONE) > TIMESTAMP '2020-01-01 00:00:00') on ":memory:".PUBLIC.T

-- # The constraints are part of the table definition in the file, so they must
-- # be read back the same.
/* connection 1 */
CREATE TABLE "my table" ("a b" INT CHECK ("a b" > -1.5), "check" VARCHAR(10) CHECK ("check" <> 'it''s' AND "check" NOT LIKE '%x%'), c DOUBLE PRECISION CHECK (c BETWEEN 1.5e0 AND 2e10), d INT CHECK (d IN (1, 2, 3) OR d IS NULL), e INT, CHECK (CASE WHEN e > 0 THEN TRUE ELSE e = -1 END), CHECK (NOT (e = 5 OR e = 6)), CHECK (ABS(e) < 100 AND POSITION('z' IN LOWER("check")) = 0), CHECK (CAST(e AS VARCHAR(10)) <> '7'));
/* connection 2 */
INSERT INTO "my table" ("a b", "check", c, d, e) VALUES (1, 'a', 2.0e0, 1, 1);
INSERT INTO "my table" ("a b") VALUES (-2);
INSERT INTO "my table" ("check") VALUES ('it''s');
INSERT INTO "my table" ("check") VALUES ('axb');
INSERT INTO "my table" (c) VALUES (1e0);
INSERT INTO "my table" (d) VALUES (4);
INSERT INTO "my table" (e) VALUES (0);
INSERT INTO "my table" (e) VALUES (6);
INSERT INTO "my table" (e) VALUES (100);
INSERT INTO "my table" ("check") VALUES ('Z');
INSERT INTO "my table" (e) VALUES (7);
INSERT INTO "my table" (e) VALUES (-1);
SELECT * FROM "my table";
-- 1: msg: CREATE TABLE 1
-- 2: msg: INSERT 1
-- 2: error 23514: violates check constraint: CHECK ("a b" > -1.5) on "test".PUBLIC."my table"
-- 2: error 23514: violates check constraint: CHECK ("check" <> 'it''s' AND "check" NOT LIKE '%x%') on "test".PUBLIC."my table"
-- 2: error 23514: violates check constraint: CHECK ("check" <> 'it''s' AND "check" NOT LIKE '%x%') on "test".PUBLIC."my table"
-- 2: error 23514: violates check constraint: CHECK (C BETWEEN 1.5e0 AND 2e+10) on "test".PUBLIC."my table"
-- 2: error 23514: violates check constraint: CHECK (D IN (1, 2, 3) OR D IS NULL) on "test".PUBLIC."my table"
-- 2: error 23514: violates check constraint: CHECK (CASE WHEN E > 0 THEN TRUE ELSE E = -1 END) on "test".PUBLIC."my table"
-- 2: error 23514: violates check constraint: CHECK (NOT (E = 5 OR E = 6)) on "test".PUBLIC."my table"
-- 2: error 23514: violates check constraint: CHECK (ABS(E) < 100 AND POSITION('z' IN LOWER("check")) = 0) on "test".PUBLIC."my table"
-- 2: error 23514: violates check constraint: CHECK (ABS(E) < 100 AND POSITION('z' IN LOWER("check")) = 0) on "test".PUBLIC."my table"
-- 2: error 23514: violates check constraint: CHECK (CAST(E AS CHARACTER VARYING(10)) <> '7') on "test".PUBLIC."my table"
-- 2: msg: INSERT 1
-- 2: a b: 1 check: a C: 2e0 D: 1 E: 1
-- 2: a b: NULL check: NULL C: NULL D: NULL E: -1

-- # The constraints are dumped as table constraints, so that loading the dump
-- # gives the same table (and the same dump). Strings and names with
-- # characters that end a statement or start a comment are still one statement.
CREATE SCHEMA s;
CREATE TABLE s."my;table" ("a""b" INT CHECK ("a""b" > -1.5) NOT NULL, c VARCHAR(10) DEFAULT 'x' CHECK (c <> ';' AND c NOT LIKE '%--%'), d DOUBLE PRECISION, PRIMARY KEY ("a""b"), CHECK (NOT (d = 1e0 OR d BETWEEN 2e10 AND 3e10)), CHECK (POSITION('z' IN c) = 0 AND s."my;table".d IS NOT NULL));
INSERT INTO s."my;table" ("a""b", c, d) VALUES (1, 'a', 2.0e0);
/* out */
/* in */
/* out */
INSERT INTO s."my;table" ("a""b", d) VALUES (2, 2e0);
INSERT INTO s."my;table" ("a""b", c, d) VALUES (3, ';', 2e0);
INSERT INTO s."my;table" ("a""b", c, d) VALUES (3, 'a--b', 2e0);
INSERT INTO s."my;table" ("a""b", d) VALUES (-2, 2e0);
INSERT INTO s."my;table" ("a""b", d) VALUES (3, 1e0);
INSERT INTO s."my;table" ("a""b", d) VALUES (3, 2.5e10);
INSERT INTO s."my;table" ("a""b", c, d) VALUES (3, 'z', 2e0);
INSERT INTO s."my;table" ("a""b") VALUES (3);
SELECT * FROM s."my;table";
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- out: CREATE SCHEMA "S";
-- out: CREATE TABLE "S"."my;table" (
-- out:   "a""b" INTEGER NOT NULL,
-- out:   "C" CHARACTER VARYING(10) DEFAULT 'x',
-- out:   "D" DOUBLE PRECISION,
-- out:   PRIMARY KEY ("a""b"),
-- out:   CHECK ("a""b" > -1.5),
-- out:   CHECK (C <> ';' AND C NOT LIKE '%--%'),
-- out:   CHECK (NOT (D = 1e0 OR D BETWEEN 2e+10 AND 3e+10)),
-- out:   CHECK (POSITION('z' IN C) = 0 AND S."my;table".D IS NOT NULL)
-- out: );
-- out: INSERT INTO "S"."my;table" ("a""b", "C", "D") VALUES (1, 'a', 2.0e0);
-- out: CREATE SCHEMA "S";
-- out: CREATE TABLE "S"."my;table" (
-- out:   "a""b" INTEGER NOT NULL,
-- out:   "C" CHARACTER VARYING(10) DEFAULT 'x',
-- out:   "D" DOUBLE PRECISION,
-- out:   PRIMARY KEY ("a""b"),
-- out:   CHECK ("a""b" > -1.5),
-- out:   CHECK (C <> ';' AND C NOT LIKE '%--%'),
-- out:   CHECK (NOT (D = 1e0 OR D BETWEEN 2e+10 AND 3e+10)),
-- out:   CHECK (POSITION('z' IN C) = 0 AND S."my;table".D IS NOT NULL)
-- out: );
-- out: INSERT INTO "S"."my;table" ("a""b", "C", "D") VALUES (1, 'a', 2.0e0);
-- msg: INSERT 1
-- error 23514: violates check constraint: CHECK (C <> ';' AND C NOT LIKE '%--%') on ":memory:".S."my;table"
-- error 23514: violates check constraint: CHECK (C <> ';' AND C NOT LIKE '%--%') on ":memory:".S."my;table"
-- error 23514: violates check constraint: CHECK ("a""b" > -1.5) on ":memory:".S."my;table"
-- error 23514: violates check constraint: CHECK (NOT (D = 1e0 OR D BETWEEN 2e+10 AND 3e+10)) on ":memory:".S."my;table"
-- error 23514: violates check constraint: CHECK (NOT (D = 1e0 OR D BETWEEN 2e+10 AND 3e+10)) on ":memory:".S."my;table"
-- error 23514: violates check constraint: CHECK (POSITION('z' IN C) = 0 AND S."my;table".D IS NOT NULL) on ":memory:".S."my;table"
-- error 23514: violates check constraint: CHECK (POSITION('z' IN C) = 0 AND S."my;table".D IS NOT NULL) on ":memory:".S."my;table"
-- a"b: 1 C: a D: 2e0
-- a"b: 2 C: x D: 2e0
