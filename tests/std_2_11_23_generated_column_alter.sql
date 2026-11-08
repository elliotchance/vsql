CREATE TABLE foo (x INT);
INSERT INTO foo (x) VALUES (1), (2), (NULL);
ALTER TABLE foo ADD COLUMN y INT GENERATED ALWAYS AS (x * 3);
INSERT INTO foo (x) VALUES (4);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- msg: ALTER TABLE 1
-- msg: INSERT 1
-- X: 1 Y: 3
-- X: 2 Y: 6
-- X: NULL Y: NULL
-- X: 4 Y: 12

CREATE TABLE foo (x INT);
INSERT INTO foo (x) VALUES (1), (NULL);
ALTER TABLE foo ADD COLUMN y GENERATED ALWAYS AS (x * 3) NOT NULL;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- error 23502: violates non-null constraint: column Y

CREATE TABLE foo (x INT, y INT GENERATED ALWAYS AS (x * 2));
INSERT INTO foo (x) VALUES (1);
ALTER TABLE foo ADD COLUMN z INT GENERATED ALWAYS AS (x + 1);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: ALTER TABLE 1
-- X: 1 Y: 2 Z: 2

-- # A dump of a generated column that was added has its generation expression
-- # in the CREATE TABLE, in the position it was added, and the values are set
-- # again from the other columns.
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1), (2);
ALTER TABLE t ADD COLUMN y INT GENERATED ALWAYS AS (x * 10);
ALTER TABLE t ADD COLUMN z VARCHAR(10);
UPDATE t SET z = 'a' WHERE x = 1;
/* out */
/* in */
INSERT INTO t (x, z) VALUES (3, 'c');
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: UPDATE 1
-- out: CREATE TABLE "PUBLIC"."T" (
-- out:   "X" INTEGER,
-- out:   "Y" INTEGER GENERATED ALWAYS AS (X * 10),
-- out:   "Z" CHARACTER VARYING(10)
-- out: );
-- out: INSERT INTO "PUBLIC"."T" ("X", "Z") VALUES (1, 'a');
-- out: INSERT INTO "PUBLIC"."T" ("X", "Z") VALUES (2, NULL);
-- msg: INSERT 1
-- X: 1 Y: 10 Z: a
-- X: 2 Y: 20 Z: NULL
-- X: 3 Y: 30 Z: c

-- # An added generated column without a data type, with NOT NULL and a
-- # delimited identifier.
CREATE TABLE t ("first name" VARCHAR(10));
INSERT INTO t ("first name") VALUES ('Bob');
ALTER TABLE t ADD COLUMN "Greeting" GENERATED ALWAYS AS ('Hi ' || "first name") NOT NULL;
/* out */
/* in */
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: ALTER TABLE 1
-- out: CREATE TABLE "PUBLIC"."T" (
-- out:   "first name" CHARACTER VARYING(10),
-- out:   "Greeting" CHARACTER VARYING(13) GENERATED ALWAYS AS ('Hi ' || "first name") NOT NULL
-- out: );
-- out: INSERT INTO "PUBLIC"."T" ("first name") VALUES ('Bob');
-- first name: Bob Greeting: Hi Bob

-- # A generated column from the CREATE TABLE and one that was added, after a
-- # column used by the first one was dropped with CASCADE.
CREATE TABLE t (w INT, x INT, y INT GENERATED ALWAYS AS (w + x));
INSERT INTO t (w, x) VALUES (1, 2);
ALTER TABLE t ADD COLUMN z INT GENERATED ALWAYS AS (x * 2);
ALTER TABLE t DROP COLUMN w CASCADE;
/* out */
/* in */
INSERT INTO t (x) VALUES (5);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- out: CREATE TABLE "PUBLIC"."T" (
-- out:   "X" INTEGER,
-- out:   "Z" INTEGER GENERATED ALWAYS AS (X * 2)
-- out: );
-- out: INSERT INTO "PUBLIC"."T" ("X") VALUES (2);
-- msg: INSERT 1
-- X: 2 Z: 4
-- X: 5 Z: 10
