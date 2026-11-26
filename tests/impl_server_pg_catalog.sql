-- # The parts of PostgreSQL's system catalog that clients read to list the
-- # schemas and tables are registered for PostgreSQL clients. Each object has
-- # an oid from its position: the schemas (by name), then the tables. The
-- # built-in types are in pg_catalog.
/* postgresql */
SELECT * FROM pg_namespace;
-- OID: 11 NSPNAME: pg_catalog NSPOWNER: 10 NSPACL: NULL
-- OID: 16384 NSPNAME: INFORMATION_SCHEMA NSPOWNER: 10 NSPACL: NULL
-- OID: 16385 NSPNAME: PUBLIC NSPOWNER: 10 NSPACL: NULL
-- OID: 16386 NSPNAME: VSQL NSPOWNER: 10 NSPACL: NULL

/* postgresql */
CREATE SCHEMA s1;
CREATE TABLE s1.t1 (x INT);
CREATE TABLE t2 (x INT);
SELECT oid, nspname FROM pg_namespace;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- OID: 11 NSPNAME: pg_catalog
-- OID: 16384 NSPNAME: INFORMATION_SCHEMA
-- OID: 16385 NSPNAME: PUBLIC
-- OID: 16386 NSPNAME: S1
-- OID: 16387 NSPNAME: VSQL

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

-- # pg_type has the built-in types (in pg_catalog), and format_type() is the
-- # SQL name of each. There are no user-defined types, enums or functions.
/* postgresql */
SELECT oid, typname, typnamespace, typlen, typbyval, typcategory, format_type(oid, -1) FROM pg_type;
-- OID: 16 TYPNAME: bool TYPNAMESPACE: 11 TYPLEN: 1 TYPBYVAL: TRUE TYPCATEGORY: B COL7: boolean
-- OID: 20 TYPNAME: int8 TYPNAMESPACE: 11 TYPLEN: 8 TYPBYVAL: TRUE TYPCATEGORY: N COL7: bigint
-- OID: 21 TYPNAME: int2 TYPNAMESPACE: 11 TYPLEN: 2 TYPBYVAL: TRUE TYPCATEGORY: N COL7: smallint
-- OID: 23 TYPNAME: int4 TYPNAMESPACE: 11 TYPLEN: 4 TYPBYVAL: TRUE TYPCATEGORY: N COL7: integer
-- OID: 25 TYPNAME: text TYPNAMESPACE: 11 TYPLEN: -1 TYPBYVAL: FALSE TYPCATEGORY: S COL7: text
-- OID: 700 TYPNAME: float4 TYPNAMESPACE: 11 TYPLEN: 4 TYPBYVAL: TRUE TYPCATEGORY: N COL7: real
-- OID: 701 TYPNAME: float8 TYPNAMESPACE: 11 TYPLEN: 8 TYPBYVAL: TRUE TYPCATEGORY: N COL7: double precision
-- OID: 1042 TYPNAME: bpchar TYPNAMESPACE: 11 TYPLEN: -1 TYPBYVAL: FALSE TYPCATEGORY: S COL7: character
-- OID: 1043 TYPNAME: varchar TYPNAMESPACE: 11 TYPLEN: -1 TYPBYVAL: FALSE TYPCATEGORY: S COL7: character varying
-- OID: 1082 TYPNAME: date TYPNAMESPACE: 11 TYPLEN: 4 TYPBYVAL: TRUE TYPCATEGORY: D COL7: date
-- OID: 1083 TYPNAME: time TYPNAMESPACE: 11 TYPLEN: 8 TYPBYVAL: TRUE TYPCATEGORY: D COL7: time without time zone
-- OID: 1114 TYPNAME: timestamp TYPNAMESPACE: 11 TYPLEN: 8 TYPBYVAL: TRUE TYPCATEGORY: D COL7: timestamp without time zone
-- OID: 1184 TYPNAME: timestamptz TYPNAMESPACE: 11 TYPLEN: 8 TYPBYVAL: TRUE TYPCATEGORY: D COL7: timestamp with time zone
-- OID: 1266 TYPNAME: timetz TYPNAMESPACE: 11 TYPLEN: 12 TYPBYVAL: FALSE TYPCATEGORY: D COL7: time with time zone
-- OID: 1700 TYPNAME: numeric TYPNAMESPACE: 11 TYPLEN: -1 TYPBYVAL: FALSE TYPCATEGORY: N COL7: numeric

/* postgresql */
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

/* postgresql */
/* flags */
SELECT COUNT(*) FROM pg_attribute, pg_attrdef, pg_roles, pg_tablespace, pg_settings, pg_description, pg_shdescription, pg_depend, pg_conversion, pg_collation, pg_am, pg_language;
-- flags: V502-08, V502-09, V502-10, V502-11, V502-12, V502-13, V502-14, V502-15, V502-16, V502-17, V502-18, V502-19
-- COL1: 0

