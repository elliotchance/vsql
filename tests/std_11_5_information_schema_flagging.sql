-- # The Conformance Rules of the INFORMATION_SCHEMA views: some views, and some
-- # columns of a view, can't be referenced without a feature. The
-- # INFORMATION_SCHEMA name itself has 18 characters, so it doesn't need F391.
/* setup */
CREATE TABLE t (x INT NOT NULL, y INT GENERATED ALWAYS AS (x + 1));
CREATE TABLE columns (is_updatable INT, is_generated INT);
CREATE TABLE key_column_usage (k INT);
INSERT INTO t (x) VALUES (1);

-- # COLUMNS needs F391 (5.21, Conformance Rules, 1), IS_GENERATED and
-- # GENERATION_EXPRESSION need T175 (2 and 3), and IS_UPDATABLE needs T111 (4).
/* flags */
SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'T';
-- flags: F391
-- COL1: 2

/* flags */
SELECT COLUMN_NAME, IS_GENERATED FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'T';
-- flags: F391, T175
-- COLUMN_NAME: X IS_GENERATED: NEVER
-- COLUMN_NAME: Y IS_GENERATED: ALWAYS

/* flags */
SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'T' AND GENERATION_EXPRESSION IS NOT NULL;
-- flags: F391, T175
-- COLUMN_NAME: Y

/* flags */
SELECT DISTINCT IS_UPDATABLE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'T';
-- flags: F391, T111
-- IS_UPDATABLE: YES

-- # A column of the view is referenced by a qualified name, through a
-- # correlation name (even one that renames it), and in a subquery.
/* flags */
SELECT c.IS_UPDATABLE FROM INFORMATION_SCHEMA.COLUMNS AS c WHERE c.COLUMN_NAME = 'X';
-- flags: F391, T111
-- IS_UPDATABLE: YES

/* flags */
SELECT INFORMATION_SCHEMA.COLUMNS.IS_UPDATABLE FROM INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'X';
-- flags: F391, T111
-- IS_UPDATABLE: YES

/* flags */
SELECT c.u FROM INFORMATION_SCHEMA.COLUMNS AS c (a1, a2, a3, n, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25, a26, a27, a28, a29, a30, a31, a32, a33, a34, a35, a36, a37, a38, a39, a40, a41, g, a43, u) WHERE n = 'X';
-- flags: F391, T111
-- U: YES

/* flags */
SELECT x FROM t WHERE EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE GENERATION_EXPRESSION IS NOT NULL);
-- flags: F391, T175
-- X: 1

/* flags */
SELECT x FROM t WHERE EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS AS c WHERE c.TABLE_NAME = 'T' AND t.x = 1);
-- flags: F391
-- X: 1

-- # An asterisk references every column of the view, but a column of a derived
-- # table isn't a column of the view.
/* flags */
SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'NOSUCH';
-- flags: F391, T111, T175

/* flags */
SELECT c.* FROM INFORMATION_SCHEMA.COLUMNS AS c, t WHERE c.COLUMN_NAME = 'NOSUCH';
-- flags: F391, T111, T175

/* flags */
SELECT t.* FROM INFORMATION_SCHEMA.COLUMNS AS c, t WHERE c.COLUMN_NAME = 'X';
-- flags: F391
-- X: 1 Y: 2

/* flags */
SELECT d.IS_UPDATABLE FROM (SELECT COLUMN_NAME AS IS_UPDATABLE FROM INFORMATION_SCHEMA.COLUMNS) AS d WHERE d.IS_UPDATABLE = 'X';
-- flags: F391, F591
-- IS_UPDATABLE: X

-- # KEY_COLUMN_USAGE needs F341 (5.32, Conformance Rules, 1) and F391 (2).
/* flags */
SELECT COUNT(*) FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE;
-- flags: F341, F391
-- COL1: 0

/* flags */
SELECT x FROM t WHERE x IN (SELECT ORDINAL_POSITION FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE);
-- flags: F341, F391

-- # The short name views need the same features, except F391 (5.77,
-- # Conformance Rules, 9, 37, 39 and 40).
/* flags */
SELECT COUNT(*) FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE_S;
-- flags: F341
-- COL1: 0

/* flags */
SELECT DISTINCT IS_UPDATABLE FROM INFORMATION_SCHEMA.COLUMNS_S WHERE TABLE_NAME = 'T';
-- flags: T111
-- IS_UPDATABLE: YES

