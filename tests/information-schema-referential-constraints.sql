-- # Each FOREIGN KEY has the name of the unique constraint that it references,
-- # which is the PRIMARY KEY when the referenced columns aren't given. It can't
-- # have a MATCH yet.
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (parent_id INT REFERENCES parent);
SELECT * FROM information_schema.referential_constraints;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- CONSTRAINT_CATALOG: :memory: CONSTRAINT_SCHEMA: PUBLIC CONSTRAINT_NAME: CHILD_FOREIGN_KEY_1 UNIQUE_CONSTRAINT_CATALOG: :memory: UNIQUE_CONSTRAINT_SCHEMA: PUBLIC UNIQUE_CONSTRAINT_NAME: PARENT_PRIMARY_KEY MATCH_OPTION: NONE UPDATE_RULE: NO ACTION DELETE_RULE: NO ACTION

-- # A FOREIGN KEY can reference a UNIQUE, with the columns in any order, and a
-- # table in another schema. The unique constraint is in the schema of the
-- # referenced table. Tables are ordered by schema and name, then the FOREIGN
-- # KEYs are in the order they're defined.
CREATE SCHEMA s;
CREATE TABLE s.parent (id INT PRIMARY KEY, a INT, b INT, c INT UNIQUE, UNIQUE (a, b));
CREATE TABLE child (x INT, y INT REFERENCES s.parent (c), FOREIGN KEY (y, x) REFERENCES s.parent (b, a), z INT REFERENCES s.parent);
CREATE TABLE s.emp (id INT PRIMARY KEY, manager_id INT REFERENCES s.emp);
SELECT constraint_schema, constraint_name, unique_constraint_schema, unique_constraint_name FROM information_schema.referential_constraints;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- CONSTRAINT_SCHEMA: PUBLIC CONSTRAINT_NAME: CHILD_FOREIGN_KEY_1 UNIQUE_CONSTRAINT_SCHEMA: S UNIQUE_CONSTRAINT_NAME: PARENT_UNIQUE_1
-- CONSTRAINT_SCHEMA: PUBLIC CONSTRAINT_NAME: CHILD_FOREIGN_KEY_2 UNIQUE_CONSTRAINT_SCHEMA: S UNIQUE_CONSTRAINT_NAME: PARENT_UNIQUE_2
-- CONSTRAINT_SCHEMA: PUBLIC CONSTRAINT_NAME: CHILD_FOREIGN_KEY_3 UNIQUE_CONSTRAINT_SCHEMA: S UNIQUE_CONSTRAINT_NAME: PARENT_PRIMARY_KEY
-- CONSTRAINT_SCHEMA: S CONSTRAINT_NAME: EMP_FOREIGN_KEY_1 UNIQUE_CONSTRAINT_SCHEMA: S UNIQUE_CONSTRAINT_NAME: EMP_PRIMARY_KEY

-- # Each row is a FOREIGN KEY in TABLE_CONSTRAINTS, and the unique constraint is
-- # a PRIMARY KEY or UNIQUE of the referenced table.
CREATE TABLE parent (id INT PRIMARY KEY, u INT UNIQUE);
CREATE TABLE child (a INT REFERENCES parent (u), b INT REFERENCES parent);
SELECT rc.constraint_name, tc1.constraint_type, tc1.table_name, tc2.constraint_type AS unique_type, tc2.table_name AS unique_table FROM information_schema.referential_constraints AS rc JOIN information_schema.table_constraints AS tc1 ON tc1.constraint_name = rc.constraint_name JOIN information_schema.table_constraints AS tc2 ON tc2.constraint_name = rc.unique_constraint_name;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- CONSTRAINT_NAME: CHILD_FOREIGN_KEY_1 CONSTRAINT_TYPE: FOREIGN KEY TABLE_NAME: CHILD UNIQUE_TYPE: UNIQUE UNIQUE_TABLE: PARENT
-- CONSTRAINT_NAME: CHILD_FOREIGN_KEY_2 CONSTRAINT_TYPE: FOREIGN KEY TABLE_NAME: CHILD UNIQUE_TYPE: PRIMARY KEY UNIQUE_TABLE: PARENT

-- # A FOREIGN KEY that's dropped by a DROP TABLE CASCADE is removed, and the
-- # other FOREIGN KEY keeps its name.
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (parent_id INT REFERENCES parent, id INT PRIMARY KEY REFERENCES child);
DROP TABLE parent CASCADE;
SELECT constraint_name, unique_constraint_name FROM information_schema.referential_constraints;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: DROP TABLE 1
-- CONSTRAINT_NAME: CHILD_FOREIGN_KEY_2 UNIQUE_CONSTRAINT_NAME: CHILD_PRIMARY_KEY

-- # The constraints are read back from the file the same.
/* connection 1 */
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (parent_id INT REFERENCES parent);
/* connection 2 */
SELECT constraint_catalog, constraint_name, unique_constraint_catalog, unique_constraint_name FROM information_schema.referential_constraints;
-- 1: msg: CREATE TABLE 1
-- 1: msg: CREATE TABLE 1
-- 2: CONSTRAINT_CATALOG: test CONSTRAINT_NAME: CHILD_FOREIGN_KEY_1 UNIQUE_CONSTRAINT_CATALOG: test UNIQUE_CONSTRAINT_NAME: PARENT_PRIMARY_KEY
