-- # The rows are read from docs/sql-compliance-9075-*.rst. Only a few are tested
-- # here, so the test doesn't change every time the compliance pages do.
-- # A feature's SUB_FEATURE_ID and SUB_FEATURE_NAME are a single space (6.43,
-- # Description, 4).
SELECT * FROM information_schema.sql_features WHERE feature_id = 'E011' AND sub_feature_id IN (' ', '01');
-- FEATURE_ID: E011 FEATURE_NAME: Numeric data types SUB_FEATURE_ID:   SUB_FEATURE_NAME:   IS_SUPPORTED: YES IS_VERIFIED_BY: NULL COMMENTS: NULL
-- FEATURE_ID: E011 FEATURE_NAME: Numeric data types SUB_FEATURE_ID: 01 SUB_FEATURE_NAME: INTEGER and SMALLINT data types (including all spellings) IS_SUPPORTED: YES IS_VERIFIED_BY: NULL COMMENTS: NULL

-- # The markup of a name is removed. The view describes itself.
SELECT feature_name, sub_feature_name, is_supported FROM information_schema.sql_features WHERE feature_id = 'F501' AND sub_feature_id = '01';
-- FEATURE_NAME: Features and conformance views SUB_FEATURE_NAME: SQL_FEATURES view IS_SUPPORTED: YES

-- # A feature that isn't supported (a ❌ or ⭕) is NO.
SELECT is_supported FROM information_schema.sql_features WHERE feature_id = 'S011' AND sub_feature_id = ' ';
-- IS_SUPPORTED: NO

-- # A feature that's in the pages of more than one part has one row for each
-- # feature and subfeature.
SELECT COUNT(*) FROM information_schema.sql_features WHERE feature_id = 'S011';
-- COL1: 2

-- # Only features and subfeatures are in the view (not the CLI routines, which
-- # are also in the pages, or packages and parts).
SELECT COUNT(*) FROM information_schema.sql_features WHERE CHAR_LENGTH(feature_id) <> 4 OR CHAR_LENGTH(sub_feature_id) NOT IN (1, 2);
-- COL1: 0

-- # The view can't be changed.
DELETE FROM information_schema.sql_features;
-- error 42501: insufficient privilege: INFORMATION_SCHEMA is read-only
