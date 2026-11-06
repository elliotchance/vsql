-- # CREATE SCHEMA can't be EXPLAINed (EXPLAIN is a vsql extension).
EXPLAIN CREATE SCHEMA foo;
-- error 42601: syntax error: Cannot EXPLAIN CREATE SCHEMA

-- # The default schema of the session is PUBLIC, and creating a schema doesn't
-- # change it.
VALUES CURRENT_SCHEMA;
-- COL1: PUBLIC

CREATE SCHEMA foo;
VALUES CURRENT_SCHEMA;
-- msg: CREATE SCHEMA 1
-- COL1: PUBLIC

-- # A schema name can only be used once in a catalog (Syntax Rules, 3).
CREATE SCHEMA foo;
CREATE SCHEMA foo;
-- msg: CREATE SCHEMA 1
-- error 42P06: duplicate schema: FOO

-- # A table can be created in the new schema by qualifying its name.
CREATE SCHEMA foo;
CREATE TABLE foo.bar (baz INT);
INSERT INTO foo.bar (baz) VALUES (123);
SELECT * FROM foo.bar;
VALUES CURRENT_SCHEMA;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- BAZ: 123
-- COL1: PUBLIC

-- # ABSOLUTE is a non-reserved word, so it can be a schema name. The schema
-- # name can be qualified by its catalog.
CREATE SCHEMA absolute;
-- msg: CREATE SCHEMA 1

CREATE SCHEMA ABSOLUTE;
-- msg: CREATE SCHEMA 1

CREATE SCHEMA ":memory:".foo;
-- msg: CREATE SCHEMA 1

-- # A CREATE SCHEMA can also create tables. An unqualified name is in the new
-- # schema, not the default schema (5.4, Syntax Rules, 4.b), and a qualified
-- # name must be in the new schema (11.3, Syntax Rules, 6). If a table fails,
-- # the schema isn't created either.
CREATE SCHEMA foo CREATE TABLE bar (baz INT);
INSERT INTO foo.bar (baz) VALUES (123);
SELECT * FROM foo.bar;
VALUES CURRENT_SCHEMA;
-- msg: CREATE SCHEMA 1
-- msg: INSERT 1
-- BAZ: 123
-- COL1: PUBLIC

CREATE SCHEMA foo CREATE TABLE foo.bar (baz INT);
INSERT INTO foo.bar (baz) VALUES (1);
-- msg: CREATE SCHEMA 1
-- msg: INSERT 1

CREATE SCHEMA ":memory:".foo CREATE TABLE ":memory:".foo.bar (baz INT);
INSERT INTO foo.bar (baz) VALUES (1);
-- msg: CREATE SCHEMA 1
-- msg: INSERT 1

CREATE SCHEMA foo CREATE TABLE public.bar (baz INT);
CREATE SCHEMA foo;
-- error 42601: syntax error: PUBLIC.BAR must be in schema FOO
-- msg: CREATE SCHEMA 1

-- # Sequences can be created too. An unqualified name is in the new schema
-- # (5.4, Syntax Rules, 13.d.ii), a qualified name must be in the new schema
-- # (11.72, Syntax Rules, 2), and two sequences can't have the same name.
CREATE SCHEMA foo CREATE TABLE bar (baz INT) CREATE SEQUENCE seq START WITH 5;
SELECT NEXT VALUE FOR foo.seq FROM (VALUES 1) AS t;
-- msg: CREATE SCHEMA 1
-- COL1: 5

CREATE SCHEMA foo CREATE SEQUENCE foo.seq;
SELECT NEXT VALUE FOR foo.seq FROM (VALUES 1) AS t;
-- msg: CREATE SCHEMA 1
-- COL1: 1

CREATE SCHEMA foo CREATE SEQUENCE public.seq;
-- error 42601: syntax error: PUBLIC.SEQ must be in schema FOO

