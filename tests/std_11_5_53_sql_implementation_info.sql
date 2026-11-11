-- # There's one row for each SQL-implementation information item, with the
-- # value in either INTEGER_VALUE or CHARACTER_VALUE (6.44, Description, 1 to
-- # 3). The items and the codes of the integer values are the ones of SQL/CLI
-- # (ISO/IEC 9075-3:2003(E), 7.1), and the ID is a character string.
SELECT implementation_info_id, implementation_info_name, integer_value, character_value FROM information_schema.sql_implementation_info WHERE implementation_info_id NOT IN ('2', '13');
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
-- # (ISO/IEC 9075-3:2003(E), 6.38, General Rules, 10.b and 10.c).
SELECT character_value FROM information_schema.sql_implementation_info WHERE implementation_info_id = '17';
SELECT integer_value FROM information_schema.sql_implementation_info WHERE implementation_info_id = '28';
-- CHARACTER_VALUE: vsql
-- INTEGER_VALUE: 1

-- # The DBMS VERSION is 00.00.0000 until it's built for a release, when it's
-- # followed by the version and date, such as "01.02.0003 v1.2.3 2026-11-11".
SELECT CHAR_LENGTH(character_value) FROM information_schema.sql_implementation_info WHERE implementation_info_name = 'DBMS VERSION';
-- COL1: 10
