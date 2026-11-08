-- # CREATE INDEX is a vsql extension (V002-01). After each test, every index is
-- # checked against the rows of its table (see check_indexes), so these tests
-- # change the rows in different ways after the index is created.

/* setup */
CREATE TABLE t (id INT PRIMARY KEY, x VARCHAR(10), y INT);
INSERT INTO t (id, x, y) VALUES (1, 'b', 5), (2, 'a', NULL), (3, 'c', 1);

/* extensions V002-01 */
/* flags */
CREATE INDEX t_x ON t (x);
-- flags: V002-01
-- msg: CREATE INDEX 1

/* extensions V002-01 */
CREATE INDEX t_x ON t (x ASC, y DESC);
INSERT INTO t (id, x, y) VALUES (4, 'b', 2), (5, NULL, NULL);
UPDATE t SET x = 'z' WHERE id = 1;
UPDATE t SET y = y + 1;
DELETE FROM t WHERE id = 2;
SELECT * FROM t;
-- msg: CREATE INDEX 1
-- msg: INSERT 2
-- msg: UPDATE 1
-- msg: UPDATE 5
-- msg: DELETE 1
-- ID: 1 X: z Y: 6
-- ID: 3 X: c Y: 2
-- ID: 4 X: b Y: 3
-- ID: 5 X: NULL Y: NULL

-- # A table can have more than one index, including on the same columns.
/* extensions V002-01 */
CREATE INDEX t_x ON t (x);
CREATE INDEX t_y ON t (y DESC);
CREATE INDEX t_x2 ON t (x);
DELETE FROM t;
-- msg: CREATE INDEX 1
-- msg: CREATE INDEX 1
-- msg: CREATE INDEX 1
-- msg: DELETE 3

-- # An empty table.
/* extensions V002-01 */
CREATE TABLE t2 (a INT);
CREATE INDEX t2_a ON t2 (a);
INSERT INTO t2 (a) VALUES (1), (1), (NULL);
SELECT * FROM t2;
-- msg: CREATE TABLE 1
-- msg: CREATE INDEX 1
-- msg: INSERT 3
-- A: 1
-- A: 1
-- A: NULL

-- # The name of an index is unique in its schema, but it can be the same as
-- # another kind of object, or an index in another schema.
/* extensions V002-01 */
CREATE INDEX t_x ON t (x);
CREATE INDEX t_x ON t (y);
-- msg: CREATE INDEX 1
-- error 42P07: duplicate index: ":memory:".PUBLIC.T_X

/* extensions V002-01 */
CREATE TABLE t2 (a INT);
CREATE INDEX t_x ON t (x);
CREATE INDEX t_x ON t2 (a);
-- msg: CREATE TABLE 1
-- msg: CREATE INDEX 1
-- error 42P07: duplicate index: ":memory:".PUBLIC.T_X

/* extensions V002-01 */
CREATE SEQUENCE s;
CREATE INDEX t ON t (x);
CREATE INDEX s ON t (y);
-- msg: CREATE SEQUENCE 1
-- msg: CREATE INDEX 1
-- msg: CREATE INDEX 1

/* extensions V002-01 V003-01 */
CREATE SCHEMA other;
CREATE TABLE other.t (x INT);
CREATE INDEX t_x ON t (x);
CREATE INDEX t_x ON other.t (x);
DROP INDEX other.t_x;
DROP INDEX t_x;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: CREATE INDEX 1
-- msg: CREATE INDEX 1
-- msg: DROP INDEX 1
-- msg: DROP INDEX 1

/* extensions V002-01 */
CREATE INDEX t_x ON nosuch (x);
-- error 42P01: no such table: ":memory:".PUBLIC.NOSUCH

/* extensions V002-01 */
CREATE INDEX t_x ON nosuch.t (x);
-- error 3F000: invalid schema name: NOSUCH

/* extensions V002-01 */
CREATE INDEX t_x ON information_schema.tables (table_name);
-- error 42501: insufficient privilege: INFORMATION_SCHEMA is read-only

/* extensions V002-01 */
CREATE INDEX t_x ON t (nosuch);
-- error 42703: no such column: NOSUCH

/* extensions V002-01 */
CREATE INDEX t_x ON t (x, y, x);
-- error 42601: syntax error: column X is in index ":memory:".PUBLIC.T_X more than once

-- # The name of the index can't be qualified, it's always in the schema of the
-- # table.
CREATE INDEX public.t_x ON t (x);
-- error 42601: syntax error: unexpected ".", expecting ON

/* extensions V002-01 */
EXPLAIN CREATE INDEX t_x ON t (x);
-- error 42601: syntax error: Cannot EXPLAIN CREATE INDEX

