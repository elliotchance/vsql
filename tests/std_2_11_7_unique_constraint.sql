CREATE TABLE t (id INT NOT NULL, u INT NOT NULL UNIQUE);
INSERT INTO t (id, u) VALUES (1, 10);
INSERT INTO t (id, u) VALUES (2, 20);
INSERT INTO t (id, u) VALUES (3, 10);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- error 23505: violates unique constraint: UNIQUE (U) on ":memory:".PUBLIC.T
-- ID: 1 U: 10
-- ID: 2 U: 20

-- # A UNIQUE of more than one column only prevents rows that have the same
-- # value for all of them.
CREATE TABLE t (a INT NOT NULL, b INT NOT NULL, UNIQUE (a, b));
INSERT INTO t (a, b) VALUES (1, 1);
INSERT INTO t (a, b) VALUES (1, 2);
INSERT INTO t (a, b) VALUES (2, 1);
INSERT INTO t (a, b) VALUES (1, 1);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- error 23505: violates unique constraint: UNIQUE (A, B) on ":memory:".PUBLIC.T
-- A: 1 B: 1
-- A: 1 B: 2
-- A: 2 B: 1

-- # A row with a NULL in any of the columns never conflicts.
CREATE TABLE t (a INT, b INT, UNIQUE (a, b), c INT UNIQUE);
INSERT INTO t (a, b, c) VALUES (1, NULL, NULL);
INSERT INTO t (a, b, c) VALUES (1, NULL, NULL);
INSERT INTO t (a, b, c) VALUES (NULL, NULL, 1);
INSERT INTO t (a, b, c) VALUES (NULL, NULL, 1);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- error 23505: violates unique constraint: UNIQUE (C) on ":memory:".PUBLIC.T
-- A: 1 B: NULL C: NULL
-- A: 1 B: NULL C: NULL
-- A: NULL B: NULL C: 1

-- # Values that are equal are the same, like a PRIMARY KEY.
CREATE TABLE t (n NUMERIC(5, 2) UNIQUE, s VARCHAR(10) UNIQUE, ts TIMESTAMP WITH TIME ZONE UNIQUE);
INSERT INTO t (n) VALUES (1.5);
INSERT INTO t (n) VALUES (1.50);
INSERT INTO t (s) VALUES ('a');
INSERT INTO t (s) VALUES ('a ');
INSERT INTO t (ts) VALUES (TIMESTAMP '2020-01-01 12:00:00+05:00');
INSERT INTO t (ts) VALUES (TIMESTAMP '2020-01-01 07:00:00+00:00');
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 23505: violates unique constraint: UNIQUE (N) on ":memory:".PUBLIC.T
-- msg: INSERT 1
-- error 23505: violates unique constraint: UNIQUE (S) on ":memory:".PUBLIC.T
-- msg: INSERT 1
-- error 23505: violates unique constraint: UNIQUE (TS) on ":memory:".PUBLIC.T
-- N: 1.50 S: NULL TS: NULL
-- N: NULL S: a TS: NULL
-- N: NULL S: NULL TS: 2020-01-01T12:00:00.000000+0500

-- # Two rows in the same INSERT can't have the same value, and none of the rows
-- # are inserted.
CREATE TABLE t (u INT UNIQUE);
INSERT INTO t (u) VALUES (1);
INSERT INTO t (u) VALUES (2), (3), (2);
INSERT INTO t (u) VALUES (4), (1);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 23505: violates unique constraint: UNIQUE (U) on ":memory:".PUBLIC.T
-- error 23505: violates unique constraint: UNIQUE (U) on ":memory:".PUBLIC.T
-- U: 1

-- # The constraint is checked once all of the rows have been updated, so the
-- # values can be shifted or swapped.
CREATE TABLE t (id INT PRIMARY KEY, u INT UNIQUE);
INSERT INTO t (id, u) VALUES (1, 1), (2, 2), (3, 3);
UPDATE t SET u = u + 1;
SELECT * FROM t;
UPDATE t SET u = CASE WHEN u = 2 THEN 4 WHEN u = 4 THEN 2 ELSE u END;
SELECT * FROM t;
UPDATE t SET u = 3 WHERE id = 1;
UPDATE t SET u = 5;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- msg: UPDATE 3
-- ID: 1 U: 2
-- ID: 2 U: 3
-- ID: 3 U: 4
-- msg: UPDATE 3
-- ID: 1 U: 4
-- ID: 2 U: 3
-- ID: 3 U: 2
-- error 23505: violates unique constraint: UNIQUE (U) on ":memory:".PUBLIC.T
-- error 23505: violates unique constraint: UNIQUE (U) on ":memory:".PUBLIC.T
-- ID: 1 U: 4
-- ID: 2 U: 3
-- ID: 3 U: 2

