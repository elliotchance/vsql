-- # There's one row for each SQL-implementation information item, with the
-- # value in either INTEGER_VALUE or CHARACTER_VALUE (6.44, Description, 1 to
-- # 3). The items and the codes of the integer values are the ones of SQL/CLI
-- # (ISO/IEC 9075-3:2003, 7.1), and the ID is a character string.
SELECT implementation_info_id, implementation_info_name, integer_value, character_value FROM information_schema.sql_implementation_info WHERE implementation_info_id NOT IN ('2', '13') AND CAST(implementation_info_id AS INT) < 11000;
-- IMPLEMENTATION_INFO_ID: 14 IMPLEMENTATION_INFO_NAME: SEARCH PATTERN ESCAPE INTEGER_VALUE: NULL CHARACTER_VALUE: \
-- IMPLEMENTATION_INFO_ID: 17 IMPLEMENTATION_INFO_NAME: DBMS NAME INTEGER_VALUE: NULL CHARACTER_VALUE: vsql
-- IMPLEMENTATION_INFO_ID: 18 IMPLEMENTATION_INFO_NAME: DBMS VERSION INTEGER_VALUE: NULL CHARACTER_VALUE: 00.00.0000
-- IMPLEMENTATION_INFO_ID: 23 IMPLEMENTATION_INFO_NAME: CURSOR COMMIT BEHAVIOR INTEGER_VALUE: 2 CHARACTER_VALUE: NULL
-- IMPLEMENTATION_INFO_ID: 26 IMPLEMENTATION_INFO_NAME: DEFAULT TRANSACTION ISOLATION INTEGER_VALUE: 4 CHARACTER_VALUE: NULL
-- IMPLEMENTATION_INFO_ID: 28 IMPLEMENTATION_INFO_NAME: IDENTIFIER CASE INTEGER_VALUE: 1 CHARACTER_VALUE: NULL
-- IMPLEMENTATION_INFO_ID: 46 IMPLEMENTATION_INFO_NAME: TRANSACTION CAPABLE INTEGER_VALUE: 2 CHARACTER_VALUE: NULL
-- IMPLEMENTATION_INFO_ID: 85 IMPLEMENTATION_INFO_NAME: NULL COLLATION INTEGER_VALUE: 1 CHARACTER_VALUE: NULL
-- IMPLEMENTATION_INFO_ID: 94 IMPLEMENTATION_INFO_NAME: SPECIAL CHARACTERS INTEGER_VALUE: NULL CHARACTER_VALUE:
-- IMPLEMENTATION_INFO_ID: 10003 IMPLEMENTATION_INFO_NAME: CATALOG NAME INTEGER_VALUE: NULL CHARACTER_VALUE: Y
-- IMPLEMENTATION_INFO_ID: 10004 IMPLEMENTATION_INFO_NAME: COLLATING SEQUENCE INTEGER_VALUE: NULL CHARACTER_VALUE:

-- # The DATA SOURCE NAME and SERVER NAME are both the name of the SQL-server,
-- # which is the path of the database file (it's different for each test).
SELECT COUNT(*) AS items, COUNT(DISTINCT character_value) AS names FROM information_schema.sql_implementation_info WHERE implementation_info_id IN ('2', '13');
-- ITEMS: 2 NAMES: 1

-- # Each item has a comment that explains its value (6.44, Description, 4).
SELECT comments FROM information_schema.sql_implementation_info WHERE implementation_info_id = '85';
-- COMMENTS: 1: NULLs sort before every other value.

-- # A value is found by its ID, the same way that SQLGetInfo does
-- # (ISO/IEC 9075-3:2003, 6.38, General Rules, 10.b and 10.c).
SELECT character_value FROM information_schema.sql_implementation_info WHERE implementation_info_id = '17';
SELECT integer_value FROM information_schema.sql_implementation_info WHERE implementation_info_id = '28';
-- CHARACTER_VALUE: vsql
-- INTEGER_VALUE: 1

-- # The DBMS VERSION is only the number of the release, such as "01.02.0003"
-- # for v1.2.3, and it's 00.00.0000 until it's built for a release.
SELECT CHAR_LENGTH(character_value) FROM information_schema.sql_implementation_info WHERE implementation_info_name = 'DBMS VERSION';
-- COL1: 10

-- # vsql's own (implementation-defined) items have IDs from 11000 (ISO/IEC
-- # 9075-3:2003, 7.1, Description, 2). The BUILD items were set when vsql
-- # was compiled, and the others are read when they're used. The release and
-- # its commit are NULL until it's built for a release, and the others depend
-- # on the build and the machine, so only whether they have a value is shown.
SELECT implementation_info_id, implementation_info_name, integer_value IS NULL AS no_integer, character_value IS NULL AS no_character FROM information_schema.sql_implementation_info WHERE CAST(implementation_info_id AS INT) BETWEEN 11000 AND 11007;
-- IMPLEMENTATION_INFO_ID: 11000 IMPLEMENTATION_INFO_NAME: BUILD VERSION NO_INTEGER: TRUE NO_CHARACTER: TRUE
-- IMPLEMENTATION_INFO_ID: 11001 IMPLEMENTATION_INFO_NAME: BUILD COMMIT NO_INTEGER: TRUE NO_CHARACTER: TRUE
-- IMPLEMENTATION_INFO_ID: 11002 IMPLEMENTATION_INFO_NAME: BUILD DATE NO_INTEGER: TRUE NO_CHARACTER: FALSE
-- IMPLEMENTATION_INFO_ID: 11003 IMPLEMENTATION_INFO_NAME: BUILD V VERSION NO_INTEGER: TRUE NO_CHARACTER: FALSE
-- IMPLEMENTATION_INFO_ID: 11004 IMPLEMENTATION_INFO_NAME: BUILD V COMMIT NO_INTEGER: TRUE NO_CHARACTER: FALSE
-- IMPLEMENTATION_INFO_ID: 11005 IMPLEMENTATION_INFO_NAME: BUILD C COMPILER NO_INTEGER: TRUE NO_CHARACTER: FALSE
-- IMPLEMENTATION_INFO_ID: 11006 IMPLEMENTATION_INFO_NAME: OPERATING SYSTEM NO_INTEGER: TRUE NO_CHARACTER: FALSE
-- IMPLEMENTATION_INFO_ID: 11007 IMPLEMENTATION_INFO_NAME: MACHINE NO_INTEGER: TRUE NO_CHARACTER: FALSE

-- # The FILE READ VERSION and FILE WRITE VERSION are of the database file,
-- # which a new file has as 1 until it uses something that needs a newer
-- # version of vsql (see the file format docs). They're NULL for :memory:,
-- # which has no file (the tests are run both ways).
SELECT implementation_info_name, COALESCE(integer_value, 1) AS integer_value FROM information_schema.sql_implementation_info WHERE implementation_info_name LIKE 'FILE %';
-- IMPLEMENTATION_INFO_NAME: FILE READ VERSION INTEGER_VALUE: 1
-- IMPLEMENTATION_INFO_NAME: FILE WRITE VERSION INTEGER_VALUE: 1

-- # The BUILD DATE is a date, such as 2026-11-12.
SELECT CHAR_LENGTH(character_value), CAST(character_value AS DATE) IS NOT NULL FROM information_schema.sql_implementation_info WHERE implementation_info_name = 'BUILD DATE';
-- COL1: 10 COL2: TRUE