/* postgresql */
/* flags */
SELECT COUNT(*) FROM pg_inherits, pg_constraint, pg_index, pg_trigger, pg_rewrite, pg_aggregate, pg_default_acl, pg_extension, pg_available_extensions, pg_event_trigger, pg_foreign_data_wrapper, pg_foreign_server;
-- flags: F391, V502-20, V502-21, V502-22, V502-23, V502-24, V502-25, V502-26, V502-27, V502-28, V502-29, V502-30, V502-31
-- COL1: 0

/* postgresql */
/* flags */
VALUES (current_database() IS NOT NULL, pg_database_size(1), format_type(23, -1), pg_get_expr('x', 1), pg_get_expr('x', 1, TRUE), pg_tablespace_location(1663), pg_encoding_to_char(6), pg_relation_size(1), pg_stat_get_numscans(1), pg_get_indexdef(1, 0, TRUE), pg_get_constraintdef(1), pg_get_constraintdef(1, TRUE), pg_get_ruledef(1), shobj_description(1, 'pg_database'));
-- flags: F391, F641, F661, T031, V501-09, V501-10, V501-11, V501-12, V501-13, V501-14, V501-15, V501-16, V501-17, V501-18, V501-19, V501-20
-- COL1: TRUE COL2: NULL COL3: integer COL4: x COL5: x COL6:  COL7: UTF8 COL8: NULL COL9: NULL COL10:  COL11:  COL12:  COL13:  COL14: NULL

-- # pg_class describes each table, and pg_attribute each of its columns (from
-- # 1), with the PostgreSQL type and the type modifier: the length of a
-- # character string, or the precision and scale of a number (each plus 4).
/* postgresql */
CREATE TABLE t1 (a INT PRIMARY KEY, b VARCHAR(20) DEFAULT 'x' NOT NULL, c CHAR(3), d DECIMAL(10, 2), e NUMERIC, f BOOLEAN, g BIGINT, h SMALLINT, i REAL, j DOUBLE PRECISION, k DATE, l TIME, m TIME WITH TIME ZONE, n TIMESTAMP, o TIMESTAMP WITH TIME ZONE, p VARBINARY(4), q VARCHAR);
SELECT c.relname, c.relkind, c.relnatts, c.relhasindex, c.relhaspkey, c.relpersistence FROM pg_class c WHERE c.relname = 'T1';
SELECT a.attnum, a.attname, a.atttypid, a.attlen, a.atttypmod, a.attnotnull, a.atthasdef, format_type(a.atttypid, a.atttypmod), pg_get_expr(ad.adbin, ad.adrelid) FROM pg_attribute a JOIN pg_class c ON c.oid = a.attrelid LEFT JOIN pg_attrdef ad ON ad.adrelid = a.attrelid AND ad.adnum = a.attnum WHERE c.relname = 'T1' ORDER BY a.attnum;
-- msg: CREATE TABLE 1
-- RELNAME: T1 RELKIND: r RELNATTS: 17 RELHASINDEX: TRUE RELHASPKEY: TRUE RELPERSISTENCE: p
-- ATTNUM: 1 ATTNAME: A ATTTYPID: 23 ATTLEN: 4 ATTTYPMOD: -1 ATTNOTNULL: TRUE ATTHASDEF: FALSE COL8: integer COL9: NULL
-- ATTNUM: 2 ATTNAME: B ATTTYPID: 1043 ATTLEN: -1 ATTTYPMOD: 24 ATTNOTNULL: TRUE ATTHASDEF: TRUE COL8: character varying(20) COL9: 'x'
-- ATTNUM: 3 ATTNAME: C ATTTYPID: 1042 ATTLEN: -1 ATTTYPMOD: 7 ATTNOTNULL: FALSE ATTHASDEF: FALSE COL8: character(3) COL9: NULL
-- ATTNUM: 4 ATTNAME: D ATTTYPID: 1700 ATTLEN: -1 ATTTYPMOD: 655366 ATTNOTNULL: FALSE ATTHASDEF: FALSE COL8: numeric(10,2) COL9: NULL
-- ATTNUM: 5 ATTNAME: E ATTTYPID: 1700 ATTLEN: -1 ATTTYPMOD: -1 ATTNOTNULL: FALSE ATTHASDEF: FALSE COL8: numeric COL9: NULL
-- ATTNUM: 6 ATTNAME: F ATTTYPID: 16 ATTLEN: 1 ATTTYPMOD: -1 ATTNOTNULL: FALSE ATTHASDEF: FALSE COL8: boolean COL9: NULL
-- ATTNUM: 7 ATTNAME: G ATTTYPID: 20 ATTLEN: 8 ATTTYPMOD: -1 ATTNOTNULL: FALSE ATTHASDEF: FALSE COL8: bigint COL9: NULL
-- ATTNUM: 8 ATTNAME: H ATTTYPID: 21 ATTLEN: 2 ATTTYPMOD: -1 ATTNOTNULL: FALSE ATTHASDEF: FALSE COL8: smallint COL9: NULL
-- ATTNUM: 9 ATTNAME: I ATTTYPID: 700 ATTLEN: 4 ATTTYPMOD: -1 ATTNOTNULL: FALSE ATTHASDEF: FALSE COL8: real COL9: NULL
-- ATTNUM: 10 ATTNAME: J ATTTYPID: 701 ATTLEN: 8 ATTTYPMOD: -1 ATTNOTNULL: FALSE ATTHASDEF: FALSE COL8: double precision COL9: NULL
-- ATTNUM: 11 ATTNAME: K ATTTYPID: 1082 ATTLEN: 4 ATTTYPMOD: -1 ATTNOTNULL: FALSE ATTHASDEF: FALSE COL8: date COL9: NULL
-- ATTNUM: 12 ATTNAME: L ATTTYPID: 1083 ATTLEN: 8 ATTTYPMOD: -1 ATTNOTNULL: FALSE ATTHASDEF: FALSE COL8: time without time zone COL9: NULL
-- ATTNUM: 13 ATTNAME: M ATTTYPID: 1266 ATTLEN: 12 ATTTYPMOD: -1 ATTNOTNULL: FALSE ATTHASDEF: FALSE COL8: time with time zone COL9: NULL
-- ATTNUM: 14 ATTNAME: N ATTTYPID: 1114 ATTLEN: 8 ATTTYPMOD: -1 ATTNOTNULL: FALSE ATTHASDEF: FALSE COL8: timestamp without time zone COL9: NULL
-- ATTNUM: 15 ATTNAME: O ATTTYPID: 1184 ATTLEN: 8 ATTTYPMOD: -1 ATTNOTNULL: FALSE ATTHASDEF: FALSE COL8: timestamp with time zone COL9: NULL
-- ATTNUM: 16 ATTNAME: P ATTTYPID: 25 ATTLEN: -1 ATTTYPMOD: -1 ATTNOTNULL: FALSE ATTHASDEF: FALSE COL8: text COL9: NULL
-- ATTNUM: 17 ATTNAME: Q ATTTYPID: 1043 ATTLEN: -1 ATTTYPMOD: 10485764 ATTNOTNULL: FALSE ATTHASDEF: FALSE COL8: character varying(10485760) COL9: NULL

