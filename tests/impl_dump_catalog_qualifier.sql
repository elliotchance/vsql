-- # The catalog of a column in a CHECK or generation expression is left out of
-- # a dump, so that it can be loaded into a file with another name. See also
-- # cmd/tests/out-catalog-qualifier.sh.
CREATE TABLE t (a INT CHECK (":memory:".public.t.a > 0), b INT GENERATED ALWAYS AS (":memory:".public.t.a + 1));
INSERT INTO t (a) VALUES (1);
/* out */
/* in */
SELECT * FROM t;
INSERT INTO t (a) VALUES (0);
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- out: CREATE TABLE "PUBLIC"."T" (
-- out:   "A" INTEGER,
-- out:   "B" INTEGER GENERATED ALWAYS AS (PUBLIC.T.A + 1),
-- out:   CHECK (PUBLIC.T.A > 0)
-- out: );
-- out: INSERT INTO "PUBLIC"."T" ("A") VALUES (1);
-- A: 1 B: 2
-- error 23514: violates check constraint: CHECK (PUBLIC.T.A > 0) on ":memory:".PUBLIC.T

-- # In another schema, where every name in the chain is delimited and contains
-- # a dot or a doubled quote.
CREATE SCHEMA "s.x";
SET SCHEMA '"s.x"';
CREATE TABLE "t.y" ("a""b" INT CHECK (":memory:"."s.x"."t.y"."a""b" > 0));
SET SCHEMA 'PUBLIC';
/* out */
/* in */
INSERT INTO "s.x"."t.y" ("a""b") VALUES (1);
INSERT INTO "s.x"."t.y" ("a""b") VALUES (0);
-- msg: CREATE SCHEMA 1
-- msg: SET SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: SET SCHEMA 1
-- out: CREATE SCHEMA "s.x";
-- out: SET SCHEMA '"s.x"';
-- out: CREATE TABLE "s.x"."t.y" (
-- out:   "a""b" INTEGER,
-- out:   CHECK ("s.x"."t.y"."a""b" > 0)
-- out: );
-- out: SET SCHEMA 'PUBLIC';
-- msg: INSERT 1
-- error 23514: violates check constraint: CHECK ("s.x"."t.y"."a""b" > 0) on ":memory:"."s.x"."t.y"

-- # A name without a catalog isn't changed, however many parts it has, and
-- # neither is anything in a string that looks like a name with a catalog.
CREATE TABLE t (
  a VARCHAR(20) DEFAULT 'A.B.C.D' CHECK (t.a <> 'it''s W.X.Y.Z'),
  "B.C.D.E" INT CHECK (public.t."B.C.D.E" > 1.5e0),
  "F" INT CHECK (F > 0)
);
/* out */
/* in */
/* out */
-- msg: CREATE TABLE 1
-- out: CREATE TABLE "PUBLIC"."T" (
-- out:   "A" CHARACTER VARYING(20) DEFAULT 'A.B.C.D',
-- out:   "B.C.D.E" INTEGER,
-- out:   "F" INTEGER,
-- out:   CHECK (T.A <> 'it''s W.X.Y.Z'),
-- out:   CHECK (PUBLIC.T."B.C.D.E" > 1.5e0),
-- out:   CHECK (F > 0)
-- out: );
-- out: CREATE TABLE "PUBLIC"."T" (
-- out:   "A" CHARACTER VARYING(20) DEFAULT 'A.B.C.D',
-- out:   "B.C.D.E" INTEGER,
-- out:   "F" INTEGER,
-- out:   CHECK (T.A <> 'it''s W.X.Y.Z'),
-- out:   CHECK (PUBLIC.T."B.C.D.E" > 1.5e0),
-- out:   CHECK (F > 0)
-- out: );
