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
