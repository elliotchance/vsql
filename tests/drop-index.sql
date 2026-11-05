-- # DROP INDEX is a vsql extension (V003-01). An index is also dropped with its
-- # table, and ALTER TABLE keeps the indexes of the table up to date.

/* setup */
CREATE TABLE t (id INT PRIMARY KEY, x VARCHAR(10), y INT);
INSERT INTO t (id, x, y) VALUES (1, 'b', 5), (2, 'a', NULL), (3, 'c', 1);

/* extensions V002-01 V003-01 */
/* flags */
CREATE INDEX t_x ON t (x);
DROP INDEX t_x;
-- flags: V002-01
-- msg: CREATE INDEX 1
-- flags: V003-01
-- msg: DROP INDEX 1

/* extensions V002-01 V003-01 */
CREATE INDEX t_x ON t (x);
DROP INDEX public.t_x;
CREATE INDEX t_x ON t (y);
INSERT INTO t (id, x, y) VALUES (4, 'd', 4);
-- msg: CREATE INDEX 1
-- msg: DROP INDEX 1
-- msg: CREATE INDEX 1
-- msg: INSERT 1

/* extensions V003-01 */
DROP INDEX t_x;
-- error 42704: no such index: ":memory:".PUBLIC.T_X

-- # A table isn't an index.
/* extensions V003-01 */
DROP INDEX t;
-- error 42704: no such index: ":memory:".PUBLIC.T

/* extensions V002-01 V003-01 */
CREATE SCHEMA other;
CREATE INDEX t_x ON t (x);
DROP INDEX other.t_x;
-- msg: CREATE SCHEMA 1
-- msg: CREATE INDEX 1
-- error 42704: no such index: ":memory:".OTHER.T_X

/* extensions V003-01 */
DROP INDEX nosuch.t_x;
-- error 3F000: invalid schema name: NOSUCH

/* extensions V003-01 */
EXPLAIN DROP INDEX t_x;
-- error 42601: syntax error: Cannot EXPLAIN DROP INDEX

-- # A dropped index is put back by a ROLLBACK.
/* extensions V002-01 V003-01 */
CREATE INDEX t_x ON t (x);
START TRANSACTION;
DROP INDEX t_x;
INSERT INTO t (id, x) VALUES (4, 'd');
ROLLBACK;
INSERT INTO t (id, x) VALUES (5, 'e');
DROP INDEX t_x;
-- msg: CREATE INDEX 1
-- msg: START TRANSACTION
-- msg: DROP INDEX 1
-- msg: INSERT 1
-- msg: ROLLBACK
-- msg: INSERT 1
-- msg: DROP INDEX 1

-- # DROP TABLE drops the indexes of the table.
/* extensions V002-01 */
CREATE INDEX t_x ON t (x);
CREATE INDEX t_y ON t (y);
DROP TABLE t RESTRICT;
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
CREATE INDEX t_x ON t (x);
-- msg: CREATE INDEX 1
-- msg: CREATE INDEX 1
-- msg: DROP TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: CREATE INDEX 1

/* extensions V002-01 */
CREATE INDEX t_x ON t (x);
START TRANSACTION;
DROP TABLE t RESTRICT;
ROLLBACK;
INSERT INTO t (id, x) VALUES (4, 'd');
CREATE INDEX t_x ON t (x);
-- msg: CREATE INDEX 1
-- msg: START TRANSACTION
-- msg: DROP TABLE 1
-- msg: ROLLBACK
-- msg: INSERT 1
-- error 42P07: duplicate index: ":memory:".PUBLIC.T_X

/* extensions V002-01 */
CREATE SCHEMA other;
CREATE TABLE other.t (x INT);
CREATE INDEX t_x ON other.t (x);
DROP SCHEMA other CASCADE;
CREATE SCHEMA other;
CREATE TABLE other.t (x INT);
CREATE INDEX t_x ON other.t (x);
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: CREATE INDEX 1
-- msg: DROP SCHEMA 1
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: CREATE INDEX 1

