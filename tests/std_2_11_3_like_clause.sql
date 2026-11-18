-- # A <like clause> (T171) is replaced by the columns of another table, in the
-- # same place in the <table element list> (11.3, Syntax Rules, 9.b.v). Each
-- # column has the name, type and nullability of the column it's copied from
-- # (Syntax Rules, 9.b.iii), but nothing else: no default, identity, generation
-- # expression or constraint, other than NOT NULL. The rows aren't copied.
CREATE TABLE t (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  a NUMERIC(5, 2) DEFAULT 1.5 NOT NULL,
  b VARCHAR(20) CHECK (b <> '') UNIQUE,
  c TIMESTAMP(3) WITH TIME ZONE,
  d INT GENERATED ALWAYS AS (id + 1)
);
INSERT INTO t (a, b) VALUES (2.5, 'x');
CREATE TABLE u (x BOOLEAN, LIKE t, y SMALLINT NOT NULL);
SELECT * FROM u;
/* out */
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: CREATE TABLE 1
-- out: CREATE TABLE "PUBLIC"."T" (
-- out:   "ID" INTEGER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647) NOT NULL,
-- out:   "A" NUMERIC(5, 2) DEFAULT 1.5 NOT NULL,
-- out:   "B" CHARACTER VARYING(20),
-- out:   "C" TIMESTAMP(3) WITH TIME ZONE,
-- out:   "D" INTEGER GENERATED ALWAYS AS (id + 1),
-- out:   PRIMARY KEY ("ID"),
-- out:   UNIQUE ("B"),
-- out:   CHECK (B <> '')
-- out: );
-- out: INSERT INTO "PUBLIC"."T" ("ID", "A", "B", "C") OVERRIDING SYSTEM VALUE VALUES (1, 2.50, 'x', NULL);
-- out: ALTER TABLE "PUBLIC"."T" ALTER COLUMN "ID" RESTART WITH 2;
-- out: CREATE TABLE "PUBLIC"."U" (
-- out:   "X" BOOLEAN,
-- out:   "ID" INTEGER NOT NULL,
-- out:   "A" NUMERIC(5, 2) NOT NULL,
-- out:   "B" CHARACTER VARYING(20),
-- out:   "C" TIMESTAMP(3) WITH TIME ZONE,
-- out:   "D" INTEGER,
-- out:   "Y" SMALLINT NOT NULL
-- out: );

-- # The new table can have its own constraints on the copied columns.
CREATE TABLE t (x INT, y INT);
CREATE TABLE u (LIKE t, PRIMARY KEY (x), CHECK (y > 0));
INSERT INTO u (x, y) VALUES (1, 0);
INSERT INTO u (x, y) VALUES (NULL, 1);
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- error 23514: violates check constraint: CHECK (Y > 0) on ":memory:".PUBLIC.U
-- error 23502: violates non-null constraint: column X

-- # There can be more than one, and a table can be used twice, but each
-- # column name can still only be used once.
CREATE TABLE t (x INT);
CREATE TABLE t2 (y INT, z INT);
CREATE TABLE u (LIKE t, LIKE t2);
SELECT column_name FROM information_schema.columns WHERE table_name = 'U' ORDER BY ordinal_position;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- COLUMN_NAME: X
-- COLUMN_NAME: Y
-- COLUMN_NAME: Z

CREATE TABLE t (x INT);
CREATE TABLE u (LIKE t, LIKE t);
-- msg: CREATE TABLE 1
-- error 42601: syntax error: column X is defined more than once

CREATE TABLE t (x INT);
CREATE TABLE u (x INT, LIKE t);
-- msg: CREATE TABLE 1
-- error 42601: syntax error: column X is defined more than once

-- # A <like clause> is enough for the table to have a column (Syntax Rules,
-- # 9.a).
CREATE TABLE t (x INT);
CREATE TABLE u (LIKE t, UNIQUE (x));
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1

-- # The table must exist, and can be in another schema, or a view of the
-- # INFORMATION_SCHEMA.
CREATE TABLE u (LIKE nosuch);
-- error 42P01: no such table: ":memory:".PUBLIC.NOSUCH

CREATE TABLE u (LIKE u);
-- error 42P01: no such table: ":memory:".PUBLIC.U

CREATE SCHEMA s;
CREATE TABLE s.t (x INT NOT NULL);
CREATE TABLE u (LIKE s.t);
INSERT INTO u (x) VALUES (NULL);
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- error 23502: violates non-null constraint: column X

CREATE TABLE u (LIKE information_schema.schemata);
SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'U' AND ordinal_position <= 2 ORDER BY ordinal_position;
-- msg: CREATE TABLE 1
-- COLUMN_NAME: CATALOG_NAME DATA_TYPE: CHARACTER VARYING
-- COLUMN_NAME: SCHEMA_NAME DATA_TYPE: CHARACTER VARYING

-- # It can be in a CREATE SCHEMA.
CREATE TABLE t (x INT);
CREATE SCHEMA s CREATE TABLE u (LIKE public.t);
SELECT * FROM s.u;
-- msg: CREATE TABLE 1
-- msg: CREATE SCHEMA 1

-- # The table that's being defined doesn't exist yet when IF NOT EXISTS skips
-- # it, so the <like clause> isn't checked.
/* extensions V103-01 */
CREATE TABLE t (x INT);
CREATE TABLE IF NOT EXISTS t (LIKE nosuch);
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 0

-- # A <like clause> is flagged with T171.
CREATE TABLE t (x INT);
/* flags */
CREATE TABLE u (LIKE t);
-- flags:
-- msg: CREATE TABLE 1
-- flags: T171
-- msg: CREATE TABLE 1

-- # A <like clause> can copy a table that was made by an <as subquery clause>,
-- # and the query of an <as subquery clause> can use a table that was made with
-- # a <like clause>.
CREATE TABLE t (x INT NOT NULL, y VARCHAR(10));
INSERT INTO t (x, y) VALUES (1, 'a');
CREATE TABLE u AS (SELECT x, y FROM t) WITH DATA;
CREATE TABLE v (LIKE u, z BOOLEAN);
INSERT INTO v (x, y, z) VALUES (2, 'b', TRUE);
CREATE TABLE w AS (SELECT * FROM v) WITH DATA;
SELECT * FROM w;
INSERT INTO v (x) VALUES (NULL);
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: CREATE TABLE 1
-- X: 2 Y: b Z: TRUE
-- error 23502: violates non-null constraint: column X
