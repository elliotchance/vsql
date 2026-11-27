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

-- # A view uses the tables and views that its query reads, but not the tables
-- # that those views read.
CREATE SCHEMA s;
CREATE TABLE s.t (x INT, y INT, z INT);
CREATE VIEW s.v1 AS SELECT x, y + 1 AS a FROM t;
CREATE VIEW v2 AS SELECT * FROM s.v1;
SELECT * FROM information_schema.view_table_usage;
SELECT * FROM information_schema.view_column_usage;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- VIEW_CATALOG: :memory: VIEW_SCHEMA: PUBLIC VIEW_NAME: V2 TABLE_CATALOG: :memory: TABLE_SCHEMA: S TABLE_NAME: V1
-- VIEW_CATALOG: :memory: VIEW_SCHEMA: S VIEW_NAME: V1 TABLE_CATALOG: :memory: TABLE_SCHEMA: S TABLE_NAME: T
-- VIEW_CATALOG: :memory: VIEW_SCHEMA: PUBLIC VIEW_NAME: V2 TABLE_CATALOG: :memory: TABLE_SCHEMA: S TABLE_NAME: V1 COLUMN_NAME: A
-- VIEW_CATALOG: :memory: VIEW_SCHEMA: PUBLIC VIEW_NAME: V2 TABLE_CATALOG: :memory: TABLE_SCHEMA: S TABLE_NAME: V1 COLUMN_NAME: X
-- VIEW_CATALOG: :memory: VIEW_SCHEMA: S VIEW_NAME: V1 TABLE_CATALOG: :memory: TABLE_SCHEMA: S TABLE_NAME: T COLUMN_NAME: X
-- VIEW_CATALOG: :memory: VIEW_SCHEMA: S VIEW_NAME: V1 TABLE_CATALOG: :memory: TABLE_SCHEMA: S TABLE_NAME: T COLUMN_NAME: Y

-- # A column of a table with a correlation name is the column of the table it
-- # reads, including in a subquery. A derived table isn't a table that's
-- # used, but the tables that it reads are.
CREATE TABLE t (x INT, y INT, z INT);
CREATE TABLE u (id INT, x INT);
CREATE VIEW v AS SELECT q.b, d.k FROM u AS q (c, b), (SELECT z AS k FROM t) AS d WHERE q.c IN (SELECT y FROM t AS t2 WHERE t2.x = q.c);
SELECT table_name, column_name FROM information_schema.view_column_usage;
SELECT table_name FROM information_schema.view_table_usage;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: CREATE VIEW 1
-- TABLE_NAME: T COLUMN_NAME: X
-- TABLE_NAME: T COLUMN_NAME: Y
-- TABLE_NAME: T COLUMN_NAME: Z
-- TABLE_NAME: U COLUMN_NAME: ID
-- TABLE_NAME: U COLUMN_NAME: X
-- TABLE_NAME: T
-- TABLE_NAME: U

-- # A view (or its correlation name) with * or a qualified asterisk uses all
-- # of its columns.
CREATE TABLE t (x INT, y INT);
CREATE VIEW v (w) AS SELECT x FROM t;
CREATE VIEW w AS SELECT a.*, t.* FROM v AS a, t;
SELECT table_name, column_name FROM information_schema.view_column_usage WHERE view_name = 'W';
-- msg: CREATE TABLE 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- TABLE_NAME: T COLUMN_NAME: X
-- TABLE_NAME: T COLUMN_NAME: Y
-- TABLE_NAME: V COLUMN_NAME: W

-- # A view can read the INFORMATION_SCHEMA. A routine of the VSQL schema is
-- # used by its specific name, but a standard function isn't a routine.
CREATE TABLE t (x INT);
CREATE VIEW v AS SELECT CBRT(x) AS c, ABS(x) AS a, table_name FROM t, information_schema.tables;
SELECT * FROM information_schema.view_routine_usage;
SELECT table_schema, table_name, column_name FROM information_schema.view_column_usage;
-- msg: CREATE TABLE 1
-- msg: CREATE VIEW 1
-- TABLE_CATALOG: :memory: TABLE_SCHEMA: PUBLIC TABLE_NAME: V SPECIFIC_CATALOG: :memory: SPECIFIC_SCHEMA: VSQL SPECIFIC_NAME: CBRT_1
-- TABLE_SCHEMA: INFORMATION_SCHEMA TABLE_NAME: TABLES COLUMN_NAME: TABLE_NAME
-- TABLE_SCHEMA: PUBLIC TABLE_NAME: T COLUMN_NAME: X

-- # A view that can't be read uses nothing.
CREATE TABLE t (x INT);
CREATE VIEW v AS SELECT x FROM t;
DROP TABLE t RESTRICT;
SELECT * FROM information_schema.view_table_usage;
SELECT * FROM information_schema.view_column_usage;
-- msg: CREATE TABLE 1
-- msg: CREATE VIEW 1
-- msg: DROP TABLE 1

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