-- # A row that gets a new PRIMARY KEY is still the same row.
CREATE TABLE t (id INT PRIMARY KEY, u INT UNIQUE);
INSERT INTO t (id, u) VALUES (1, 1), (2, 2);
UPDATE t SET id = id + 10;
UPDATE t SET id = 1, u = 2 WHERE id = 11;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: UPDATE 2
-- error 23505: violates unique constraint: UNIQUE (U) on ":memory:".PUBLIC.T
-- ID: 11 U: 1
-- ID: 12 U: 2

-- # A table can have more than one UNIQUE, as well as a PRIMARY KEY.
CREATE TABLE t (id INT, a INT UNIQUE, b INT, PRIMARY KEY (id), UNIQUE (b));
INSERT INTO t (id, a, b) VALUES (1, 1, 1);
INSERT INTO t (id, a, b) VALUES (2, 1, 2);
INSERT INTO t (id, a, b) VALUES (2, 2, 1);
INSERT INTO t (id, a, b) VALUES (1, 2, 2);
INSERT INTO t (id, a, b) VALUES (2, 2, 2);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 23505: violates unique constraint: UNIQUE (A) on ":memory:".PUBLIC.T
-- error 23505: violates unique constraint: UNIQUE (B) on ":memory:".PUBLIC.T
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T
-- msg: INSERT 1
-- ID: 1 A: 1 B: 1
-- ID: 2 A: 2 B: 2

-- # A deleted value can be used again, also in the same transaction.
CREATE TABLE t (u INT UNIQUE);
INSERT INTO t (u) VALUES (1), (2);
DELETE FROM t WHERE u = 1;
INSERT INTO t (u) VALUES (1);
START TRANSACTION;
DELETE FROM t WHERE u = 2;
INSERT INTO t (u) VALUES (2);
INSERT INTO t (u) VALUES (2);
COMMIT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: DELETE 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: DELETE 1
-- msg: INSERT 1
-- error 23505: violates unique constraint: UNIQUE (U) on ":memory:".PUBLIC.T
-- msg: COMMIT
-- U: 1
-- U: 2

-- # A row that's not changed by an UPDATE isn't checked.
CREATE TABLE t (u INT UNIQUE);
INSERT INTO t (u) VALUES (1);
UPDATE t SET u = 1;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: UPDATE 1

-- # Each column in a UNIQUE must exist, and only appear once.
CREATE TABLE t (a INT, UNIQUE (b));
CREATE TABLE t (a INT, UNIQUE (a, a));
-- error 42601: syntax error: unknown column B in UNIQUE
-- error 42601: syntax error: column A appears more than once in UNIQUE

-- # Each unique constraint must have different columns, in any order.
CREATE TABLE t (a INT UNIQUE, UNIQUE (a));
CREATE TABLE t (a INT, b INT, UNIQUE (a, b), UNIQUE (b, a));
CREATE TABLE t (a INT UNIQUE PRIMARY KEY);
CREATE TABLE t (a INT, b INT, UNIQUE (b, a), PRIMARY KEY (a, b));
CREATE TABLE t (a INT, b INT, UNIQUE (a), UNIQUE (a, b), UNIQUE (b), PRIMARY KEY (b, a, c));
CREATE TABLE t (a INT, b INT, UNIQUE (a), UNIQUE (a, b), UNIQUE (b), PRIMARY KEY (a, b));
-- error 42601: syntax error: UNIQUE (A) has the same columns as another unique constraint
-- error 42601: syntax error: UNIQUE (B, A) has the same columns as another unique constraint
-- error 42601: syntax error: UNIQUE (A) has the same columns as another unique constraint
-- error 42601: syntax error: UNIQUE (B, A) has the same columns as another unique constraint
-- error 42601: syntax error: unknown column C in PRIMARY KEY
-- error 42601: syntax error: UNIQUE (A, B) has the same columns as another unique constraint

-- # There can still only be one PRIMARY KEY, even with a UNIQUE.
CREATE TABLE t (a INT PRIMARY KEY, b INT UNIQUE PRIMARY KEY);
-- error 42601: syntax error: only one PRIMARY KEY can be defined

