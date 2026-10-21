-- # The "out" directive dumps the database like "vsql out", and "in" replaces
-- # it with a new database loaded from the dump, like "vsql in". Each test
-- # changes the data in a different way, and the restored database must be the
-- # same.
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1), (2);
/* out */
/* in */
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- out: CREATE TABLE "PUBLIC"."T" (
-- out:   "X" INTEGER
-- out: );
-- out: INSERT INTO "PUBLIC"."T" ("X") VALUES (1);
-- out: INSERT INTO "PUBLIC"."T" ("X") VALUES (2);
-- X: 1
-- X: 2

-- # An empty database has nothing to dump.
/* out */
/* in */
/* out */
CREATE TABLE t (x INT);
-- msg: CREATE TABLE 1

-- # A table without rows.
CREATE TABLE t (x INT);
/* out */
/* in */
SELECT * FROM t;
INSERT INTO t (x) VALUES (1);
-- msg: CREATE TABLE 1
-- out: CREATE TABLE "PUBLIC"."T" (
-- out:   "X" INTEGER
-- out: );
-- msg: INSERT 1

-- # Schemas, then the sequences and tables in each one, are in order of their
-- # names, so that the dump is the same each time.
CREATE SCHEMA z;
CREATE SCHEMA b;
CREATE TABLE z.t2 (x INT);
CREATE TABLE z.t1 (x INT);
CREATE SEQUENCE z.s2;
CREATE SEQUENCE z.s1;
CREATE TABLE b.t (x INT);
/* out */
-- msg: CREATE SCHEMA 1
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: CREATE SEQUENCE 1
-- msg: CREATE SEQUENCE 1
-- msg: CREATE TABLE 1
-- out: CREATE SCHEMA "B";
-- out: CREATE TABLE "B"."T" (
-- out:   "X" INTEGER
-- out: );
-- out: CREATE SCHEMA "Z";
-- out: CREATE SEQUENCE "Z"."S1" START WITH 1;
-- out: CREATE SEQUENCE "Z"."S2" START WITH 1;
-- out: CREATE TABLE "Z"."T1" (
-- out:   "X" INTEGER
-- out: );
-- out: CREATE TABLE "Z"."T2" (
-- out:   "X" INTEGER
-- out: );

