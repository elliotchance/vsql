-- # BUILD_VERSION, BUILD_COMMIT, BUILD_DATE, BUILD_V_VERSION, BUILD_V_COMMIT
-- # and BUILD_C_COMPILER are vsql extensions (V411-01 to V411-06) that return
-- # how vsql was built.

-- # Each one is the same as its BUILD item of SQL_IMPLEMENTATION_INFO, so this
-- # works for a release and for a build that isn't.
SELECT implementation_info_name, character_value IS NOT DISTINCT FROM CASE implementation_info_name WHEN 'BUILD VERSION' THEN BUILD_VERSION() WHEN 'BUILD COMMIT' THEN BUILD_COMMIT() WHEN 'BUILD DATE' THEN BUILD_DATE() WHEN 'BUILD V VERSION' THEN BUILD_V_VERSION() WHEN 'BUILD V COMMIT' THEN BUILD_V_COMMIT() WHEN 'BUILD C COMPILER' THEN BUILD_C_COMPILER() END AS same FROM information_schema.sql_implementation_info WHERE implementation_info_name LIKE 'BUILD %' ORDER BY implementation_info_id;
-- IMPLEMENTATION_INFO_NAME: BUILD VERSION SAME: TRUE
-- IMPLEMENTATION_INFO_NAME: BUILD COMMIT SAME: TRUE
-- IMPLEMENTATION_INFO_NAME: BUILD DATE SAME: TRUE
-- IMPLEMENTATION_INFO_NAME: BUILD V VERSION SAME: TRUE
-- IMPLEMENTATION_INFO_NAME: BUILD V COMMIT SAME: TRUE
-- IMPLEMENTATION_INFO_NAME: BUILD C COMPILER SAME: TRUE

-- # The tests aren't built for a release, so the version and commit are NULL.
-- # The others always have a value, and the date is a date.
/* types */
VALUES ROW(BUILD_VERSION(), BUILD_COMMIT(), CAST(BUILD_DATE() AS DATE) IS NOT NULL, BUILD_V_VERSION() <> '', BUILD_V_COMMIT() <> '', BUILD_C_COMPILER() <> '');
-- COL1: NULL (CHARACTER VARYING) COL2: NULL (CHARACTER VARYING) COL3: TRUE (BOOLEAN) COL4: TRUE (BOOLEAN) COL5: TRUE (BOOLEAN) COL6: TRUE (BOOLEAN)

-- # They can be used in any expression, such as an INSERT.
CREATE TABLE migrations (id INT, built VARCHAR(20));
INSERT INTO migrations VALUES (1, BUILD_DATE());
SELECT id FROM migrations WHERE built = BUILD_DATE();
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- ID: 1

-- # They don't have arguments.
VALUES BUILD_DATE('x');
-- error 42883: function does not exist: BUILD_DATE(CHARACTER(1))

-- # The value changes when vsql is upgraded, so they can't be in a CHECK
-- # constraint or a generated column.
CREATE TABLE c (a VARCHAR(20), CHECK (a <> BUILD_VERSION()));
CREATE TABLE c (a VARCHAR(20), b VARCHAR(20) GENERATED ALWAYS AS (BUILD_C_COMPILER()));
-- error 42601: syntax error: non-deterministic function BUILD_VERSION cannot be used in a CHECK constraint
-- error 42601: syntax error: non-deterministic function BUILD_C_COMPILER cannot be used in a generation expression

-- # The flagger.
/* flags */
VALUES ROW(BUILD_VERSION(), BUILD_COMMIT(), BUILD_DATE(), BUILD_V_VERSION(), BUILD_V_COMMIT(), BUILD_C_COMPILER()) IS NOT NULL;
-- flags: F641, F661, T051, V411-01, V411-02, V411-03, V411-04, V411-05, V411-06
-- COL1: FALSE
