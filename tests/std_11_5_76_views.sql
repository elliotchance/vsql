-- # Every view in the TABLES view is in the VIEWS view. The views of the
-- # INFORMATION_SCHEMA have no definition text, no CHECK OPTION, and can't be
-- # updated or inserted into.
CREATE TABLE t (x INT);
SELECT * FROM information_schema.views WHERE table_name IN ('T', 'TABLES', 'VIEWS');
-- msg: CREATE TABLE 1
-- TABLE_CATALOG: :memory: TABLE_SCHEMA: INFORMATION_SCHEMA TABLE_NAME: TABLES VIEW_DEFINITION: NULL CHECK_OPTION: NONE IS_UPDATABLE: NO INSERTABLE_INTO: NO
-- TABLE_CATALOG: :memory: TABLE_SCHEMA: INFORMATION_SCHEMA TABLE_NAME: VIEWS VIEW_DEFINITION: NULL CHECK_OPTION: NONE IS_UPDATABLE: NO INSERTABLE_INTO: NO

-- # The same views as TABLES, in the same order.
SELECT COUNT(*) FROM information_schema.views;
SELECT COUNT(*) FROM information_schema.tables WHERE table_type = 'VIEW';
SELECT COUNT(*) FROM information_schema.tables t JOIN information_schema.views v ON t.table_name = v.table_name;
-- COL1: 40
-- COL1: 40
-- COL1: 40

-- # A view made by CREATE VIEW has the text of its query, as it was written.
CREATE TABLE t (x INT);
CREATE SCHEMA s;
CREATE VIEW v (y) AS SELECT x /* the x */ FROM t;
CREATE VIEW s."lower" AS VALUES 1;
SELECT * FROM information_schema.views WHERE table_schema <> 'INFORMATION_SCHEMA';
SELECT table_schema, table_name, table_type, is_insertable_into FROM information_schema.tables WHERE table_schema <> 'INFORMATION_SCHEMA';
-- msg: CREATE TABLE 1
-- msg: CREATE SCHEMA 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- TABLE_CATALOG: :memory: TABLE_SCHEMA: PUBLIC TABLE_NAME: V VIEW_DEFINITION: SELECT x /* the x */ FROM t CHECK_OPTION: NONE IS_UPDATABLE: NO INSERTABLE_INTO: NO
-- TABLE_CATALOG: :memory: TABLE_SCHEMA: S TABLE_NAME: lower VIEW_DEFINITION: VALUES 1 CHECK_OPTION: NONE IS_UPDATABLE: NO INSERTABLE_INTO: NO
-- TABLE_SCHEMA: PUBLIC TABLE_NAME: T TABLE_TYPE: BASE TABLE IS_INSERTABLE_INTO: YES
-- TABLE_SCHEMA: PUBLIC TABLE_NAME: V TABLE_TYPE: VIEW IS_INSERTABLE_INTO: NO
-- TABLE_SCHEMA: S TABLE_NAME: lower TABLE_TYPE: VIEW IS_INSERTABLE_INTO: NO

-- # The columns of a view have the types of the columns of its query, which
-- # follow the tables that it reads. A view that can't be read has no columns.
CREATE TABLE t (x INT NOT NULL, z VARCHAR(10));
CREATE VIEW v (a, b) AS SELECT x, z || 'x' FROM t;
CREATE VIEW w AS SELECT z FROM t;
SELECT table_name, column_name, ordinal_position, is_nullable, data_type, character_maximum_length, is_updatable FROM information_schema.columns WHERE table_schema = 'PUBLIC';
ALTER TABLE t DROP COLUMN z RESTRICT;
SELECT table_name, column_name FROM information_schema.columns WHERE table_schema = 'PUBLIC';
-- msg: CREATE TABLE 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- TABLE_NAME: T COLUMN_NAME: X ORDINAL_POSITION: 1 IS_NULLABLE: NO DATA_TYPE: INTEGER CHARACTER_MAXIMUM_LENGTH: NULL IS_UPDATABLE: YES
-- TABLE_NAME: T COLUMN_NAME: Z ORDINAL_POSITION: 2 IS_NULLABLE: YES DATA_TYPE: CHARACTER VARYING CHARACTER_MAXIMUM_LENGTH: 10 IS_UPDATABLE: YES
-- TABLE_NAME: V COLUMN_NAME: A ORDINAL_POSITION: 1 IS_NULLABLE: NO DATA_TYPE: INTEGER CHARACTER_MAXIMUM_LENGTH: NULL IS_UPDATABLE: NO
-- TABLE_NAME: V COLUMN_NAME: B ORDINAL_POSITION: 2 IS_NULLABLE: YES DATA_TYPE: CHARACTER VARYING CHARACTER_MAXIMUM_LENGTH: 11 IS_UPDATABLE: NO
-- TABLE_NAME: W COLUMN_NAME: Z ORDINAL_POSITION: 1 IS_NULLABLE: YES DATA_TYPE: CHARACTER VARYING CHARACTER_MAXIMUM_LENGTH: 10 IS_UPDATABLE: NO
-- msg: ALTER TABLE 1
-- TABLE_NAME: T COLUMN_NAME: X

-- # A view's usage of columns, routines and tables. The views of the
-- # INFORMATION_SCHEMA don't have any.
SELECT * FROM information_schema.view_column_usage;
SELECT * FROM information_schema.view_routine_usage;
SELECT * FROM information_schema.view_table_usage;

-- # VIEWS can be referenced in Core SQL, but the usage views need F341
-- # (5.73, 5.74 and 5.75, Conformance Rules, 1).
/* flags */
SELECT table_name FROM information_schema.views WHERE table_name = 'VIEWS';
-- flags:
-- TABLE_NAME: VIEWS

/* flags */
SELECT * FROM information_schema.view_column_usage;
-- flags: F341

/* flags */
SELECT * FROM information_schema.view_routine_usage;
-- flags: F341

/* flags */
SELECT * FROM information_schema.view_table_usage;
-- flags: F341
