-- # There's one row for each sizing item (6.45, Description, 1 to 4). The
-- # items are the ones of SQL/CLI (ISO/IEC 9075-3:2003(E), 7.2). The
-- # SUPPORTED_VALUE is 0 (zero) when there's no limit, and NULL when nothing
-- # that the item is for is supported.
SELECT * FROM information_schema.sql_sizing;
-- SIZING_ID: 0 SIZING_NAME: MAXIMUM DRIVER CONNECTIONS SUPPORTED_VALUE: 0 COMMENTS: There is no limit.
-- SIZING_ID: 1 SIZING_NAME: MAXIMUM CONCURRENT ACTIVITIES SUPPORTED_VALUE: 0 COMMENTS: There is no limit.
-- SIZING_ID: 30 SIZING_NAME: MAXIMUM COLUMN NAME LENGTH SUPPORTED_VALUE: 128 COMMENTS: Characters in a name.
-- SIZING_ID: 31 SIZING_NAME: MAXIMUM CURSOR NAME LENGTH SUPPORTED_VALUE: 128 COMMENTS: Characters in a name.
-- SIZING_ID: 32 SIZING_NAME: MAXIMUM SCHEMA NAME LENGTH SUPPORTED_VALUE: 128 COMMENTS: Characters in a name.
-- SIZING_ID: 34 SIZING_NAME: MAXIMUM CATALOG NAME LENGTH SUPPORTED_VALUE: 128 COMMENTS: Characters in a name.
-- SIZING_ID: 35 SIZING_NAME: MAXIMUM TABLE NAME LENGTH SUPPORTED_VALUE: 128 COMMENTS: Characters in a name.
-- SIZING_ID: 97 SIZING_NAME: MAXIMUM COLUMNS IN GROUP BY SUPPORTED_VALUE: 0 COMMENTS: There is no limit.
-- SIZING_ID: 99 SIZING_NAME: MAXIMUM COLUMNS IN ORDER BY SUPPORTED_VALUE: 0 COMMENTS: There is no limit.
-- SIZING_ID: 100 SIZING_NAME: MAXIMUM COLUMNS IN SELECT SUPPORTED_VALUE: 0 COMMENTS: There is no limit.
-- SIZING_ID: 101 SIZING_NAME: MAXIMUM COLUMNS IN TABLE SUPPORTED_VALUE: 1600 COMMENTS: Columns in a table.
-- SIZING_ID: 106 SIZING_NAME: MAXIMUM TABLES IN SELECT SUPPORTED_VALUE: 0 COMMENTS: There is no limit.
-- SIZING_ID: 107 SIZING_NAME: MAXIMUM USER NAME LENGTH SUPPORTED_VALUE: 0 COMMENTS: There is no limit.
-- SIZING_ID: 10005 SIZING_NAME: MAXIMUM IDENTIFIER LENGTH SUPPORTED_VALUE: 128 COMMENTS: Characters in a name.
-- SIZING_ID: 20000 SIZING_NAME: MAXIMUM STATEMENT OCTETS SUPPORTED_VALUE: 0 COMMENTS: There is no limit.
-- SIZING_ID: 20001 SIZING_NAME: MAXIMUM STATEMENT OCTETS DATA SUPPORTED_VALUE: 0 COMMENTS: There is no limit.
-- SIZING_ID: 20002 SIZING_NAME: MAXIMUM STATEMENT OCTETS SCHEMA SUPPORTED_VALUE: 0 COMMENTS: There is no limit.
-- SIZING_ID: 25000 SIZING_NAME: MAXIMUM CURRENT DEFAULT TRANSFORM GROUP LENGTH SUPPORTED_VALUE: NULL COMMENTS: Transform groups are not supported.
-- SIZING_ID: 25001 SIZING_NAME: MAXIMUM CURRENT TRANSFORM GROUP LENGTH SUPPORTED_VALUE: NULL COMMENTS: Transform groups are not supported.
-- SIZING_ID: 25002 SIZING_NAME: MAXIMUM CURRENT PATH LENGTH SUPPORTED_VALUE: NULL COMMENTS: CURRENT_PATH is not supported.
-- SIZING_ID: 25003 SIZING_NAME: MAXIMUM CURRENT ROLE LENGTH SUPPORTED_VALUE: NULL COMMENTS: Roles are not supported.
-- SIZING_ID: 25004 SIZING_NAME: MAXIMUM SESSION USER LENGTH SUPPORTED_VALUE: NULL COMMENTS: SESSION_USER is not supported.
-- SIZING_ID: 25005 SIZING_NAME: MAXIMUM SYSTEM USER LENGTH SUPPORTED_VALUE: NULL COMMENTS: SYSTEM_USER is not supported.

-- # A size is found by its ID, the same way that SQLGetInfo does
-- # (ISO/IEC 9075-3:2003(E), 6.38, General Rules, 10.a).
SELECT supported_value FROM information_schema.sql_sizing WHERE sizing_id = 30;
-- SUPPORTED_VALUE: 128

-- # The maximum length of a name is the most characters that an identifier can
-- # have.
CREATE TABLE t (x INT);
SELECT supported_value FROM information_schema.sql_sizing WHERE sizing_name = 'MAXIMUM TABLE NAME LENGTH';
ALTER TABLE t ADD COLUMN "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" INT;
ALTER TABLE t ADD COLUMN "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab" INT;
-- msg: CREATE TABLE 1
-- SUPPORTED_VALUE: 128
-- msg: ALTER TABLE 1
-- error 42601: syntax error: identifier is longer than 128 characters: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab
