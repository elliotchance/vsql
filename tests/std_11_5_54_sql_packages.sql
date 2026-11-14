-- # There's one row for each package of SQL:2003 (Part 1, Subclause 8.4),
-- # which SQL:2023 removed (#1505). A package is Core SQL and its features, so
-- # none of them are supported until Core SQL is. Nothing is verified by a conformance test (6.43, Description, 6).
SELECT id, name, is_supported, is_verified_by FROM information_schema.sql_packages;
-- ID: PKG001 NAME: Enhanced datetime facilities IS_SUPPORTED: NO IS_VERIFIED_BY: NULL
-- ID: PKG002 NAME: Enhanced integrity management IS_SUPPORTED: NO IS_VERIFIED_BY: NULL
-- ID: PKG004 NAME: PSM IS_SUPPORTED: NO IS_VERIFIED_BY: NULL
-- ID: PKG006 NAME: Basic object support IS_SUPPORTED: NO IS_VERIFIED_BY: NULL
-- ID: PKG007 NAME: Enhanced object support IS_SUPPORTED: NO IS_VERIFIED_BY: NULL
-- ID: PKG008 NAME: Active database IS_SUPPORTED: NO IS_VERIFIED_BY: NULL
-- ID: PKG010 NAME: OLAP IS_SUPPORTED: NO IS_VERIFIED_BY: NULL

-- # The comments have how many of the features of the package are supported,
-- # which changes as features are added. A feature that isn't in the compliance
-- # tables, such as the ones of SQL/PSM, isn't supported.
SELECT id, comments LIKE '% of the % features are supported.' AS has_count FROM information_schema.sql_packages WHERE id IN ('PKG001', 'PKG010');
SELECT comments FROM information_schema.sql_packages WHERE id = 'PKG004';
-- ID: PKG001 HAS_COUNT: TRUE
-- ID: PKG010 HAS_COUNT: TRUE
-- COMMENTS: 0 of the 4 features are supported.

-- # Enhanced object support has all of the features of Basic object support,
-- # and 9 more.
SELECT id, comments LIKE '% of the 5 features are supported.' AS five, comments LIKE '% of the 14 features are supported.' AS fourteen FROM information_schema.sql_packages WHERE id IN ('PKG006', 'PKG007');
-- ID: PKG006 FIVE: TRUE FOURTEEN: FALSE
-- ID: PKG007 FIVE: FALSE FOURTEEN: TRUE
