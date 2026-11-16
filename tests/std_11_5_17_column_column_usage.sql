-- # Each column that a generated column uses, ordered by table, then the
-- # generated column, then the column it uses (6.18, Description, 1 and 2).
CREATE TABLE t (a INT, b INT, c INT GENERATED ALWAYS AS (b * 2 + a), d INT GENERATED ALWAYS AS (b + 1));
CREATE SCHEMA s;
CREATE TABLE s.u ("x y" INT, z VARCHAR(10) GENERATED ALWAYS AS (UPPER(CAST("x y" AS VARCHAR(10)))));
CREATE TABLE v (k INT);
SELECT * FROM information_schema.column_column_usage;
-- msg: CREATE TABLE 1
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- TABLE_CATALOG: :memory: TABLE_SCHEMA: PUBLIC TABLE_NAME: T COLUMN_NAME: A DEPENDENT_COLUMN: C
-- TABLE_CATALOG: :memory: TABLE_SCHEMA: PUBLIC TABLE_NAME: T COLUMN_NAME: B DEPENDENT_COLUMN: C
-- TABLE_CATALOG: :memory: TABLE_SCHEMA: PUBLIC TABLE_NAME: T COLUMN_NAME: B DEPENDENT_COLUMN: D
-- TABLE_CATALOG: :memory: TABLE_SCHEMA: S TABLE_NAME: U COLUMN_NAME: x y DEPENDENT_COLUMN: Z

-- # A generated column that doesn't use any columns isn't in the view, and a
-- # column that's added later is.
CREATE TABLE t (a INT, b INT GENERATED ALWAYS AS (1));
ALTER TABLE t ADD COLUMN c INT GENERATED ALWAYS AS (a - 1);
SELECT column_name, dependent_column FROM information_schema.column_column_usage;
-- msg: CREATE TABLE 1
-- msg: ALTER TABLE 1
-- COLUMN_NAME: A DEPENDENT_COLUMN: C

-- # The generated columns are read back from the file the same, in a
-- # schema other than the current one.
/* connection 1 */
CREATE SCHEMA s;
CREATE TABLE s.t (a INT, b INT GENERATED ALWAYS AS (a + 1));
/* connection 2 */
SELECT table_schema, column_name, dependent_column FROM information_schema.column_column_usage;
-- 1: msg: CREATE SCHEMA 1
-- 1: msg: CREATE TABLE 1
-- 2: TABLE_SCHEMA: S COLUMN_NAME: A DEPENDENT_COLUMN: B

-- # The short name view (5.77).
CREATE TABLE t (a INT, b INT GENERATED ALWAYS AS (a + 1));
SELECT * FROM information_schema.col_col_usage;
-- msg: CREATE TABLE 1
-- TABLE_CATALOG: :memory: TABLE_SCHEMA: PUBLIC TABLE_NAME: T COLUMN_NAME: A DEPENDENT_COLUMN: B
