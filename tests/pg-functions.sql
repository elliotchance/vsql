/* setup */
CREATE TABLE singlerow (x INT);
INSERT INTO singlerow (x) VALUES (0);

SELECT version() FROM singlerow;
-- COL1: PostgreSQL 9.3.10 on x86_64-unknown-linux-gnu, compiled by gcc (Ubuntu 4.8.2-19ubuntu1) 4.8.2, 64-bit

SELECT current_setting('server_version_num') as ver_num FROM singlerow;
-- VER_NUM: 90310
