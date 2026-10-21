/* types */
VALUES version();
-- COL1: PostgreSQL 9.3.10 on x86_64-unknown-linux-gnu, compiled by gcc (Ubuntu 4.8.2-19ubuntu1) 4.8.2, 64-bit (CHARACTER VARYING)

/* types */
VALUES current_setting('server_version_num');
-- COL1: 90310 (CHARACTER VARYING)

/* types */
SELECT * FROM (VALUES current_setting('server_version_num')) AS t1 (ver_num);
-- VER_NUM: 90310 (CHARACTER VARYING)

-- # pg_database is a virtual table that's registered for PostgreSQL clients.
SELECT * FROM pg_database;
-- DATNAME: vsql

EXPLAIN SELECT datname FROM pg_database;
-- EXPLAIN: VIRTUAL TABLE PUBLIC.PG_DATABASE (DATNAME CHARACTER VARYING(255))
-- EXPLAIN: EXPR (DATNAME CHARACTER VARYING(255))
