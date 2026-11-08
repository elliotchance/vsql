-- # A NOT NULL column is a check constraint too. The constraints don't have
-- # names, so they're named after the table and their position.
CREATE TABLE t (a INT CHECK (a > 0) NOT NULL, b VARCHAR(10), c INT NOT NULL, CHECK (c <> a), CHECK (NOT (b LIKE 'x%' OR b = 'it''s')));
SELECT * FROM information_schema.check_constraints;
-- msg: CREATE TABLE 1
-- CONSTRAINT_CATALOG: :memory: CONSTRAINT_SCHEMA: PUBLIC CONSTRAINT_NAME: T_NOT_NULL_1 CHECK_CLAUSE: A IS NOT NULL
-- CONSTRAINT_CATALOG: :memory: CONSTRAINT_SCHEMA: PUBLIC CONSTRAINT_NAME: T_NOT_NULL_3 CHECK_CLAUSE: C IS NOT NULL
-- CONSTRAINT_CATALOG: :memory: CONSTRAINT_SCHEMA: PUBLIC CONSTRAINT_NAME: T_CHECK_1 CHECK_CLAUSE: A > 0
-- CONSTRAINT_CATALOG: :memory: CONSTRAINT_SCHEMA: PUBLIC CONSTRAINT_NAME: T_CHECK_2 CHECK_CLAUSE: C <> A
-- CONSTRAINT_CATALOG: :memory: CONSTRAINT_SCHEMA: PUBLIC CONSTRAINT_NAME: T_CHECK_3 CHECK_CLAUSE: NOT (B LIKE 'x%' OR B = 'it''s')

-- # The columns of a PRIMARY KEY are NOT NULL. Tables are ordered by schema and
-- # name, and a table without constraints doesn't have any rows.
CREATE SCHEMA s;
CREATE TABLE s.a ("my col" INT CHECK ("my col" IN (1, 2)));
CREATE TABLE "Mixed" ("select" INT, "x y" INT, PRIMARY KEY ("x y"));
CREATE TABLE z (x INT);
SELECT constraint_schema, constraint_name, check_clause FROM information_schema.check_constraints;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- CONSTRAINT_SCHEMA: PUBLIC CONSTRAINT_NAME: Mixed_NOT_NULL_2 CHECK_CLAUSE: "x y" IS NOT NULL
-- CONSTRAINT_SCHEMA: S CONSTRAINT_NAME: A_CHECK_1 CHECK_CLAUSE: "my col" IN (1, 2)

CREATE TABLE "select" (id INT NOT NULL, CHECK ("select".id > 0));
SELECT constraint_name, check_clause FROM information_schema.check_constraints;
-- msg: CREATE TABLE 1
-- CONSTRAINT_NAME: select_NOT_NULL_1 CHECK_CLAUSE: ID IS NOT NULL
-- CONSTRAINT_NAME: select_CHECK_1 CHECK_CLAUSE: "select".ID > 0

-- # The constraints are read back from the file the same.
/* connection 1 */
CREATE TABLE t (a INT CHECK (a BETWEEN -1 AND 1.5 AND POSITION('a' IN 'abc') = 1));
/* connection 2 */
SELECT constraint_catalog, constraint_name, check_clause FROM information_schema.check_constraints;
-- 1: msg: CREATE TABLE 1
-- 2: CONSTRAINT_CATALOG: test CONSTRAINT_NAME: T_CHECK_1 CHECK_CLAUSE: A BETWEEN -1 AND 1.5 AND POSITION('a' IN 'abc') = 1

-- # A constraint is removed with its table.
CREATE TABLE t (a INT CHECK (a > 0));
DROP TABLE t RESTRICT;
SELECT * FROM information_schema.check_constraints;
-- msg: CREATE TABLE 1
-- msg: DROP TABLE 1