/* flags */
SELECT COLUMN_NAME, IS_GENERATED FROM INFORMATION_SCHEMA.COLUMNS_S WHERE TABLE_NAME = 'T';
-- flags: T175
-- COLUMN_NAME: X IS_GENERATED: NEVER
-- COLUMN_NAME: Y IS_GENERATED: ALWAYS

/* flags */
SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS_S WHERE TABLE_NAME = 'T' AND GENERATION_EXPR IS NOT NULL;
-- flags: T175
-- COLUMN_NAME: Y

-- # COLUMN_COLUMN_USAGE needs T175, F341 and F391 (5.17, Conformance Rules,
-- # 1-3), and its short name view needs T175 and F341 (5.77, Conformance Rules,
-- # 18 and 38).
/* flags */
SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMN_COLUMN_USAGE;
-- flags: F341, F391, T175
-- COL1: 1

/* flags */
SELECT COUNT(*) FROM INFORMATION_SCHEMA.COL_COL_USAGE;
-- flags: F341, T175
-- COL1: 1

-- # CONSTRAINT_COLUMN_USAGE and CONSTRAINT_TABLE_USAGE need F341 and F391
-- # (5.22 and 5.23, Conformance Rules, 1 and 2), and their short name views
-- # need F341 (5.77, Conformance Rules, 7 and 8).
/* flags */
SELECT COUNT(*) FROM INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE;
-- flags: F341, F391
-- COL1: 1

/* flags */
SELECT COUNT(*) FROM INFORMATION_SCHEMA.CONSTRAINT_TABLE_USAGE;
-- flags: F341, F391
-- COL1: 0

/* flags */
SELECT COUNT(*) FROM INFORMATION_SCHEMA.CONSTR_COL_USAGE;
-- flags: F341
-- COL1: 1

/* flags */
SELECT COUNT(*) FROM INFORMATION_SCHEMA.CONSTR_TABLE_USAGE;
-- flags: F341
-- COL1: 0

-- # INFORMATION_SCHEMA_CATALOG_NAME needs F391 and F651 (5.2, Conformance
-- # Rules, 1 and 2), but its short name view can be referenced in Core SQL.
/* flags */
SELECT CATALOG_NAME FROM INFORMATION_SCHEMA.INFORMATION_SCHEMA_CATALOG_NAME;
-- flags: F391, F651
-- CATALOG_NAME: :memory:

/* flags */
SELECT CATALOG_NAME FROM INFORMATION_SCHEMA.CATALOG_NAME;
-- flags:
-- CATALOG_NAME: :memory:

-- # CHARACTER_SETS (5.12) and SCHEMATA (5.50) need F391 (Conformance Rules,
-- # 1), but their short name views don't.
/* flags */
SELECT CHARACTER_SET_NAME FROM INFORMATION_SCHEMA.CHARACTER_SETS;
-- flags: F391
-- CHARACTER_SET_NAME: UTF8

/* flags */
SELECT COUNT(*) FROM INFORMATION_SCHEMA.SCHEMATA;
-- flags: F391
-- COL1: 3

/* flags */
SELECT COUNT(*) FROM INFORMATION_SCHEMA.CHARACTER_SETS_S, INFORMATION_SCHEMA.SCHEMATA_S;
-- flags:
-- COL1: 3

-- # SEQUENCES needs T176 and F391 (5.51, Conformance Rules, 1 and 2), and its
-- # short name view needs T176 (5.77, Conformance Rules, 42).
/* flags */
SELECT COUNT(*) FROM INFORMATION_SCHEMA.SEQUENCES;
-- flags: F391, T176
-- COL1: 0

/* flags */
SELECT COUNT(*) FROM INFORMATION_SCHEMA.SEQUENCES_S;
-- flags: T176
-- COL1: 0

-- # ROUTINES needs F391 (5.49, Conformance Rules, 1), CREATED and LAST_ALTERED
-- # need T011 (2 and 3), and NEW_SAVEPOINT_LEVEL needs T272 (4). The same
-- # columns of its short name view need the same features (5.77, Conformance
-- # Rules, 33, 34 and 50). PARAMETERS needs F391 (5.35, Conformance Rules, 1).
/* flags */
SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'GCD';
-- flags: F391
-- COL1: 9

