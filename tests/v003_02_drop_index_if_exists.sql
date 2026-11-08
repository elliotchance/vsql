-- # DROP INDEX IF EXISTS is a vsql extension (V003-02), like the other IF
-- # EXISTS (see v104_02_drop_table_if_exists.sql).

/* setup */
CREATE TABLE t (id INT PRIMARY KEY, x INT, y INT);
INSERT INTO t (id, x, y) VALUES (1, 10, 100), (2, 20, 200);

/* flags */
/* extensions V003-01 V003-02 */
DROP INDEX IF EXISTS t_x;
-- flags: V003-01, V003-02
-- msg: DROP INDEX 0

/* extensions V002-01 V003-01 V003-02 */
CREATE INDEX t_x ON t (x);
DROP INDEX IF EXISTS t_x;
DROP INDEX IF EXISTS t_x;
DROP INDEX t_x;
-- msg: CREATE INDEX 1
-- msg: DROP INDEX 1
-- msg: DROP INDEX 0
-- error 42704: no such index: ":memory:".PUBLIC.T_X

-- # An index in a schema that doesn't exist doesn't exist.
/* extensions V003-01 V003-02 */
DROP INDEX IF EXISTS nosuch.t_x;
-- msg: DROP INDEX 0

/* extensions V003-01 V003-02 */
DROP INDEX IF EXISTS nosuch.public.t_x;
-- error 3D000: invalid catalog name: NOSUCH

/* extensions V003-01 V003-02 */
DROP INDEX IF EXISTS information_schema.t_x;
-- msg: DROP INDEX 0

/* extensions V002-01 V003-01 V003-02 */
CREATE SCHEMA other;
CREATE TABLE other.t (x INT);
CREATE INDEX t_x ON other.t (x);
DROP INDEX IF EXISTS t_x;
DROP INDEX IF EXISTS other.t_x;
DROP INDEX IF EXISTS other.t_x;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: CREATE INDEX 1
-- msg: DROP INDEX 0
-- msg: DROP INDEX 1
-- msg: DROP INDEX 0

-- # A table isn't an index.
/* extensions V003-01 V003-02 */
DROP INDEX IF EXISTS t;
SELECT * FROM t;
-- msg: DROP INDEX 0
-- ID: 1 X: 10 Y: 100
-- ID: 2 X: 20 Y: 200

-- # A dropped index is put back by a ROLLBACK.
/* extensions V002-01 V003-01 V003-02 */
CREATE INDEX t_x ON t (x);
START TRANSACTION;
DROP INDEX IF EXISTS t_x;
DROP INDEX IF EXISTS t_x;
ROLLBACK;
DROP INDEX IF EXISTS t_x;
-- msg: CREATE INDEX 1
-- msg: START TRANSACTION
-- msg: DROP INDEX 1
-- msg: DROP INDEX 0
-- msg: ROLLBACK
-- msg: DROP INDEX 1

DROP INDEX IF NOT EXISTS t_x;
-- error 42601: syntax error: unexpected NOT

/* extensions V003-01 V003-02 */
EXPLAIN DROP INDEX IF EXISTS t_x;
-- error 42601: syntax error: Cannot EXPLAIN DROP INDEX

-- # IF is a non-reserved word, so it can still be the name of an index.
/* extensions V002-01 V002-03 V003-01 V003-02 */
CREATE INDEX if ON t (x);
CREATE INDEX IF NOT EXISTS if ON t (x);
DROP INDEX if;
DROP INDEX IF EXISTS if;
-- msg: CREATE INDEX 1
-- msg: CREATE INDEX 0
-- msg: DROP INDEX 1
-- msg: DROP INDEX 0
