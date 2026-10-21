-- # A "virtual_table" directive registers a virtual table, which has its rows
-- # provided when it's read (see docs/virtual-tables.rst).
/* virtual_table CREATE TABLE fruits (id INT, name VARCHAR(10)) AS VALUES ROW(1, 'kiwi'), ROW(2, 'pear') */
SELECT * FROM fruits;
EXPLAIN SELECT * FROM fruits;
-- ID: 1 NAME: kiwi
-- ID: 2 NAME: pear
-- EXPLAIN: VIRTUAL TABLE PUBLIC.FRUITS (ID INTEGER, NAME CHARACTER VARYING(10))
-- EXPLAIN: EXPR (ID INTEGER, NAME CHARACTER VARYING(10))

/* virtual_table CREATE TABLE fruits (id INT, name VARCHAR(10)) AS VALUES ROW(1, 'kiwi'), ROW(2, 'pear'), ROW(3, 'plum') */
SELECT name FROM fruits WHERE id > 1 ORDER BY name DESC;
-- NAME: plum
-- NAME: pear

-- # Each SELECT reads the rows again.
/* virtual_table CREATE TABLE fruits (id INT, name VARCHAR(10)) AS VALUES ROW(1, 'kiwi'), ROW(2, 'pear') */
SELECT COUNT(*) AS c FROM fruits;
SELECT COUNT(*) AS c FROM fruits;
-- C: 2
-- C: 2

-- # A virtual table without any rows.
/* virtual_table CREATE TABLE nothing (x INT) AS SELECT * FROM (VALUES 1) AS t (x) WHERE x > 1 */
SELECT * FROM nothing;
SELECT COUNT(*) AS c FROM nothing;
-- C: 0

-- # Any type, and NULL.
/* virtual_table CREATE TABLE t (a INT, b VARCHAR(20), c DOUBLE PRECISION, d BOOLEAN, e DATE) AS VALUES ROW(1, 'x', 1.5e0, TRUE, DATE '2022-06-30'), ROW(CAST(NULL AS INT), CAST(NULL AS VARCHAR(20)), CAST(NULL AS DOUBLE PRECISION), CAST(NULL AS BOOLEAN), CAST(NULL AS DATE)) */
SELECT * FROM t;
-- A: 1 B: x C: 1.5e0 D: TRUE E: 2022-06-30
-- A: NULL B: NULL C: NULL D: UNKNOWN E: NULL

-- # A virtual table can be joined with a real table.
/* virtual_table CREATE TABLE fruits (id INT, name VARCHAR(10)) AS VALUES ROW(1, 'kiwi'), ROW(2, 'pear') */
CREATE TABLE prices (fruit_id INT, price INT);
INSERT INTO prices (fruit_id, price) VALUES (1, 30), (2, 45);
SELECT name, price FROM fruits JOIN prices ON id = fruit_id ORDER BY price DESC;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- NAME: pear PRICE: 45
-- NAME: kiwi PRICE: 30

/* virtual_table CREATE TABLE fruits (id INT, name VARCHAR(10)) AS VALUES ROW(1, 'kiwi'), ROW(2, 'pear') */
SELECT * FROM (SELECT name FROM fruits WHERE id = 2) AS t;
-- NAME: pear

-- # It can be in a schema other than PUBLIC.
CREATE SCHEMA s;
/* virtual_table CREATE TABLE s.t (x INT) AS VALUES 1 */
SELECT * FROM s.t;
-- msg: CREATE SCHEMA 1
-- X: 1

-- # The schema must exist.
/* virtual_table CREATE TABLE nope.t (x INT) AS VALUES 1 */
SELECT * FROM nope.t;
-- error 3F000: invalid schema name: NOPE
-- error 3F000: invalid schema name: NOPE

-- # Only a CREATE TABLE can be registered.
/* virtual_table VALUES (1) AS VALUES 1 */
-- error 00000: must provide a CREATE TABLE statement

-- # A virtual table can only be read.
/* virtual_table CREATE TABLE fruits (id INT, name VARCHAR(10)) AS VALUES ROW(1, 'kiwi') */
INSERT INTO fruits (id, name) VALUES (2, 'pear');
UPDATE fruits SET name = 'pear';
DELETE FROM fruits;
DROP TABLE fruits;
SELECT * FROM fruits;
-- error 42P01: no such table: ":memory:".PUBLIC.FRUITS
-- error 42P01: no such table: ":memory:".PUBLIC.FRUITS
-- error 42P01: no such table: ":memory:".PUBLIC.FRUITS
-- error 42P01: no such table: ":memory:".PUBLIC.FRUITS
-- ID: 1 NAME: kiwi
