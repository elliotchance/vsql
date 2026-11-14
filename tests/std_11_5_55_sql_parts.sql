-- # There's one row for each part (ISO/IEC 9075-1:2023, 5.2 to 5.10), but
-- # not for the parts that SQL:2023 added (5.11 and 5.12, #1505). A part is
-- # only supported when all of its mandatory features are, and the parts that
-- # have a compliance page say how many are. Nothing is verified
-- # by a conformance test (6.43, Description, 6).
SELECT part, name, is_supported, is_verified_by FROM information_schema.sql_parts;
-- PART: 1 NAME: Framework (SQL/Framework) IS_SUPPORTED: NO IS_VERIFIED_BY: NULL
-- PART: 2 NAME: Foundation (SQL/Foundation) IS_SUPPORTED: NO IS_VERIFIED_BY: NULL
-- PART: 3 NAME: Call Level Interface (SQL/CLI) IS_SUPPORTED: NO IS_VERIFIED_BY: NULL
-- PART: 4 NAME: Persistent Stored Modules (SQL/PSM) IS_SUPPORTED: NO IS_VERIFIED_BY: NULL
-- PART: 9 NAME: Management of External Data (SQL/MED) IS_SUPPORTED: NO IS_VERIFIED_BY: NULL
-- PART: 10 NAME: Object Language Bindings (SQL/OLB) IS_SUPPORTED: NO IS_VERIFIED_BY: NULL
-- PART: 11 NAME: Information and Definition Schemas (SQL/Schemata) IS_SUPPORTED: NO IS_VERIFIED_BY: NULL
-- PART: 13 NAME: Java Routines and Types Using the Java Programming Language (SQL/JRT) IS_SUPPORTED: NO IS_VERIFIED_BY: NULL
-- PART: 14 NAME: XML-Related Specifications (SQL/XML) IS_SUPPORTED: NO IS_VERIFIED_BY: NULL

-- # The comments are the counts from the compliance pages, so they change as
-- # features are added. A part without a page has no comments.
SELECT part, comments LIKE '% of the % mandatory features are supported.' AS has_count FROM information_schema.sql_parts WHERE comments IS NOT NULL;
SELECT COUNT(*) AS c FROM information_schema.sql_parts WHERE comments IS NULL;
-- PART: 2 HAS_COUNT: TRUE
-- PART: 3 HAS_COUNT: TRUE
-- PART: 11 HAS_COUNT: TRUE
-- C: 6

-- # Part 3 has one mandatory feature, which isn't supported yet.
SELECT comments FROM information_schema.sql_parts WHERE part = '3';
-- COMMENTS: 0 of the 1 mandatory features are supported.
