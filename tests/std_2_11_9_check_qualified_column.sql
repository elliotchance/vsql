-- # A column in a CHECK can be qualified with the name of its table. That means
-- # the same table for as long as the constraint exists, so the current schema
-- # only matters when the constraint is defined.
CREATE TABLE t (a INT CHECK (t.a > 0), b INT CHECK (public.t.b > 0), CHECK (":memory:".public.t.a < t.b));
CREATE SCHEMA x;
SET SCHEMA 'X';
CREATE TABLE t (a VARCHAR(10));
INSERT INTO public.t (a, b) VALUES (1, 2);
INSERT INTO public.t (a, b) VALUES (0, 2);
INSERT INTO public.t (a, b) VALUES (1, 0);
INSERT INTO public.t (a, b) VALUES (2, 1);
UPDATE public.t SET b = 3;
UPDATE public.t SET a = 0;
UPDATE public.t SET b = 0;
SELECT * FROM public.t;
-- msg: CREATE TABLE 1
-- msg: CREATE SCHEMA 1
-- msg: SET SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 23514: violates check constraint: CHECK (T.A > 0) on ":memory:".PUBLIC.T
-- error 23514: violates check constraint: CHECK (PUBLIC.T.B > 0) on ":memory:".PUBLIC.T
-- error 23514: violates check constraint: CHECK (":memory:".PUBLIC.T.A < T.B) on ":memory:".PUBLIC.T
-- msg: UPDATE 1
-- error 23514: violates check constraint: CHECK (T.A > 0) on ":memory:".PUBLIC.T
-- error 23514: violates check constraint: CHECK (PUBLIC.T.B > 0) on ":memory:".PUBLIC.T
-- A: 1 B: 3

-- # A constraint that's defined in the current schema works from any other.
CREATE SCHEMA x;
SET SCHEMA 'X';
CREATE TABLE t (a INT CHECK (t.a > 0));
SET SCHEMA 'PUBLIC';
INSERT INTO x.t (a) VALUES (1);
INSERT INTO x.t (a) VALUES (0);
UPDATE x.t SET a = 0;
-- msg: CREATE SCHEMA 1
-- msg: SET SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: SET SCHEMA 1
-- msg: INSERT 1
-- error 23514: violates check constraint: CHECK (T.A > 0) on ":memory:".X.T
-- error 23514: violates check constraint: CHECK (T.A > 0) on ":memory:".X.T

-- # The same goes for the current catalog.
/* create_catalog FOO */
SET CATALOG ':memory:';
CREATE TABLE t (a INT CHECK (t.a > 0), b INT CHECK (public.t.b > 0), c INT GENERATED ALWAYS AS (public.t.a + t.b));
SET CATALOG 'FOO';
INSERT INTO ":memory:".public.t (a, b) VALUES (1, 2);
INSERT INTO ":memory:".public.t (a, b) VALUES (0, 2);
INSERT INTO ":memory:".public.t (a, b) VALUES (1, 0);
UPDATE ":memory:".public.t SET b = 3;
SELECT * FROM ":memory:".public.t;
-- msg: SET CATALOG 1
-- msg: CREATE TABLE 1
-- msg: SET CATALOG 1
-- msg: INSERT 1
-- error 23514: violates check constraint: CHECK (T.A > 0) on ":memory:".PUBLIC.T
-- error 23514: violates check constraint: CHECK (PUBLIC.T.B > 0) on ":memory:".PUBLIC.T
-- msg: UPDATE 1
-- A: 1 B: 3 C: 4

-- # The expression of a generated column works the same way.
CREATE TABLE t (a INT, b INT GENERATED ALWAYS AS (t.a + 1), c INT GENERATED ALWAYS AS (public.t.a + 2));
CREATE SCHEMA x;
SET SCHEMA 'X';
INSERT INTO public.t (a) VALUES (1);
UPDATE public.t SET a = 2;
SELECT * FROM public.t;
-- msg: CREATE TABLE 1
-- msg: CREATE SCHEMA 1
-- msg: SET SCHEMA 1
-- msg: INSERT 1
-- msg: UPDATE 1
-- A: 2 B: 3 C: 4

-- # A new definition still uses the current schema, like any other table name.
CREATE SCHEMA x;
SET SCHEMA 'X';
CREATE TABLE public.t (a INT CHECK (t.a > 0));
CREATE TABLE public.t (a INT, b INT GENERATED ALWAYS AS (t.a + 1));
CREATE TABLE public.t (a INT);
ALTER TABLE public.t ADD CONSTRAINT c CHECK (t.a > 0);
ALTER TABLE public.t ADD COLUMN b INT CHECK (t.b > 0);
ALTER TABLE public.t ADD COLUMN b INT GENERATED ALWAYS AS (t.a + 1);
SELECT * FROM public.t;
-- msg: CREATE SCHEMA 1
-- msg: SET SCHEMA 1
-- error 42P01: no such table: ":memory:".X.T
-- error 42P01: no such table: ":memory:".X.T
-- msg: CREATE TABLE 1
-- error 42P01: no such table: ":memory:".X.T
-- error 42P01: no such table: ":memory:".X.T
-- error 42P01: no such table: ":memory:".X.T

-- # Changing a table from another schema doesn't check its stored definitions
-- # again with that schema, only the new one.
/* extensions V105-01 */
CREATE TABLE t (a INT CHECK (t.a > 0), b INT GENERATED ALWAYS AS (t.a + 1), c INT);
CREATE SCHEMA x;
SET SCHEMA 'X';
ALTER TABLE public.t ADD CONSTRAINT d CHECK (public.t.a < 10);
ALTER TABLE public.t ADD COLUMN e INT CHECK (public.t.e > 0);
ALTER TABLE public.t ADD COLUMN f INT GENERATED ALWAYS AS (public.t.a + 2);
ALTER TABLE public.t DROP COLUMN c;
INSERT INTO public.t (a, e) VALUES (1, 1);
INSERT INTO public.t (a, e) VALUES (0, 1);
INSERT INTO public.t (a, e) VALUES (10, 1);
INSERT INTO public.t (a, e) VALUES (1, 0);
SELECT * FROM public.t;
ALTER TABLE public.t DROP COLUMN a;
-- msg: CREATE TABLE 1
-- msg: CREATE SCHEMA 1
-- msg: SET SCHEMA 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: INSERT 1
-- error 23514: violates check constraint: CHECK (T.A > 0) on ":memory:".PUBLIC.T
-- error 23514: violates check constraint: CHECK (PUBLIC.T.A < 10) on ":memory:".PUBLIC.T
-- error 23514: violates check constraint: CHECK (PUBLIC.T.E > 0) on ":memory:".PUBLIC.T
-- A: 1 B: 2 E: 1 F: 3
-- error 2BP01: dependent objects still exist on column B on ":memory:".PUBLIC.T

-- # The definition is parsed again when the file is opened, and it's still the
-- # same table for a connection with a different current schema.
/* connection 1 */
CREATE SCHEMA x;
CREATE SCHEMA y;
SET SCHEMA 'X';
CREATE TABLE t (a INT CHECK (t.a > 0), b INT GENERATED ALWAYS AS (t.a + 1));
/* connection 2 */
SET SCHEMA 'Y';
INSERT INTO x.t (a) VALUES (1);
INSERT INTO x.t (a) VALUES (0);
UPDATE x.t SET a = 2;
UPDATE x.t SET a = 0;
SELECT * FROM x.t;
-- 1: msg: CREATE SCHEMA 1
-- 1: msg: CREATE SCHEMA 1
-- 1: msg: SET SCHEMA 1
-- 1: msg: CREATE TABLE 1
-- 2: msg: SET SCHEMA 1
-- 2: msg: INSERT 1
-- 2: error 23514: violates check constraint: CHECK (T.A > 0) on "test".X.T
-- 2: msg: UPDATE 1
-- 2: error 23514: violates check constraint: CHECK (T.A > 0) on "test".X.T
-- 2: A: 2 B: 3

-- # A dump can be loaded when the table is only known by its name, which is the
-- # schema of the table while it's being created.
CREATE SCHEMA "it's";
CREATE TABLE "it's".t (a INT, CHECK (a > 0));
SET SCHEMA 'it''s';
CREATE TABLE u (a INT CHECK (u.a > 0), b INT GENERATED ALWAYS AS (u.a + 1));
INSERT INTO u (a) VALUES (1);
SET SCHEMA 'PUBLIC';
CREATE TABLE u (a INT CHECK (u.a > 0));
/* out */
/* in */
SELECT * FROM "it's".u;
INSERT INTO "it's".u (a) VALUES (0);
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: SET SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: SET SCHEMA 1
-- msg: CREATE TABLE 1
-- out: CREATE TABLE "PUBLIC"."U" (
-- out:   "A" INTEGER,
-- out:   CHECK (U.A > 0)
-- out: );
-- out: CREATE SCHEMA "it's";
-- out: SET SCHEMA 'it''s';
-- out: CREATE TABLE "it's"."T" (
-- out:   "A" INTEGER,
-- out:   CHECK (A > 0)
-- out: );
-- out: SET SCHEMA 'PUBLIC';
-- out: SET SCHEMA 'it''s';
-- out: CREATE TABLE "it's"."U" (
-- out:   "A" INTEGER,
-- out:   "B" INTEGER GENERATED ALWAYS AS (U.A + 1),
-- out:   CHECK (U.A > 0)
-- out: );
-- out: SET SCHEMA 'PUBLIC';
-- out: INSERT INTO "it's"."U" ("A") VALUES (1);
-- A: 1 B: 2
-- error 23514: violates check constraint: CHECK (U.A > 0) on ":memory:"."it's".U
