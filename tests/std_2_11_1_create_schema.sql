EXPLAIN CREATE SCHEMA foo;
-- error 42601: syntax error: Cannot EXPLAIN CREATE SCHEMA

VALUES CURRENT_SCHEMA;
-- COL1: PUBLIC

CREATE SCHEMA foo;
VALUES CURRENT_SCHEMA;
-- msg: CREATE SCHEMA 1
-- COL1: PUBLIC

CREATE SCHEMA foo;
CREATE SCHEMA foo;
-- msg: CREATE SCHEMA 1
-- error 42P06: duplicate schema: FOO

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

CREATE SCHEMA absolute;
-- msg: CREATE SCHEMA 1

CREATE SCHEMA ABSOLUTE;
-- msg: CREATE SCHEMA 1

CREATE SCHEMA ":memory:".foo;
-- msg: CREATE SCHEMA 1

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

CREATE SCHEMA foo
  CREATE TABLE a (x INT REFERENCES b)
  CREATE TABLE b (x INT PRIMARY KEY);
-- error 42P01: no such table: ":memory:".FOO.B

CREATE SCHEMA foo CREATE TABLE bar (baz INT CHECK (bar.baz > 0));
SET SCHEMA 'FOO';
INSERT INTO bar (baz) VALUES (0);
-- msg: CREATE SCHEMA 1
-- msg: SET SCHEMA 1
-- error 23514: violates check constraint: CHECK (BAR.BAZ > 0) on ":memory:".FOO.BAR

CREATE SCHEMA foo CREATE TABLE bar (baz VARCHAR(128) DEFAULT CURRENT_SCHEMA);
INSERT INTO foo.bar (baz) VALUES (DEFAULT);
SELECT * FROM foo.bar;
-- msg: CREATE SCHEMA 1
-- msg: INSERT 1
-- BAZ: PUBLIC

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

CREATE SCHEMA foo CREATE TABLE bar (baz INT);
CREATE SCHEMA foo CREATE TABLE bar (baz INT);
-- msg: CREATE SCHEMA 1
-- error 42P06: duplicate schema: FOO

CREATE SCHEMA information_schema CREATE TABLE bar (baz INT);
-- error 42P06: duplicate schema: INFORMATION_SCHEMA

/* flags */
CREATE SCHEMA foo CREATE TABLE bar (baz INT) CREATE SEQUENCE seq;
-- flags: F171, T176
-- msg: CREATE SCHEMA 1

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