CREATE SCHEMA foo CREATE SEQUENCE seq CREATE SEQUENCE seq;
-- error 42P07: duplicate sequence: ":memory:".FOO.SEQ

-- # The names used inside a table are also in the new schema (5.4, Syntax
-- # Rules, 4.b), so a table can reference itself or a table created before it,
-- # but a table of another schema must be qualified. A table created after it
-- # can be referenced too (below).
CREATE SCHEMA foo
  CREATE TABLE parent (id INT PRIMARY KEY)
  CREATE TABLE child (id INT REFERENCES parent, self INT REFERENCES child (other), other INT UNIQUE);
SET SCHEMA 'FOO';
INSERT INTO parent (id) VALUES (1);
INSERT INTO child (id) VALUES (1);
SET SCHEMA 'PUBLIC';
INSERT INTO foo.child (id) VALUES (2);
-- msg: CREATE SCHEMA 1
-- msg: SET SCHEMA 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: SET SCHEMA 1
-- error 23503: violates foreign key constraint: FOREIGN KEY (ID) REFERENCES ":memory:".FOO.PARENT (ID) on ":memory:".FOO.CHILD

CREATE TABLE parent (id INT PRIMARY KEY);
CREATE SCHEMA foo CREATE TABLE child (id INT REFERENCES parent);
-- msg: CREATE TABLE 1
-- error 42P01: no such table: ":memory:".FOO.PARENT

CREATE TABLE parent (id INT PRIMARY KEY);
CREATE SCHEMA foo CREATE TABLE child (id INT REFERENCES public.parent);
INSERT INTO parent (id) VALUES (1);
INSERT INTO foo.child (id) VALUES (1);
-- msg: CREATE TABLE 1
-- msg: CREATE SCHEMA 1
-- msg: INSERT 1
-- msg: INSERT 1

-- # A FOREIGN KEY can reference a table that's after it, and two tables can
-- # reference each other.
CREATE SCHEMA foo
  CREATE TABLE a (x INT PRIMARY KEY, y INT REFERENCES b)
  CREATE TABLE b (x INT PRIMARY KEY, y INT REFERENCES a);
SET SCHEMA 'FOO';
INSERT INTO a (x) VALUES (1);
INSERT INTO b (x, y) VALUES (2, 1);
INSERT INTO b (x, y) VALUES (3, 4);
UPDATE a SET y = 2;
SELECT constraint_name, unique_constraint_name FROM information_schema.referential_constraints;
-- msg: CREATE SCHEMA 1
-- msg: SET SCHEMA 1
-- msg: INSERT 1
-- msg: INSERT 1
-- error 23503: violates foreign key constraint: FOREIGN KEY (Y) REFERENCES ":memory:".FOO.A (X) on ":memory:".FOO.B
-- msg: UPDATE 1
-- CONSTRAINT_NAME: A_FOREIGN_KEY_1 UNIQUE_CONSTRAINT_NAME: B_PRIMARY_KEY
-- CONSTRAINT_NAME: B_FOREIGN_KEY_1 UNIQUE_CONSTRAINT_NAME: A_PRIMARY_KEY

-- # A table that isn't created by any element is still an error, and then the
-- # schema isn't created either.
CREATE SCHEMA foo
  CREATE TABLE a (x INT REFERENCES b)
  CREATE TABLE c (x INT PRIMARY KEY);
CREATE SCHEMA foo;
-- error 42P01: no such table: ":memory:".FOO.B
-- msg: CREATE SCHEMA 1

-- # The name of a foreign key that's added later still can't be used by
-- # another table.
CREATE SCHEMA foo
  CREATE TABLE a (x INT CONSTRAINT k REFERENCES b)
  CREATE TABLE b (x INT CONSTRAINT k PRIMARY KEY);
-- error 42710: duplicate constraint: K

