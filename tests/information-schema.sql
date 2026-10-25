-- # The INFORMATION_SCHEMA is in every catalog, and its views are listed in it.
SELECT table_catalog, table_schema, table_name, table_type, is_insertable_into FROM information_schema.tables;
-- TABLE_CATALOG: :memory: TABLE_SCHEMA: INFORMATION_SCHEMA TABLE_NAME: CHECK_CONSTRAINTS TABLE_TYPE: VIEW IS_INSERTABLE_INTO: NO
-- TABLE_CATALOG: :memory: TABLE_SCHEMA: INFORMATION_SCHEMA TABLE_NAME: COLUMNS TABLE_TYPE: VIEW IS_INSERTABLE_INTO: NO
-- TABLE_CATALOG: :memory: TABLE_SCHEMA: INFORMATION_SCHEMA TABLE_NAME: REFERENTIAL_CONSTRAINTS TABLE_TYPE: VIEW IS_INSERTABLE_INTO: NO
-- TABLE_CATALOG: :memory: TABLE_SCHEMA: INFORMATION_SCHEMA TABLE_NAME: TABLES TABLE_TYPE: VIEW IS_INSERTABLE_INTO: NO
-- TABLE_CATALOG: :memory: TABLE_SCHEMA: INFORMATION_SCHEMA TABLE_NAME: TABLE_CONSTRAINTS TABLE_TYPE: VIEW IS_INSERTABLE_INTO: NO

CREATE SCHEMA information_schema;
-- error 42P06: duplicate schema: INFORMATION_SCHEMA

-- # The INFORMATION_SCHEMA can't be changed.
DROP SCHEMA information_schema RESTRICT;
CREATE TABLE information_schema.foo (x INT);
INSERT INTO information_schema.tables (table_name) VALUES ('x');
UPDATE information_schema.tables SET table_name = 'x';
DELETE FROM information_schema.columns;
DROP TABLE information_schema.tables;
CREATE SEQUENCE information_schema.seq;
ALTER SEQUENCE information_schema.seq RESTART;
DROP SEQUENCE information_schema.seq;
-- error 42501: insufficient privilege: INFORMATION_SCHEMA is read-only
-- error 42501: insufficient privilege: INFORMATION_SCHEMA is read-only
-- error 42501: insufficient privilege: INFORMATION_SCHEMA is read-only
-- error 42501: insufficient privilege: INFORMATION_SCHEMA is read-only
-- error 42501: insufficient privilege: INFORMATION_SCHEMA is read-only
-- error 42501: insufficient privilege: INFORMATION_SCHEMA is read-only
-- error 42501: insufficient privilege: INFORMATION_SCHEMA is read-only
-- error 42501: insufficient privilege: INFORMATION_SCHEMA is read-only
-- error 42501: insufficient privilege: INFORMATION_SCHEMA is read-only

/* virtual_table CREATE TABLE information_schema.fruits (id INT) AS VALUES 1 */
SELECT * FROM information_schema.fruits;
-- error 42501: insufficient privilege: INFORMATION_SCHEMA is read-only
-- error 42P01: no such table: ":memory:".INFORMATION_SCHEMA.FRUITS

SELECT * FROM information_schema.nope;
-- error 42P01: no such table: ":memory:".INFORMATION_SCHEMA.NOPE

SET SCHEMA 'INFORMATION_SCHEMA';
SELECT table_name FROM tables;
-- msg: SET SCHEMA 1
-- TABLE_NAME: CHECK_CONSTRAINTS
-- TABLE_NAME: COLUMNS
-- TABLE_NAME: REFERENTIAL_CONSTRAINTS
-- TABLE_NAME: TABLES
-- TABLE_NAME: TABLE_CONSTRAINTS

SELECT information_schema.tables.table_name, t.table_type FROM information_schema.tables JOIN information_schema.tables AS t ON t.table_name = information_schema.tables.table_name;
-- TABLE_NAME: CHECK_CONSTRAINTS TABLE_TYPE: VIEW
-- TABLE_NAME: COLUMNS TABLE_TYPE: VIEW
-- TABLE_NAME: REFERENTIAL_CONSTRAINTS TABLE_TYPE: VIEW
-- TABLE_NAME: TABLES TABLE_TYPE: VIEW
-- TABLE_NAME: TABLE_CONSTRAINTS TABLE_TYPE: VIEW

