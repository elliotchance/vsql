-- # Every view in the TABLES view is in the VIEWS view. Until there's CREATE
-- # VIEW, those are the views of the INFORMATION_SCHEMA, which have no
-- # definition text, no CHECK OPTION, and can't be updated or inserted into.
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