-- # A column that's in an index can only be dropped with CASCADE, which drops
-- # the index.
/* extensions V002-01 */
CREATE INDEX t_xy ON t (x, y);
ALTER TABLE t DROP COLUMN y RESTRICT;
-- msg: CREATE INDEX 1
-- error 2BP01: dependent objects still exist on index ":memory:".PUBLIC.T_XY

/* extensions V002-01 */
CREATE INDEX t_y ON t (y);
CREATE INDEX t_xy ON t (x, y);
CREATE INDEX t_x ON t (x);
ALTER TABLE t DROP COLUMN y CASCADE;
CREATE INDEX t_y ON t (x);
CREATE INDEX t_xy ON t (x);
CREATE INDEX t_x ON t (x);
SELECT * FROM t;
-- msg: CREATE INDEX 1
-- msg: CREATE INDEX 1
-- msg: CREATE INDEX 1
-- msg: ALTER TABLE 1
-- msg: CREATE INDEX 1
-- msg: CREATE INDEX 1
-- error 42P07: duplicate index: ":memory:".PUBLIC.T_X
-- ID: 1 X: b
-- ID: 2 X: a
-- ID: 3 X: c

-- # A generated column that's dropped with the column drops its indexes too.
/* extensions V002-01 */
ALTER TABLE t ADD COLUMN z INT GENERATED ALWAYS AS (y * 2);
CREATE INDEX t_z ON t (z);
ALTER TABLE t DROP COLUMN y CASCADE;
CREATE INDEX t_z ON t (x);
-- msg: ALTER TABLE 1
-- msg: CREATE INDEX 1
-- msg: ALTER TABLE 1
-- msg: CREATE INDEX 1

-- # The other columns are written again when a column is dropped.
/* extensions V002-01 */
CREATE INDEX t_x ON t (x DESC, id);
ALTER TABLE t DROP COLUMN y RESTRICT;
INSERT INTO t (id, x) VALUES (4, 'd');
SELECT * FROM t;
-- msg: CREATE INDEX 1
-- msg: ALTER TABLE 1
-- msg: INSERT 1
-- ID: 1 X: b
-- ID: 2 X: a
-- ID: 3 X: c
-- ID: 4 X: d

-- # Every row gets a new row ID when the PRIMARY KEY is dropped or added.
/* extensions V002-01 */
CREATE INDEX t_x ON t (x);
ALTER TABLE t DROP CONSTRAINT t_primary_key RESTRICT;
INSERT INTO t (id, x) VALUES (4, 'd');
ALTER TABLE t ADD PRIMARY KEY (x);
UPDATE t SET x = 'z' WHERE id = 1;
SELECT * FROM t;
-- msg: CREATE INDEX 1
-- msg: ALTER TABLE 1
-- msg: INSERT 1
-- msg: ALTER TABLE 1
-- msg: UPDATE 1
-- ID: 2 X: a Y: NULL
-- ID: 3 X: c Y: 1
-- ID: 4 X: d Y: NULL
-- ID: 1 X: z Y: 5

-- # A new column with a DEFAULT writes every row again, but they keep their
-- # entries.
/* extensions V002-01 */
CREATE INDEX t_x ON t (x);
ALTER TABLE t ADD COLUMN z INT DEFAULT 7;
ALTER TABLE t ADD COLUMN w INT DEFAULT 8 NOT NULL;
ALTER TABLE t ADD CONSTRAINT y_positive CHECK (y > 0);
ALTER TABLE t ALTER COLUMN z SET DEFAULT 9;
UPDATE t SET z = 1;
SELECT * FROM t;
-- msg: CREATE INDEX 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: UPDATE 3
-- ID: 1 X: b Y: 5 Z: 1 W: 8
-- ID: 2 X: a Y: NULL Z: 1 W: 8
-- ID: 3 X: c Y: 1 Z: 1 W: 8

-- # An index on the new column.
/* extensions V002-01 */
ALTER TABLE t ADD COLUMN z INT GENERATED ALWAYS AS IDENTITY;
CREATE INDEX t_z ON t (z DESC);
ALTER TABLE t DROP COLUMN z CASCADE;
-- msg: ALTER TABLE 1
-- msg: CREATE INDEX 1
-- msg: ALTER TABLE 1