-- # Each catalog only describes its own tables.
/* create_catalog FOO */
SET CATALOG 'FOO';
CREATE TABLE bar (x INT);
SELECT table_catalog, table_schema, table_name FROM information_schema.tables;
SET CATALOG ':memory:';
SELECT table_name FROM information_schema.tables WHERE table_schema = 'PUBLIC';
SELECT table_name FROM foo.information_schema.tables WHERE table_schema = 'PUBLIC';
-- msg: SET CATALOG 1
-- msg: CREATE TABLE 1
-- TABLE_CATALOG: FOO TABLE_SCHEMA: INFORMATION_SCHEMA TABLE_NAME: CHECK_CONSTRAINTS
-- TABLE_CATALOG: FOO TABLE_SCHEMA: INFORMATION_SCHEMA TABLE_NAME: COLUMNS
-- TABLE_CATALOG: FOO TABLE_SCHEMA: INFORMATION_SCHEMA TABLE_NAME: REFERENTIAL_CONSTRAINTS
-- TABLE_CATALOG: FOO TABLE_SCHEMA: INFORMATION_SCHEMA TABLE_NAME: TABLES
-- TABLE_CATALOG: FOO TABLE_SCHEMA: INFORMATION_SCHEMA TABLE_NAME: TABLE_CONSTRAINTS
-- TABLE_CATALOG: FOO TABLE_SCHEMA: PUBLIC TABLE_NAME: BAR
-- msg: SET CATALOG 1
-- TABLE_NAME: BAR

-- # Virtual tables registered on a connection aren't part of the catalog.
/* virtual_table CREATE TABLE fruits (id INT) AS VALUES 1 */
SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'PUBLIC';
-- COL1: 0

-- # A table is only described to other transactions once it's committed.
/* connection 1 */
START TRANSACTION;
CREATE TABLE foo (x INT);
SELECT table_name FROM information_schema.tables WHERE table_schema = 'PUBLIC';
/* connection 2 */
SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'PUBLIC';
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE TABLE 1
-- 1: TABLE_NAME: FOO
-- 2: COL1: 0

/* connection 1 */
START TRANSACTION;
CREATE TABLE foo (x INT);
COMMIT;
/* connection 2 */
SELECT table_name FROM information_schema.tables WHERE table_schema = 'PUBLIC';
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE TABLE 1
-- 1: msg: COMMIT
-- 2: TABLE_NAME: FOO

START TRANSACTION;
CREATE TABLE foo (x INT);
ROLLBACK;
SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = 'PUBLIC';
-- msg: START TRANSACTION
-- msg: CREATE TABLE 1
-- msg: ROLLBACK
-- COL1: 0

CREATE TABLE foo (x INT);
DROP TABLE foo;
SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = 'PUBLIC';
-- msg: CREATE TABLE 1
-- msg: DROP TABLE 1
-- COL1: 0

-- # The INFORMATION_SCHEMA isn't part of a dump.
CREATE TABLE foo (x INT);
/* out */
/* in */
SELECT table_schema, table_name FROM information_schema.tables;
-- msg: CREATE TABLE 1
-- out: CREATE TABLE "PUBLIC"."FOO" (
-- out:   "X" INTEGER
-- out: );
-- TABLE_SCHEMA: INFORMATION_SCHEMA TABLE_NAME: CHECK_CONSTRAINTS
-- TABLE_SCHEMA: INFORMATION_SCHEMA TABLE_NAME: COLUMNS
-- TABLE_SCHEMA: INFORMATION_SCHEMA TABLE_NAME: REFERENTIAL_CONSTRAINTS
-- TABLE_SCHEMA: INFORMATION_SCHEMA TABLE_NAME: TABLES
-- TABLE_SCHEMA: INFORMATION_SCHEMA TABLE_NAME: TABLE_CONSTRAINTS
-- TABLE_SCHEMA: PUBLIC TABLE_NAME: FOO