-- # A statement that fails doesn't create the index.
/* extensions V002-01 V003-01 */
CREATE TABLE t2 (x VARCHAR(200));
INSERT INTO t2 (x) VALUES ('this value is too long to be in the key of an index entry, because the key must fit in half of a page, which is 256 bytes in the tests');
CREATE INDEX t2_x ON t2 (x);
DROP INDEX t2_x;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 54000: the key of an object (184 bytes) is too long for a page of 256 bytes
-- error 42704: no such index: ":memory:".PUBLIC.T2_X

/* extensions V002-01 */
CREATE TABLE t2 (x VARCHAR(200));
CREATE INDEX t2_x ON t2 (x);
INSERT INTO t2 (x) VALUES ('short');
INSERT INTO t2 (x) VALUES ('this value is too long to be in the key of an index entry, because the key must fit in half of a page, which is 256 bytes in the tests');
UPDATE t2 SET x = 'this value is too long to be in the key of an index entry, because the key must fit in half of a page, which is 256 bytes in the tests';
SELECT * FROM t2;
-- msg: CREATE TABLE 1
-- msg: CREATE INDEX 1
-- msg: INSERT 1
-- error 54000: the key of an object (184 bytes) is too long for a page of 256 bytes
-- error 54000: the key of an object (184 bytes) is too long for a page of 256 bytes
-- X: short

-- # INDEX is a non-reserved word.
/* extensions V002-01 */
CREATE TABLE index (index INT);
CREATE INDEX index ON index (index);
INSERT INTO index (index) VALUES (1);
SELECT index FROM index;
-- msg: CREATE TABLE 1
-- msg: CREATE INDEX 1
-- msg: INSERT 1
-- INDEX: 1

-- # Every type that can be in a PRIMARY KEY can be in an index.
/* extensions V002-01 */
CREATE TABLE types (b BOOLEAN, s SMALLINT, i INTEGER, bi BIGINT, r REAL, d DOUBLE PRECISION, n NUMERIC(10, 2), de DECIMAL(5, 1), c CHAR(3), vc VARCHAR(5), dt DATE, tm TIME, tmz TIME WITH TIME ZONE, ts TIMESTAMP, tsz TIMESTAMP WITH TIME ZONE);
CREATE INDEX types_1 ON types (b, s, i, bi, r, d);
CREATE INDEX types_2 ON types (n, de, c, vc);
CREATE INDEX types_3 ON types (dt, tm, tmz, ts, tsz);
CREATE INDEX types_4 ON types (b DESC, s DESC, i DESC, bi DESC, r DESC, d DESC);
CREATE INDEX types_5 ON types (n DESC, de DESC, c DESC, vc DESC);
CREATE INDEX types_6 ON types (dt DESC, tm DESC, tmz DESC, ts DESC, tsz DESC);
INSERT INTO types VALUES (TRUE, 1, 2, 3, 1.5, -2.5, 12.34, -0.5, 'ab', 'a b', DATE '2022-07-04', TIME '12:34:56', TIME '12:34:56+05:00', TIMESTAMP '2022-07-04 12:34:56', TIMESTAMP '2022-07-04 12:34:56+05:00');
INSERT INTO types VALUES (FALSE, -1, -2, -3, -1.5, 0, 0, 0, '', '', DATE '2000-01-01', TIME '00:00:00', TIME '00:00:00-05:00', TIMESTAMP '2000-01-01 00:00:00', TIMESTAMP '2000-01-01 00:00:00-05:00');
INSERT INTO types (b) VALUES (NULL);
UPDATE types SET n = n + 1, tsz = TIMESTAMP '2001-01-01 00:00:00+00:00';
SELECT b, n FROM types;
-- msg: CREATE TABLE 1
-- msg: CREATE INDEX 1
-- msg: CREATE INDEX 1
-- msg: CREATE INDEX 1
-- msg: CREATE INDEX 1
-- msg: CREATE INDEX 1
-- msg: CREATE INDEX 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: UPDATE 3
-- B: TRUE N: 13.34
-- B: FALSE N: 1.00
-- B: UNKNOWN N: NULL

-- # A row that gets a new PRIMARY KEY moves, so its entries get the new row ID.
/* extensions V002-01 */
CREATE INDEX t_x ON t (x);
UPDATE t SET id = id + 10;
UPDATE t SET id = id - 10, x = 'q' WHERE id = 11;
SELECT * FROM t;
-- msg: CREATE INDEX 1
-- msg: UPDATE 3
-- msg: UPDATE 1
-- ID: 1 X: q Y: 5
-- ID: 12 X: a Y: NULL
-- ID: 13 X: c Y: 1