/* flags */
SELECT DISTINCT CREATED, LAST_ALTERED, NEW_SAVEPOINT_LEVEL FROM INFORMATION_SCHEMA.ROUTINES;
-- flags: F391, T011, T272
-- CREATED: NULL LAST_ALTERED: NULL NEW_SAVEPOINT_LEVEL: NULL

/* flags */
SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES_S WHERE ROUTINE_NAME = 'GCD';
-- flags:
-- COL1: 9

/* flags */
SELECT DISTINCT CREATED, LAST_ALTERED, NEW_SAVEPOINT_LVL FROM INFORMATION_SCHEMA.ROUTINES_S;
-- flags: T011, T272
-- CREATED: NULL LAST_ALTERED: NULL NEW_SAVEPOINT_LVL: NULL

/* flags */
SELECT COUNT(*) FROM INFORMATION_SCHEMA.PARAMETERS WHERE SPECIFIC_NAME = 'GCD_1';
-- flags: F391
-- COL1: 2

/* flags */
SELECT COUNT(*) FROM INFORMATION_SCHEMA.PARAMETERS_S WHERE SPECIFIC_NAME = 'GCD_1';
-- flags:
-- COL1: 2

-- # REFERENTIAL_CONSTRAINTS (5.37, Conformance Rules, 1) and TABLES (5.61,
-- # Conformance Rules, 1) need F391.
/* flags */
SELECT COUNT(*) FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS;
-- flags: F391
-- COL1: 0

/* flags */
SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'T';
-- flags: F391
-- COL1: 1

-- # SQL_IMPLEMENTATION_INFO needs F502 and F391 (5.53, Conformance Rules, 1
-- # and 2).
/* flags */
SELECT CHARACTER_VALUE FROM INFORMATION_SCHEMA.SQL_IMPLEMENTATION_INFO WHERE IMPLEMENTATION_INFO_ID = '17';
-- flags: F391, F502
-- CHARACTER_VALUE: vsql

-- # Its short name view only needs F502 (5.77, Conformance Rules, 19).
/* flags */
SELECT CHARACTER_VALUE FROM INFORMATION_SCHEMA.SQL_IMPL_INFO WHERE IMPL_INFO_ID = '17';
-- flags: F502
-- CHARACTER_VALUE: vsql

-- # SQL_PACKAGES and SQL_PARTS need F502 (5.54 and 5.55, Conformance Rules,
-- # 1).
/* flags */
SELECT COUNT(*) FROM INFORMATION_SCHEMA.SQL_PACKAGES;
-- flags: F502
-- COL1: 7

/* flags */
SELECT COUNT(*) FROM INFORMATION_SCHEMA.SQL_PARTS;
-- flags: F502
-- COL1: 11

-- # SQL_SIZING_PROFILES needs F502 and F391 (5.57, Conformance Rules, 1 and
-- # 2), and its short name view only needs F502 (5.77, Conformance Rules, 20).
/* flags */
SELECT COUNT(*) FROM INFORMATION_SCHEMA.SQL_SIZING_PROFILES;
-- flags: F391, F502
-- COL1: 0

/* flags */
SELECT COUNT(*) FROM INFORMATION_SCHEMA.SQL_SIZING_PROFS;
-- flags: F502
-- COL1: 0

-- # The other views, and a table with the same name as a view in another
-- # schema, can be referenced in Core SQL.
/* flags */
SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS WHERE TABLE_NAME = 'T';
-- flags:
-- COL1: 1

/* flags */
SELECT SUPPORTED_VALUE FROM INFORMATION_SCHEMA.SQL_SIZING WHERE SIZING_ID = 30;
-- flags:
-- SUPPORTED_VALUE: 128

/* flags */
SELECT is_updatable, is_generated FROM columns;
-- flags:

/* flags */
SELECT * FROM columns, key_column_usage;
-- flags:

-- # A view is flagged by what it is, not by the long schema name, so it's also
-- # flagged when it's in the default schema (F761 is for SET SCHEMA).
/* flags */
SET SCHEMA 'INFORMATION_SCHEMA';
SELECT IS_UPDATABLE FROM COLUMNS WHERE TABLE_NAME = 'T' AND COLUMN_NAME = 'X';
SELECT COUNT(*) FROM KEY_COLUMN_USAGE;
-- flags: F761
-- msg: SET SCHEMA 1
-- flags: F391, T111
-- IS_UPDATABLE: YES
-- flags: F341, F391
-- COL1: 0