/* connection 1 */
CREATE TABLE t (u INT UNIQUE);
INSERT INTO t (u) VALUES (1);
START TRANSACTION;
INSERT INTO t (u) VALUES (2);
DELETE FROM t WHERE u = 1;
/* connection 2 */
INSERT INTO t (u) VALUES (2);
INSERT INTO t (u) VALUES (1);
INSERT INTO t (u) VALUES (3);
/* connection 1 */
COMMIT;
/* connection 2 */
INSERT INTO t (u) VALUES (1);
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: msg: INSERT 1
-- 1: msg: DELETE 1
-- 2: error 40001: serialization failure: avoiding concurrent write on individual row
-- 2: error 40001: serialization failure: avoiding concurrent write on individual row
-- 2: msg: INSERT 1
-- 1: msg: COMMIT
-- 2: msg: INSERT 1
-- 2: U: 2
-- 2: U: 3
-- 2: U: 1

-- # The constraints are part of the table definition in the file, so they must
-- # be read back the same.
/* connection 1 */
CREATE TABLE "my table" ("a b" INT UNIQUE, c INT, d INT, UNIQUE (d, "a b"));
/* connection 2 */
INSERT INTO "my table" ("a b", c, d) VALUES (1, 1, 1);
INSERT INTO "my table" ("a b", c, d) VALUES (1, 2, 2);
INSERT INTO "my table" ("a b", c, d) VALUES (2, 1, 1);
SELECT * FROM "my table";
-- 1: msg: CREATE TABLE 1
-- 2: msg: INSERT 1
-- 2: error 23505: violates unique constraint: UNIQUE ("a b") on "test".PUBLIC."my table"
-- 2: msg: INSERT 1
-- 2: a b: 1 C: 1 D: 1
-- 2: a b: 2 C: 1 D: 1

-- # The constraints are dumped as table constraints, after the PRIMARY KEY, so
-- # that loading the dump gives the same table (and the same dump).
CREATE TABLE t (id INT, "a b" INT UNIQUE, c INT CHECK (c > 0), UNIQUE (c, "a b"), PRIMARY KEY (id));
INSERT INTO t (id, "a b", c) VALUES (1, 1, 1);
/* out */
/* in */
/* out */
INSERT INTO t (id, "a b", c) VALUES (2, 1, 2);
INSERT INTO t (id, "a b", c) VALUES (2, 2, 1);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- out: CREATE TABLE "PUBLIC"."T" (
-- out:   "ID" INTEGER NOT NULL,
-- out:   "a b" INTEGER,
-- out:   "C" INTEGER,
-- out:   PRIMARY KEY ("ID"),
-- out:   UNIQUE ("a b"),
-- out:   UNIQUE ("C", "a b"),
-- out:   CHECK (C > 0)
-- out: );
-- out: INSERT INTO "PUBLIC"."T" ("ID", "a b", "C") VALUES (1, 1, 1);
-- out: CREATE TABLE "PUBLIC"."T" (
-- out:   "ID" INTEGER NOT NULL,
-- out:   "a b" INTEGER,
-- out:   "C" INTEGER,
-- out:   PRIMARY KEY ("ID"),
-- out:   UNIQUE ("a b"),
-- out:   UNIQUE ("C", "a b"),
-- out:   CHECK (C > 0)
-- out: );
-- out: INSERT INTO "PUBLIC"."T" ("ID", "a b", "C") VALUES (1, 1, 1);
-- error 23505: violates unique constraint: UNIQUE ("a b") on ":memory:".PUBLIC.T
-- msg: INSERT 1
-- ID: 1 a b: 1 C: 1
-- ID: 2 a b: 2 C: 1

-- # ALTER TABLE ADD COLUMN keeps the UNIQUE constraints of the table, and a new
-- # UNIQUE column with a default can only be added to a table with at most one
-- # row, because every row gets the same value.
CREATE TABLE t (id INT PRIMARY KEY, u INT UNIQUE);
INSERT INTO t (id, u) VALUES (1, 1), (2, 2);
ALTER TABLE t ADD COLUMN v INT UNIQUE;
ALTER TABLE t ADD COLUMN w INT DEFAULT 0 UNIQUE;
INSERT INTO t (id, u) VALUES (3, 1);
UPDATE t SET v = 5;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: ALTER TABLE 1
-- error 23505: violates unique constraint: UNIQUE (W) on ":memory:".PUBLIC.T
-- error 23505: violates unique constraint: UNIQUE (U) on ":memory:".PUBLIC.T
-- error 23505: violates unique constraint: UNIQUE (V) on ":memory:".PUBLIC.T
-- ID: 1 U: 1 V: NULL
-- ID: 2 U: 2 V: NULL

CREATE TABLE t (id INT PRIMARY KEY);
INSERT INTO t (id) VALUES (1);
ALTER TABLE t ADD COLUMN w INT DEFAULT 0 UNIQUE;
INSERT INTO t (id) VALUES (2);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: ALTER TABLE 1
-- error 23505: violates unique constraint: UNIQUE (W) on ":memory:".PUBLIC.T
-- ID: 1 W: 0