-- # Every type keeps its type and value, including NULL.
CREATE TABLE t (
  a SMALLINT, b INTEGER, c BIGINT, d REAL, e DOUBLE PRECISION, f NUMERIC(10, 2),
  g DECIMAL(5, 1), h NUMERIC, i DECIMAL, j VARCHAR(20), k CHAR(5), l BOOLEAN,
  m DATE, n TIME(3), o TIME WITH TIME ZONE, p TIMESTAMP(6),
  q TIMESTAMP WITH TIME ZONE
);
INSERT INTO t (a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q) VALUES (-32768, -2147483648, -9223372036854775808, 1.1e0, 0.1e0 + 0.2e0, 12345678.91, -1234.5, 15, 7, 'it''s', 'ab', TRUE, DATE '2022-06-30', TIME '01:02:03.456', TIME '01:02:03+05:00', TIMESTAMP '2022-06-30 21:47:32.123456', TIMESTAMP '2022-06-30 21:47:32+05:00');
INSERT INTO t (a, b, c, d, e, l) VALUES (32767, 2147483647, 9223372036854775807, -3.4028235e38, 5e-324, FALSE);
INSERT INTO t (a) VALUES (NULL);
/* out */
/* in */
/* types */
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- out: CREATE TABLE "PUBLIC"."T" (
-- out:   "A" SMALLINT,
-- out:   "B" INTEGER,
-- out:   "C" BIGINT,
-- out:   "D" REAL,
-- out:   "E" DOUBLE PRECISION,
-- out:   "F" NUMERIC(10, 2),
-- out:   "G" DECIMAL(5, 1),
-- out:   "H" NUMERIC,
-- out:   "I" DECIMAL,
-- out:   "J" CHARACTER VARYING(20),
-- out:   "K" CHARACTER(5),
-- out:   "L" BOOLEAN,
-- out:   "M" DATE,
-- out:   "N" TIME(3) WITHOUT TIME ZONE,
-- out:   "O" TIME(0) WITH TIME ZONE,
-- out:   "P" TIMESTAMP(6) WITHOUT TIME ZONE,
-- out:   "Q" TIMESTAMP(6) WITH TIME ZONE
-- out: );
-- out: INSERT INTO "PUBLIC"."T" ("A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q") VALUES (-32768, -2147483648, -9223372036854775808, 1.1e0, 0.30000000000000004e0, 12345678.91, -1234.5, 15, 7, 'it''s', 'ab   ', TRUE, DATE '2022-06-30', TIME '01:02:03.456', TIME '01:02:03+05:00', TIMESTAMP '2022-06-30 21:47:32.123456', TIMESTAMP '2022-06-30 21:47:32.000000+05:00');
-- out: INSERT INTO "PUBLIC"."T" ("A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q") VALUES (32767, 2147483647, 9223372036854775807, -3.4028235e+38, 5e-324, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, NULL, NULL, NULL, NULL, NULL);
-- out: INSERT INTO "PUBLIC"."T" ("A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q") VALUES (NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
-- A: -32768 (SMALLINT) B: -2147483648 (INTEGER) C: -9223372036854775808 (BIGINT) D: 1.1e0 (REAL) E: 0.3e0 (DOUBLE PRECISION) F: 12345678.91 (NUMERIC(10, 2)) G: -1234.5 (DECIMAL(5, 1)) H: 15 (NUMERIC) I: 7 (DECIMAL) J: it's (CHARACTER VARYING(20)) K: ab    (CHARACTER(5)) L: TRUE (BOOLEAN) M: 2022-06-30 (DATE) N: 01:02:03.456 (TIME(3) WITHOUT TIME ZONE) O: 01:02:03+0500 (TIME(0) WITH TIME ZONE) P: 2022-06-30T21:47:32.123456 (TIMESTAMP(6) WITHOUT TIME ZONE) Q: 2022-06-30T21:47:32.000000+0500 (TIMESTAMP(6) WITH TIME ZONE)
-- A: 32767 (SMALLINT) B: 2147483647 (INTEGER) C: 9223372036854775807 (BIGINT) D: -3.40282e+38 (REAL) E: 4.94065645841e-324 (DOUBLE PRECISION) F: NULL (NUMERIC(10, 2)) G: NULL (DECIMAL(5, 1)) H: NULL (NUMERIC) I: NULL (DECIMAL) J: NULL (CHARACTER VARYING(20)) K: NULL (CHARACTER(5)) L: FALSE (BOOLEAN) M: NULL (DATE) N: NULL (TIME(3) WITHOUT TIME ZONE) O: NULL (TIME(0) WITH TIME ZONE) P: NULL (TIMESTAMP(6) WITHOUT TIME ZONE) Q: NULL (TIMESTAMP(6) WITH TIME ZONE)
-- A: NULL (SMALLINT) B: NULL (INTEGER) C: NULL (BIGINT) D: NULL (REAL) E: NULL (DOUBLE PRECISION) F: NULL (NUMERIC(10, 2)) G: NULL (DECIMAL(5, 1)) H: NULL (NUMERIC) I: NULL (DECIMAL) J: NULL (CHARACTER VARYING(20)) K: NULL (CHARACTER(5)) L: UNKNOWN (BOOLEAN) M: NULL (DATE) N: NULL (TIME(3) WITHOUT TIME ZONE) O: NULL (TIME(0) WITH TIME ZONE) P: NULL (TIMESTAMP(6) WITHOUT TIME ZONE) Q: NULL (TIMESTAMP(6) WITH TIME ZONE)

-- # Floating point values come back exactly the same.
CREATE TABLE t (d REAL, e DOUBLE PRECISION);
INSERT INTO t (d, e) VALUES (1.17549435e-38, 2.2250738585072014e-308), (1.4e-45, 4.9e-324), (3.4028235e38, 1.7976931348623157e308), (-0.0e0, 123456789.123456789e0);
/* out */
/* in */
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 4
-- out: CREATE TABLE "PUBLIC"."T" (
-- out:   "D" REAL,
-- out:   "E" DOUBLE PRECISION
-- out: );
-- out: INSERT INTO "PUBLIC"."T" ("D", "E") VALUES (1.1754944e-38, 2.2250738585072014e-308);
-- out: INSERT INTO "PUBLIC"."T" ("D", "E") VALUES (1e-45, 5e-324);
-- out: INSERT INTO "PUBLIC"."T" ("D", "E") VALUES (3.4028235e+38, 1.7976931348623157e+308);
-- out: INSERT INTO "PUBLIC"."T" ("D", "E") VALUES (-0.0e0, 1.2345678912345679e+08);
-- D: 1.17549e-38 E: 2.22507385851e-308
-- D: 1.4013e-45 E: 4.94065645841e-324
-- D: 3.40282e+38 E: 1.79769313486e+308
-- D: -0e0 E: 1.23456789123e+08

-- # Strings with quotes, semicolons and other characters that need care.
CREATE TABLE t (s VARCHAR(400));
INSERT INTO t (s) VALUES ('it''s'), ('a; b'), (''), ('"quoted"'), ('caf<U+00E9>'), ('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'), ('  spaces  ');
/* out */
/* in */
SELECT CHAR_LENGTH(s) AS len, s FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 7
-- out: CREATE TABLE "PUBLIC"."T" (
-- out:   "S" CHARACTER VARYING(400)
-- out: );
-- out: INSERT INTO "PUBLIC"."T" ("S") VALUES ('it''s');
-- out: INSERT INTO "PUBLIC"."T" ("S") VALUES ('a; b');
-- out: INSERT INTO "PUBLIC"."T" ("S") VALUES ('');
-- out: INSERT INTO "PUBLIC"."T" ("S") VALUES ('"quoted"');
-- out: INSERT INTO "PUBLIC"."T" ("S") VALUES ('café');
-- out: INSERT INTO "PUBLIC"."T" ("S") VALUES ('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
-- out: INSERT INTO "PUBLIC"."T" ("S") VALUES ('  spaces  ');
-- LEN: 4 S: it's
-- LEN: 4 S: a; b
-- LEN: 0 S:
-- LEN: 8 S: "quoted"
-- LEN: 4 S: café
-- LEN: 300 S: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- LEN: 10 S:   spaces

-- # Names that need to be quoted, in a schema other than PUBLIC.
CREATE SCHEMA "Mixed Case";
CREATE TABLE "Mixed Case"."Table" ("id" INT NOT NULL, "Value" VARCHAR(10), "select" INT, PRIMARY KEY ("id"));
INSERT INTO "Mixed Case"."Table" ("id", "Value", "select") VALUES (1, 'x', 2);
/* out */
/* in */
SELECT * FROM "Mixed Case"."Table";
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- out: CREATE SCHEMA "Mixed Case";
-- out: CREATE TABLE "Mixed Case"."Table" (
-- out:   "id" INTEGER NOT NULL,
-- out:   "Value" CHARACTER VARYING(10),
-- out:   "select" INTEGER,
-- out:   PRIMARY KEY ("id")
-- out: );
-- out: INSERT INTO "Mixed Case"."Table" ("id", "Value", "select") VALUES (1, 'x', 2);
-- id: 1 Value: x select: 2

-- # The rows after an UPDATE and DELETE, including a changed PRIMARY KEY.
CREATE TABLE t (id INT NOT NULL, x VARCHAR(10), PRIMARY KEY (id));
INSERT INTO t (id, x) VALUES (1, 'a'), (2, 'b'), (3, 'c'), (4, 'd');
UPDATE t SET x = 'changed' WHERE id = 2;
UPDATE t SET id = 30 WHERE id = 3;
DELETE FROM t WHERE id = 4;
/* out */
/* in */
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 4
-- msg: UPDATE 1
-- msg: UPDATE 1
-- msg: DELETE 1
-- out: CREATE TABLE "PUBLIC"."T" (
-- out:   "ID" INTEGER NOT NULL,
-- out:   "X" CHARACTER VARYING(10),
-- out:   PRIMARY KEY ("ID")
-- out: );
-- out: INSERT INTO "PUBLIC"."T" ("ID", "X") VALUES (1, 'a');
-- out: INSERT INTO "PUBLIC"."T" ("ID", "X") VALUES (2, 'changed');
-- out: INSERT INTO "PUBLIC"."T" ("ID", "X") VALUES (30, 'c');
-- ID: 1 X: a
-- ID: 2 X: changed
-- ID: 30 X: c

-- # Large values are stored across several pages.
CREATE TABLE t (id INT NOT NULL, s VARCHAR(1000), PRIMARY KEY (id));
INSERT INTO t (id, s) VALUES (1, 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
UPDATE t SET s = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' WHERE id = 1;
INSERT INTO t (id, s) VALUES (2, 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
/* out */
/* in */
SELECT id, CHAR_LENGTH(s) AS len FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: UPDATE 1
-- msg: INSERT 1
-- out: CREATE TABLE "PUBLIC"."T" (
-- out:   "ID" INTEGER NOT NULL,
-- out:   "S" CHARACTER VARYING(1000),
-- out:   PRIMARY KEY ("ID")
-- out: );
-- out: INSERT INTO "PUBLIC"."T" ("ID", "S") VALUES (1, 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
-- out: INSERT INTO "PUBLIC"."T" ("ID", "S") VALUES (2, 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
-- ID: 1 LEN: 300
-- ID: 2 LEN: 900

-- # Dropped tables, schemas and sequences are gone.
CREATE SCHEMA s;
CREATE TABLE s.t (x INT);
CREATE TABLE t1 (x INT);
CREATE TABLE t2 (x INT);
INSERT INTO t1 (x) VALUES (1);
CREATE SEQUENCE seq1;
CREATE SEQUENCE seq2;
DROP TABLE s.t;
DROP SCHEMA s RESTRICT;
DROP TABLE t1;
DROP SEQUENCE seq1;
/* out */
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: CREATE SEQUENCE 1
-- msg: CREATE SEQUENCE 1
-- msg: DROP TABLE 1
-- msg: DROP SCHEMA 1
-- msg: DROP TABLE 1
-- msg: DROP SEQUENCE 1
-- out: CREATE SEQUENCE "PUBLIC"."SEQ2" START WITH 1;
-- out: CREATE TABLE "PUBLIC"."T2" (
-- out:   "X" INTEGER
-- out: );

-- # Sequences continue from the same place.
CREATE SEQUENCE unused START WITH 10;
CREATE SEQUENCE moved INCREMENT BY 5;
VALUES NEXT VALUE FOR moved;
CREATE SEQUENCE down START WITH -5 INCREMENT BY -1;
VALUES NEXT VALUE FOR down;
CREATE SEQUENCE restarted;
ALTER SEQUENCE restarted RESTART WITH 100;
CREATE SEQUENCE altered;
ALTER SEQUENCE altered INCREMENT BY 10 MINVALUE -100 MAXVALUE 1000;
VALUES NEXT VALUE FOR altered;
CREATE SEQUENCE past_max START WITH 1 MAXVALUE 2;
VALUES NEXT VALUE FOR past_max, NEXT VALUE FOR past_max;
CREATE SEQUENCE past_bigint START WITH 9223372036854775807;
VALUES NEXT VALUE FOR past_bigint;
CREATE SEQUENCE cycles START WITH 1 MAXVALUE 2 CYCLE;
VALUES NEXT VALUE FOR cycles, NEXT VALUE FOR cycles;
/* out */
/* in */
VALUES NEXT VALUE FOR unused;
VALUES NEXT VALUE FOR moved;
VALUES NEXT VALUE FOR down;
VALUES NEXT VALUE FOR restarted;
VALUES NEXT VALUE FOR altered;
VALUES NEXT VALUE FOR past_max;
VALUES NEXT VALUE FOR past_bigint;
VALUES NEXT VALUE FOR cycles;
-- msg: CREATE SEQUENCE 1
-- msg: CREATE SEQUENCE 1
-- COL1: 1
-- msg: CREATE SEQUENCE 1
-- COL1: -5
-- msg: CREATE SEQUENCE 1
-- msg: ALTER SEQUENCE 1
-- msg: CREATE SEQUENCE 1
-- msg: ALTER SEQUENCE 1
-- COL1: 1
-- msg: CREATE SEQUENCE 1
-- COL1: 1
-- COL1: 2
-- msg: CREATE SEQUENCE 1
-- COL1: 9223372036854775807
-- msg: CREATE SEQUENCE 1
-- COL1: 1
-- COL1: 2
-- out: CREATE SEQUENCE "PUBLIC"."ALTERED" START WITH 1 INCREMENT BY 10 MINVALUE -100 MAXVALUE 1000;
-- out: ALTER SEQUENCE "PUBLIC"."ALTERED" RESTART WITH 11;
-- out: CREATE SEQUENCE "PUBLIC"."CYCLES" START WITH 1 MAXVALUE 2 CYCLE;
-- out: ALTER SEQUENCE "PUBLIC"."CYCLES" RESTART WITH 2;
-- out: VALUES NEXT VALUE FOR "PUBLIC"."CYCLES";
-- out: CREATE SEQUENCE "PUBLIC"."DOWN" START WITH -5 INCREMENT BY -1;
-- out: ALTER SEQUENCE "PUBLIC"."DOWN" RESTART WITH -6;
-- out: CREATE SEQUENCE "PUBLIC"."MOVED" START WITH 1 INCREMENT BY 5;
-- out: ALTER SEQUENCE "PUBLIC"."MOVED" RESTART WITH 6;
-- out: CREATE SEQUENCE "PUBLIC"."PAST_BIGINT" START WITH 9223372036854775807;
-- out: ALTER SEQUENCE "PUBLIC"."PAST_BIGINT" RESTART WITH 9223372036854775807;
-- out: VALUES NEXT VALUE FOR "PUBLIC"."PAST_BIGINT";
-- out: CREATE SEQUENCE "PUBLIC"."PAST_MAX" START WITH 1 MAXVALUE 2;
-- out: ALTER SEQUENCE "PUBLIC"."PAST_MAX" RESTART WITH 2;
-- out: VALUES NEXT VALUE FOR "PUBLIC"."PAST_MAX";
-- out: CREATE SEQUENCE "PUBLIC"."RESTARTED" START WITH 1;
-- out: ALTER SEQUENCE "PUBLIC"."RESTARTED" RESTART WITH 100;
-- out: CREATE SEQUENCE "PUBLIC"."UNUSED" START WITH 10;
-- COL1: 10
-- COL1: 6
-- COL1: -6
-- COL1: 100
-- COL1: 11
-- error 2200H: sequence generator limit exceeded: PUBLIC.PAST_MAX
-- error 2200H: sequence generator limit exceeded: PUBLIC.PAST_BIGINT
-- COL1: 1

-- # A sequence used by a table.
CREATE SEQUENCE ids;
CREATE TABLE t (id INT NOT NULL, PRIMARY KEY (id));
INSERT INTO t (id) VALUES (NEXT VALUE FOR ids);
INSERT INTO t (id) VALUES (NEXT VALUE FOR ids);
/* out */
/* in */
INSERT INTO t (id) VALUES (NEXT VALUE FOR ids);
SELECT * FROM t;
-- msg: CREATE SEQUENCE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- out: CREATE SEQUENCE "PUBLIC"."IDS" START WITH 1;
-- out: ALTER SEQUENCE "PUBLIC"."IDS" RESTART WITH 3;
-- out: CREATE TABLE "PUBLIC"."T" (
-- out:   "ID" INTEGER NOT NULL,
-- out:   PRIMARY KEY ("ID")
-- out: );
-- out: INSERT INTO "PUBLIC"."T" ("ID") VALUES (1);
-- out: INSERT INTO "PUBLIC"."T" ("ID") VALUES (2);
-- msg: INSERT 1
-- ID: 1
-- ID: 2
-- ID: 3

-- # A rolled back transaction isn't dumped, and a failed statement has no
-- # effect.
CREATE TABLE t (x INT NOT NULL);
INSERT INTO t (x) VALUES (1);
START TRANSACTION;
INSERT INTO t (x) VALUES (2);
CREATE TABLE t2 (y INT);
ROLLBACK;
START TRANSACTION;
INSERT INTO t (x) VALUES (3);
COMMIT;
INSERT INTO t (x) VALUES (NULL);
/* out */
/* in */
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: CREATE TABLE 1
-- msg: ROLLBACK
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: COMMIT
-- error 23502: violates non-null constraint: column X
-- out: CREATE TABLE "PUBLIC"."T" (
-- out:   "X" INTEGER NOT NULL
-- out: );
-- out: INSERT INTO "PUBLIC"."T" ("X") VALUES (1);
-- out: INSERT INTO "PUBLIC"."T" ("X") VALUES (3);
-- X: 1
-- X: 3

-- # Inside a transaction, the dump has the changes of the transaction.
CREATE TABLE t (x INT);
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
/* out */
/* in */
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- out: CREATE TABLE "PUBLIC"."T" (
-- out:   "X" INTEGER
-- out: );
-- out: INSERT INTO "PUBLIC"."T" ("X") VALUES (1);
-- X: 1

-- # Constraints are kept.
CREATE TABLE t (id INT NOT NULL, x INT NOT NULL, PRIMARY KEY (id));
INSERT INTO t (id, x) VALUES (1, 2);
/* out */
/* in */
INSERT INTO t (id, x) VALUES (1, 3);
INSERT INTO t (id, x) VALUES (2, NULL);
INSERT INTO t (id, x) VALUES (2, 3);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- out: CREATE TABLE "PUBLIC"."T" (
-- out:   "ID" INTEGER NOT NULL,
-- out:   "X" INTEGER NOT NULL,
-- out:   PRIMARY KEY ("ID")
-- out: );
-- out: INSERT INTO "PUBLIC"."T" ("ID", "X") VALUES (1, 2);
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T
-- error 23502: violates non-null constraint: column X
-- msg: INSERT 1
-- ID: 1 X: 2
-- ID: 2 X: 3

-- # A PRIMARY KEY of more than one column.
CREATE TABLE t (a INT NOT NULL, b INT NOT NULL, c INT, PRIMARY KEY (a, b));
INSERT INTO t (a, b, c) VALUES (1, 1, 1), (1, 2, 2), (2, 1, 3);
/* out */
/* in */
INSERT INTO t (a, b, c) VALUES (1, 2, 4);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- out: CREATE TABLE "PUBLIC"."T" (
-- out:   "A" INTEGER NOT NULL,
-- out:   "B" INTEGER NOT NULL,
-- out:   "C" INTEGER,
-- out:   PRIMARY KEY ("A", "B")
-- out: );
-- out: INSERT INTO "PUBLIC"."T" ("A", "B", "C") VALUES (1, 1, 1);
-- out: INSERT INTO "PUBLIC"."T" ("A", "B", "C") VALUES (1, 2, 2);
-- out: INSERT INTO "PUBLIC"."T" ("A", "B", "C") VALUES (2, 1, 3);
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T
-- A: 1 B: 1 C: 1
-- A: 1 B: 2 C: 2
-- A: 2 B: 1 C: 3

-- # Dumping a restored database gives the same dump.
CREATE SCHEMA s;
CREATE TABLE s.t (x INT, y VARCHAR(10));
INSERT INTO s.t (x, y) VALUES (1, 'a'), (NULL, NULL);
CREATE SEQUENCE s.seq START WITH 5;
VALUES NEXT VALUE FOR s.seq;
/* out */
/* in */
/* out */
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: CREATE SEQUENCE 1
-- COL1: 5
-- out: CREATE SCHEMA "S";
-- out: CREATE SEQUENCE "S"."SEQ" START WITH 5;
-- out: ALTER SEQUENCE "S"."SEQ" RESTART WITH 6;
-- out: CREATE TABLE "S"."T" (
-- out:   "X" INTEGER,
-- out:   "Y" CHARACTER VARYING(10)
-- out: );
-- out: INSERT INTO "S"."T" ("X", "Y") VALUES (1, 'a');
-- out: INSERT INTO "S"."T" ("X", "Y") VALUES (NULL, NULL);
-- out: CREATE SCHEMA "S";
-- out: CREATE SEQUENCE "S"."SEQ" START WITH 5;
-- out: ALTER SEQUENCE "S"."SEQ" RESTART WITH 6;
-- out: CREATE TABLE "S"."T" (
-- out:   "X" INTEGER,
-- out:   "Y" CHARACTER VARYING(10)
-- out: );
-- out: INSERT INTO "S"."T" ("X", "Y") VALUES (1, 'a');
-- out: INSERT INTO "S"."T" ("X", "Y") VALUES (NULL, NULL);
