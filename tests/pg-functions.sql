/* types */
VALUES version();
-- COL1: PostgreSQL 9.3.10 on x86_64-unknown-linux-gnu, compiled by gcc (Ubuntu 4.8.2-19ubuntu1) 4.8.2, 64-bit (CHARACTER VARYING(101))

/* types */
VALUES current_setting('server_version_num');
-- COL1: 90310 (CHARACTER VARYING(5))

/* types */
SELECT * FROM (VALUES current_setting('server_version_num')) AS t1 (ver_num);
-- VER_NUM: 90310 (CHARACTER VARYING(5))
