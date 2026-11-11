-- # CREATE INDEX IF NOT EXISTS is a vsql extension (V002-03), like the other
-- # IF NOT EXISTS (see v103_01_create_table_if_not_exists.sql).

/* setup */
CREATE TABLE t (id INT PRIMARY KEY, x INT, y INT);
INSERT INTO t (id, x, y) VALUES (1, 10, 100), (2, 20, 200);

-- # CREATE INDEX IF NOT EXISTS

/* flags */
/* extensions V002-01 V002-03 */
CREATE INDEX IF NOT EXISTS t_x ON t (x);
-- flags: V002-01, V002-03
-- msg: CREATE INDEX 1

/* extensions V001-01 V002-01 V002-03 */
CREATE INDEX IF NOT EXISTS t_x ON t (x);
EXPLAIN SELECT * FROM t WHERE x = 10;
SELECT * FROM t WHERE x = 10;
-- msg: CREATE INDEX 1
-- EXPLAIN: INDEX ":memory:".PUBLIC.T_X ON ":memory:".PUBLIC.T (ID INTEGER NOT NULL, X INTEGER, Y INTEGER) RANGE X = 10
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.ID INTEGER NOT NULL, ":memory:".PUBLIC.T.X INTEGER, ":memory:".PUBLIC.T.Y INTEGER)
-- ID: 1 X: 10 Y: 100

-- # The existing index is kept: the new definition isn't compared with it, or
-- # checked.
/* extensions V001-01 V002-01 V002-03 */
CREATE INDEX t_x ON t (x);
CREATE INDEX IF NOT EXISTS t_x ON t (y);
CREATE INDEX IF NOT EXISTS t_x ON t (nosuch, nosuch);
EXPLAIN SELECT * FROM t WHERE y = 100;
EXPLAIN SELECT * FROM t WHERE x = 10;
-- msg: CREATE INDEX 1
-- msg: CREATE INDEX 0
-- msg: CREATE INDEX 0
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (ID INTEGER NOT NULL, X INTEGER, Y INTEGER)
-- EXPLAIN: WHERE Y = 100
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.ID INTEGER NOT NULL, ":memory:".PUBLIC.T.X INTEGER, ":memory:".PUBLIC.T.Y INTEGER)
-- EXPLAIN: INDEX ":memory:".PUBLIC.T_X ON ":memory:".PUBLIC.T (ID INTEGER NOT NULL, X INTEGER, Y INTEGER) RANGE X = 10
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.ID INTEGER NOT NULL, ":memory:".PUBLIC.T.X INTEGER, ":memory:".PUBLIC.T.Y INTEGER)

/* extensions V002-01 */
CREATE INDEX t_x ON t (x);
CREATE INDEX t_x ON t (y);
-- msg: CREATE INDEX 1
-- error 42P07: duplicate index: ":memory:".PUBLIC.T_X

-- # The table must still exist, because the index is in its schema.
/* extensions V002-01 V002-03 */
CREATE INDEX IF NOT EXISTS t_x ON nosuch (x);
-- error 42P01: no such table: ":memory:".PUBLIC.NOSUCH

/* extensions V002-01 V002-03 */
CREATE INDEX IF NOT EXISTS t_x ON nosuch.t (x);
-- error 3F000: invalid schema name: NOSUCH

/* extensions V002-01 V002-03 */
CREATE INDEX IF NOT EXISTS t_x ON information_schema.tables (table_name);
-- error 42501: insufficient privilege: INFORMATION_SCHEMA is read-only

-- # Only an index counts, not a table (or an index in another schema).
/* extensions V002-01 V002-03 V003-01 */
CREATE SCHEMA other;
CREATE TABLE other.t (x INT);
CREATE INDEX t_x ON other.t (x);
CREATE INDEX IF NOT EXISTS t ON t (x);
CREATE INDEX IF NOT EXISTS t_x ON t (x);
DROP INDEX t;
DROP INDEX t_x;
DROP INDEX other.t_x;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: CREATE INDEX 1
-- msg: CREATE INDEX 1
-- msg: CREATE INDEX 1
-- msg: DROP INDEX 1
-- msg: DROP INDEX 1
-- msg: DROP INDEX 1

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

CREATE INDEX IF EXISTS t_x ON t (x);
-- error 42601: syntax error: unexpected EXISTS at line 1, column 17 near "CREATE INDEX IF EXISTS t_x", expecting ON

-- # CREATE UNIQUE INDEX IF NOT EXISTS

/* flags */
/* extensions V002-01 V002-02 V002-03 */
CREATE UNIQUE INDEX IF NOT EXISTS t_x ON t (x);
-- flags: V002-01, V002-02, V002-03
-- msg: CREATE INDEX 1

/* extensions V002-01 V002-02 V002-03 */
CREATE UNIQUE INDEX IF NOT EXISTS t_x ON t (x);
INSERT INTO t (id, x) VALUES (3, 10);
-- msg: CREATE INDEX 1
-- error 23505: violates unique constraint: UNIQUE INDEX T_X on ":memory:".PUBLIC.T

-- # An existing index that isn't UNIQUE stays that way.
/* extensions V002-01 V002-02 V002-03 */
CREATE INDEX t_x ON t (x);
CREATE UNIQUE INDEX IF NOT EXISTS t_x ON t (x);
INSERT INTO t (id, x) VALUES (3, 10);
SELECT * FROM t WHERE x = 10;
-- msg: CREATE INDEX 1
-- msg: CREATE INDEX 0
-- msg: INSERT 1
-- ID: 1 X: 10 Y: 100
-- ID: 3 X: 10 Y: NULL

-- # The rows aren't checked either.
/* extensions V002-01 V002-02 V002-03 */
CREATE INDEX t_y ON t (y);
INSERT INTO t (id, y) VALUES (3, 100);
CREATE UNIQUE INDEX IF NOT EXISTS t_y ON t (y);
CREATE UNIQUE INDEX IF NOT EXISTS t_y2 ON t (y);
-- msg: CREATE INDEX 1
-- msg: INSERT 1
-- msg: CREATE INDEX 0
-- error 23505: violates unique constraint: UNIQUE INDEX T_Y2 on ":memory:".PUBLIC.T