-- # format_type() of NULL is NULL, and an unknown type is "???".
/* postgresql */
VALUES (format_type(CAST(NULL AS INTEGER), -1), format_type(23, CAST(NULL AS INTEGER)), format_type(0, -1));
-- COL1: NULL COL2: integer COL3: ???

-- # The only user, tablespace, encoding, collation, index access method and
-- # languages.
/* postgresql */
SELECT oid, rolname, rolsuper, rolcanlogin FROM pg_roles;
SELECT oid, spcname, spcowner FROM pg_tablespace;
SELECT contoencoding, pg_encoding_to_char(contoencoding) FROM pg_conversion;
SELECT oid, collname FROM pg_collation;
SELECT oid, amname FROM pg_am;
SELECT oid, lanname, lanpltrusted FROM pg_language;
-- OID: 10 ROLNAME: vsql ROLSUPER: TRUE ROLCANLOGIN: TRUE
-- OID: 1663 SPCNAME: pg_default SPCOWNER: 10
-- CONTOENCODING: 6 COL2: UTF8
-- OID: 100 COLLNAME: default
-- OID: 403 AMNAME: btree
-- OID: 12 LANNAME: internal LANPLTRUSTED: FALSE
-- OID: 13 LANNAME: c LANPLTRUSTED: FALSE
-- OID: 14 LANNAME: sql LANPLTRUSTED: TRUE

-- # pg_settings has the run-time parameters that are reported when a client
-- # connects, and the search_path.
/* postgresql */
SELECT name, setting, reset_val FROM pg_settings;
-- NAME: server_version SETTING: 9.3.10 RESET_VAL: 9.3.10
-- NAME: server_encoding SETTING: UTF8 RESET_VAL: UTF8
-- NAME: client_encoding SETTING: UTF8 RESET_VAL: UTF8
-- NAME: DateStyle SETTING: ISO, MDY RESET_VAL: ISO, MDY
-- NAME: TimeZone SETTING: UTC RESET_VAL: UTC
-- NAME: integer_datetimes SETTING: on RESET_VAL: on
-- NAME: standard_conforming_strings SETTING: on RESET_VAL: on
-- NAME: is_superuser SETTING: on RESET_VAL: on
-- NAME: session_authorization SETTING: vsql RESET_VAL: vsql
-- NAME: search_path SETTING: PUBLIC RESET_VAL: PUBLIC

-- # A classoid (of a comment) is the name of the table, which is what a
-- # regclass is cast to.
/* postgresql */
SELECT n.nspname, d.description FROM pg_namespace n LEFT JOIN pg_description d ON d.objoid = n.oid AND d.objsubid = 0 AND d.classoid = CAST('pg_namespace' AS VARCHAR(255)) WHERE n.nspname = 'PUBLIC';
-- NSPNAME: PUBLIC DESCRIPTION: NULL
