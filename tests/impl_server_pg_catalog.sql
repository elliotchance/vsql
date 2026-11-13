-- # The parts of PostgreSQL's system catalog that clients read to list the
-- # schemas and tables are registered for PostgreSQL clients. Each object has
-- # an oid from its position: the schemas (by name), then the tables.
/* postgresql */
SELECT * FROM pg_namespace;
-- OID: 16384 NSPNAME: INFORMATION_SCHEMA NSPOWNER: 10
-- OID: 16385 NSPNAME: PUBLIC NSPOWNER: 10

/* postgresql */
CREATE SCHEMA s1;
CREATE TABLE s1.t1 (x INT);
CREATE TABLE t2 (x INT);
SELECT * FROM pg_namespace;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- OID: 16384 NSPNAME: INFORMATION_SCHEMA NSPOWNER: 10
-- OID: 16385 NSPNAME: PUBLIC NSPOWNER: 10
-- OID: 16386 NSPNAME: S1 NSPOWNER: 10

-- # A table is 'r' and a view of the INFORMATION_SCHEMA is 'v'. The number of
-- # rows isn't known.
/* postgresql */
CREATE SCHEMA s1;
CREATE TABLE s1.t1 (x INT);
CREATE TABLE t2 (x INT);
SELECT n.nspname, c.relname, c.relkind, c.relowner, c.reltuples
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname <> 'INFORMATION_SCHEMA' OR c.relname = 'TABLES';
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- NSPNAME: INFORMATION_SCHEMA RELNAME: TABLES RELKIND: v RELOWNER: 10 RELTUPLES: -1
-- NSPNAME: PUBLIC RELNAME: T2 RELKIND: r RELOWNER: 10 RELTUPLES: -1
-- NSPNAME: S1 RELNAME: T1 RELKIND: r RELOWNER: 10 RELTUPLES: -1

-- # Every table has its own oid, after the schemas.
/* postgresql */
CREATE TABLE t1 (x INT);
CREATE TABLE t2 (x INT);
SELECT COUNT(*) = COUNT(DISTINCT oid), MIN(oid) > 16385 FROM pg_class;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- COL1: TRUE COL2: TRUE

-- # pg_statio_user_tables has the tables, but not the views.
/* postgresql */
CREATE SCHEMA s1;
CREATE TABLE s1.t1 (x INT);
SELECT s.schemaname, s.relname, s.relid = c.oid
FROM pg_statio_user_tables s JOIN pg_class c ON c.relname = s.relname;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- SCHEMANAME: S1 RELNAME: T1 COL3: TRUE

-- # There are no user-defined types, enums or functions.
/* postgresql */
SELECT * FROM pg_type;
SELECT * FROM pg_enum;
SELECT * FROM pg_proc;

-- # Every object is owned by the only user, and there are no functions to have
-- # arguments.
/* postgresql */
/* types */
VALUES (pg_get_userbyid(10), pg_get_function_identity_arguments(0));
-- COL1: vsql (CHARACTER VARYING) COL2:  (CHARACTER VARYING)

-- # There are no comments, and the sizes aren't known.
/* postgresql */
/* types */
VALUES (obj_description(1, 'pg_class'), pg_total_relation_size(1), pg_table_size(1), pg_indexes_size(1));
-- COL1: NULL (CHARACTER VARYING) COL2: NULL (BIGINT) COL3: NULL (BIGINT) COL4: NULL (BIGINT)

-- # The functions and tables of PostgreSQL clients are flagged as PostgreSQL
-- # compatibility.
/* postgresql */
/* flags */
VALUES (pg_get_function_identity_arguments(0), version(), current_setting('server_version_num'), pg_get_userbyid(10), obj_description(1, 'pg_class'), pg_total_relation_size(1), pg_table_size(1), pg_indexes_size(1));
-- flags: F391, F641, F661, V501-01, V501-02, V501-03, V501-04, V501-05, V501-06, V501-07, V501-08
-- COL1:  COL2: PostgreSQL 9.3.10 on x86_64-unknown-linux-gnu, compiled by gcc (Ubuntu 4.8.2-19ubuntu1) 4.8.2, 64-bit COL3: 90310 COL4: vsql COL5: NULL COL6: NULL COL7: NULL COL8: NULL

/* postgresql */
/* flags */
SELECT COUNT(*) FROM pg_database, pg_namespace, pg_class, pg_statio_user_tables, pg_type, pg_enum, pg_proc;
-- flags: F391, V502-01, V502-02, V502-03, V502-04, V502-05, V502-06, V502-07
-- COL1: 0
