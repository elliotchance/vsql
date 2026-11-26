-- # version() and current_setting() are registered for PostgreSQL clients,
-- # which check the version of the server. They return a fixed PostgreSQL
-- # 9.3.10 version (as VARCHAR), whatever the setting.
/* postgresql */
/* types */
VALUES version();
-- COL1: PostgreSQL 9.3.10 on x86_64-unknown-linux-gnu, compiled by gcc (Ubuntu 4.8.2-19ubuntu1) 4.8.2, 64-bit (CHARACTER VARYING)

/* postgresql */
/* types */
VALUES current_setting('server_version_num');
-- COL1: 90310 (CHARACTER VARYING)

/* postgresql */
/* types */
SELECT * FROM (VALUES current_setting('server_version_num')) AS t1 (ver_num);
-- VER_NUM: 90310 (CHARACTER VARYING)

-- # pg_database is a virtual table that's registered for PostgreSQL clients.
-- # The only database has the name that the client connected with, which is
-- # also the current_database().
/* postgresql */
SELECT oid, datname = current_database(), datdba, encoding, datistemplate, datallowconn, dattablespace FROM pg_database;
-- OID: 13000 COL2: TRUE DATDBA: 10 ENCODING: 6 DATISTEMPLATE: FALSE DATALLOWCONN: TRUE DATTABLESPACE: 1663

/* postgresql */
/* extensions V001-01 */
EXPLAIN SELECT datname FROM pg_database;
-- EXPLAIN: VIRTUAL TABLE PUBLIC.PG_DATABASE (OID INTEGER, DATNAME CHARACTER VARYING(255), DATDBA INTEGER, ENCODING INTEGER, DATCOLLATE CHARACTER VARYING(255), DATCTYPE CHARACTER VARYING(255), DATISTEMPLATE BOOLEAN, DATALLOWCONN BOOLEAN, DATCONNLIMIT INTEGER, DATLASTSYSOID INTEGER, DATFROZENXID INTEGER, DATMINMXID INTEGER, DATTABLESPACE INTEGER, DATACL CHARACTER VARYING(255))
-- EXPLAIN: EXPR (DATNAME CHARACTER VARYING(255))