-- # A column of a CHECK can be qualified by its table, which is in the new
-- # schema.
CREATE SCHEMA foo CREATE TABLE bar (baz INT CHECK (bar.baz > 0));
SET SCHEMA 'FOO';
INSERT INTO bar (baz) VALUES (0);
-- msg: CREATE SCHEMA 1
-- msg: SET SCHEMA 1
-- error 23514: violates check constraint: CHECK (BAR.BAZ > 0) on ":memory:".FOO.BAR

-- # A DEFAULT CURRENT_SCHEMA is evaluated when a row is inserted, so it's the
-- # schema of the session (PUBLIC), not the schema the table was created in.
CREATE SCHEMA foo CREATE TABLE bar (baz VARCHAR(128) DEFAULT CURRENT_SCHEMA);
INSERT INTO foo.bar (baz) VALUES (DEFAULT);
SELECT * FROM foo.bar;
-- msg: CREATE SCHEMA 1
-- msg: INSERT 1
-- BAZ: PUBLIC

-- # When an element fails, nothing is created, not even the schema. In a
-- # transaction only the failed statement is undone, so the schema can then be
-- # created, and the ROLLBACK removes it.
CREATE SCHEMA foo CREATE TABLE bar (baz INT) CREATE TABLE bar (baz INT);
VALUES CURRENT_SCHEMA;
CREATE SCHEMA foo;
SELECT * FROM foo.bar;
-- error 42P07: duplicate table: ":memory:".FOO.BAR
-- COL1: PUBLIC
-- msg: CREATE SCHEMA 1
-- error 42P01: no such table: ":memory:".FOO.BAR

START TRANSACTION;
CREATE SCHEMA foo CREATE TABLE bar (baz INT) CREATE TABLE bar (baz INT);
CREATE SCHEMA foo CREATE TABLE bar (baz INT);
SELECT * FROM foo.bar;
ROLLBACK;
CREATE SCHEMA foo;
-- msg: START TRANSACTION
-- error 42P07: duplicate table: ":memory:".FOO.BAR
-- msg: CREATE SCHEMA 1
-- msg: ROLLBACK
-- msg: CREATE SCHEMA 1

-- # The schema must not exist yet, even when tables are created with it, and
-- # INFORMATION_SCHEMA always exists (Syntax Rules, 3).
CREATE SCHEMA foo CREATE TABLE bar (baz INT);
CREATE SCHEMA foo CREATE TABLE bar (baz INT);
-- msg: CREATE SCHEMA 1
-- error 42P06: duplicate schema: FOO

CREATE SCHEMA information_schema CREATE TABLE bar (baz INT);
-- error 42P06: duplicate schema: INFORMATION_SCHEMA

-- # Naming the schema needs F171 (Conformance Rules, 3), and creating a
-- # sequence needs T176 (11.72, Conformance Rules, 1).
/* flags */
CREATE SCHEMA foo CREATE TABLE bar (baz INT) CREATE SEQUENCE seq;
-- flags: F171, T176
-- msg: CREATE SCHEMA 1

-- # The schema can be in another catalog, and then its tables must be in that
-- # catalog too (11.3, Syntax Rules, 6). The current catalog doesn't change.
/* create_catalog FOO */
/* extensions V001-01 */
SET CATALOG ':memory:';
CREATE SCHEMA "FOO".foo CREATE TABLE bar (baz INT);
EXPLAIN SELECT * FROM "FOO".foo.bar;
VALUES CURRENT_CATALOG;
-- msg: SET CATALOG 1
-- msg: CREATE SCHEMA 1
-- EXPLAIN: TABLE FOO.FOO.BAR (BAZ INTEGER)
-- EXPLAIN: EXPR (FOO.FOO.BAR.BAZ INTEGER)
-- COL1: :memory:

/* create_catalog FOO */
SET CATALOG ':memory:';
CREATE SCHEMA "FOO".foo CREATE TABLE ":memory:".foo.bar (baz INT);
-- msg: SET CATALOG 1
-- error 42601: syntax error: ":memory:".FOO.BAR must be in schema FOO
