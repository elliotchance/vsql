VALUES version();
-- COL1: PostgreSQL 9.3.10 on x86_64-unknown-linux-gnu, compiled by gcc (Ubuntu 4.8.2-19ubuntu1) 4.8.2, 64-bit

VALUES current_setting('server_version_num');
-- COL1: 90310

SELECT * FROM (VALUES current_setting('server_version_num')) AS t1 (ver_num);
-- VER_NUM: 90310