-- # A table without a PRIMARY KEY.
/* extensions V002-01 */
CREATE TABLE t2 (a INT, b INT);
INSERT INTO t2 (a, b) VALUES (1, 2), (1, 2), (3, 4);
CREATE INDEX t2_a ON t2 (a);
UPDATE t2 SET a = 5 WHERE b = 4;
UPDATE t2 SET b = 0 WHERE a = 1;
DELETE FROM t2 WHERE a = 1;
SELECT * FROM t2;
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- msg: CREATE INDEX 1
-- msg: UPDATE 1
-- msg: UPDATE 2
-- msg: DELETE 2
-- A: 5 B: 4

-- # The same row can change more than once in a transaction, back to an entry
-- # that it had before.
/* extensions V002-01 */
CREATE INDEX t_x ON t (x);
START TRANSACTION;
UPDATE t SET x = 'p' WHERE id = 1;
UPDATE t SET x = 'b' WHERE id = 1;
UPDATE t SET x = 'p' WHERE id = 1;
DELETE FROM t WHERE id = 2;
INSERT INTO t (id, x) VALUES (2, 'a');
COMMIT;
SELECT * FROM t;
-- msg: CREATE INDEX 1
-- msg: START TRANSACTION
-- msg: UPDATE 1
-- msg: UPDATE 1
-- msg: UPDATE 1
-- msg: DELETE 1
-- msg: INSERT 1
-- msg: COMMIT
-- ID: 1 X: p Y: 5
-- ID: 2 X: a Y: NULL
-- ID: 3 X: c Y: 1

/* extensions V002-01 */
CREATE INDEX t_x ON t (x);
START TRANSACTION;
UPDATE t SET x = 'p' WHERE id = 1;
UPDATE t SET x = 'b' WHERE id = 1;
INSERT INTO t (id, x) VALUES (4, 'd');
DELETE FROM t WHERE id = 3;
ROLLBACK;
SELECT * FROM t;
-- msg: CREATE INDEX 1
-- msg: START TRANSACTION
-- msg: UPDATE 1
-- msg: UPDATE 1
-- msg: INSERT 1
-- msg: DELETE 1
-- msg: ROLLBACK
-- ID: 1 X: b Y: 5
-- ID: 2 X: a Y: NULL
-- ID: 3 X: c Y: 1

-- # An index created in a transaction is rolled back with it.
/* extensions V002-01 V003-01 */
START TRANSACTION;
CREATE INDEX t_x ON t (x);
INSERT INTO t (id, x) VALUES (4, 'd');
ROLLBACK;
INSERT INTO t (id, x) VALUES (5, 'e');
DROP INDEX t_x;
-- msg: START TRANSACTION
-- msg: CREATE INDEX 1
-- msg: INSERT 1
-- msg: ROLLBACK
-- msg: INSERT 1
-- error 42704: no such index: ":memory:".PUBLIC.T_X

/* extensions V002-01 */
START TRANSACTION;
CREATE INDEX t_x ON t (x);
INSERT INTO t (id, x) VALUES (4, 'd');
COMMIT;
INSERT INTO t (id, x) VALUES (5, 'e');
CREATE INDEX t_x ON t (x);
-- msg: START TRANSACTION
-- msg: CREATE INDEX 1
-- msg: INSERT 1
-- msg: COMMIT
-- msg: INSERT 1
-- error 42P07: duplicate index: ":memory:".PUBLIC.T_X

-- # The changes of the transaction before the index is created are included.
/* extensions V002-01 */
START TRANSACTION;
INSERT INTO t (id, x) VALUES (4, 'd');
DELETE FROM t WHERE id = 1;
CREATE INDEX t_x ON t (x);
UPDATE t SET x = 'e' WHERE id = 4;
COMMIT;
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: DELETE 1
-- msg: CREATE INDEX 1
-- msg: UPDATE 1
-- msg: COMMIT

-- # A FOREIGN KEY action changes the rows of another table, and its indexes.
/* extensions V002-01 */
CREATE TABLE c (id INT PRIMARY KEY, p INT REFERENCES t (id) ON DELETE CASCADE ON UPDATE CASCADE);
INSERT INTO c (id, p) VALUES (10, 1), (20, 2), (30, 3);
CREATE INDEX c_p ON c (p);
UPDATE t SET id = 4 WHERE id = 1;
DELETE FROM t WHERE id = 2;
SELECT * FROM c;
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- msg: CREATE INDEX 1
-- msg: UPDATE 1
-- msg: DELETE 1
-- ID: 10 P: 4
-- ID: 30 P: 3

/* extensions V002-01 */
CREATE TABLE c (id INT PRIMARY KEY, p INT REFERENCES t (id) ON DELETE SET NULL);
INSERT INTO c (id, p) VALUES (10, 1), (20, 2);
CREATE INDEX c_p ON c (p DESC);
DELETE FROM t WHERE id = 2;
SELECT * FROM c;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: CREATE INDEX 1
-- msg: DELETE 1
-- ID: 10 P: 1
-- ID: 20 P: NULL
