-- # An index is used to find rows in the same way as the PRIMARY KEY (see
-- # impl_planner_primary_key_range.sql). Rows are read in the order of the
-- # index. The WHERE clause is still applied to them, except for what the range
-- # covers (see impl_planner_covered_filter.sql).

/* setup */
CREATE TABLE t (id INT PRIMARY KEY, x VARCHAR(10), y INT);
INSERT INTO t (id, x, y) VALUES (1, 'b', 5), (2, 'a', NULL), (3, 'c', 1), (4, 'b', 2), (5, NULL, 3), (6, 'a b', 4);

/* extensions V001-01 V002-01 */
CREATE INDEX t_x ON t (x);
EXPLAIN SELECT * FROM t WHERE x = 'b';
-- msg: CREATE INDEX 1
-- EXPLAIN: INDEX ":memory:".PUBLIC.T_X ON ":memory:".PUBLIC.T (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER) RANGE X = 'b'
-- EXPLAIN: WHERE X = 'b'
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.ID INTEGER NOT NULL, ":memory:".PUBLIC.T.X CHARACTER VARYING(10), ":memory:".PUBLIC.T.Y INTEGER)

/* extensions V002-01 */
CREATE INDEX t_x ON t (x);
SELECT * FROM t WHERE x = 'b';
SELECT * FROM t WHERE x > 'a';
SELECT * FROM t WHERE 'b' >= x;
SELECT * FROM t WHERE x BETWEEN 'a' AND 'b';
SELECT * FROM t WHERE x < 'zz' AND x <> 'b';
-- msg: CREATE INDEX 1
-- ID: 1 X: b Y: 5
-- ID: 4 X: b Y: 2
-- ID: 6 X: a b Y: 4
-- ID: 1 X: b Y: 5
-- ID: 4 X: b Y: 2
-- ID: 3 X: c Y: 1
-- ID: 2 X: a Y: NULL
-- ID: 6 X: a b Y: 4
-- ID: 1 X: b Y: 5
-- ID: 4 X: b Y: 2
-- ID: 2 X: a Y: NULL
-- ID: 6 X: a b Y: 4
-- ID: 1 X: b Y: 5
-- ID: 4 X: b Y: 2
-- ID: 2 X: a Y: NULL
-- ID: 6 X: a b Y: 4
-- ID: 3 X: c Y: 1

-- # A DESC column has the largest values first. NULL is never in a range.
/* extensions V002-01 */
CREATE INDEX t_y ON t (y DESC);
SELECT * FROM t WHERE y > 2;
SELECT * FROM t WHERE y <= 2;
SELECT * FROM t WHERE y BETWEEN 2 AND 4;
SELECT * FROM t WHERE y = 4;
-- msg: CREATE INDEX 1
-- ID: 1 X: b Y: 5
-- ID: 6 X: a b Y: 4
-- ID: 5 X: NULL Y: 3
-- ID: 4 X: b Y: 2
-- ID: 3 X: c Y: 1
-- ID: 6 X: a b Y: 4
-- ID: 5 X: NULL Y: 3
-- ID: 4 X: b Y: 2
-- ID: 6 X: a b Y: 4

/* extensions V002-01 */
CREATE INDEX t_y ON t (y);
SELECT * FROM t WHERE y < 3;
SELECT * FROM t WHERE y IS NULL;
-- msg: CREATE INDEX 1
-- ID: 3 X: c Y: 1
-- ID: 4 X: b Y: 2
-- ID: 2 X: a Y: NULL

-- # A value that the column can't hold exactly, or NULL, isn't used for the
-- # range, but the WHERE clause is still applied.
/* extensions V002-01 */
CREATE INDEX t_y ON t (y);
SELECT * FROM t WHERE y = 1.5;
SELECT * FROM t WHERE y > 1.5 AND y < 3;
SELECT * FROM t WHERE y = CAST(NULL AS INT);
SELECT * FROM t WHERE y < 100000000000;
-- msg: CREATE INDEX 1
-- ID: 4 X: b Y: 2
-- ID: 3 X: c Y: 1
-- ID: 4 X: b Y: 2
-- ID: 5 X: NULL Y: 3
-- ID: 6 X: a b Y: 4
-- ID: 1 X: b Y: 5

-- # Each leading column compared with = narrows the range, then a range of the
-- # next column. A condition on a later column alone can't use the index.
/* extensions V001-01 V002-01 */
CREATE INDEX t_xy ON t (x, y DESC);
EXPLAIN SELECT * FROM t WHERE y = 2;
SELECT * FROM t WHERE x = 'b' AND y = 2;
SELECT * FROM t WHERE x = 'b' AND y < 5;
SELECT * FROM t WHERE x = 'b' AND y >= 0;
SELECT * FROM t WHERE x > 'a' AND y = 2;
-- msg: CREATE INDEX 1
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER)
-- EXPLAIN: WHERE Y = 2
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.ID INTEGER NOT NULL, ":memory:".PUBLIC.T.X CHARACTER VARYING(10), ":memory:".PUBLIC.T.Y INTEGER)
-- ID: 4 X: b Y: 2
-- ID: 4 X: b Y: 2
-- ID: 1 X: b Y: 5
-- ID: 4 X: b Y: 2
-- ID: 4 X: b Y: 2

-- # The PRIMARY KEY or index with the most leading columns compared with = is
-- # used, then a range of the next column. The PRIMARY KEY is used when they're
-- # the same, then the index that's first by name.
/* extensions V001-01 V002-01 */
CREATE INDEX t_x ON t (x);
CREATE INDEX t_xy ON t (x, y);
CREATE INDEX t_y ON t (y);
CREATE INDEX t_y2 ON t (y);
EXPLAIN SELECT id FROM t WHERE id = 1 AND x = 'b';
EXPLAIN SELECT id FROM t WHERE id > 1 AND x = 'b';
EXPLAIN SELECT id FROM t WHERE x = 'b' AND y > 1;
EXPLAIN SELECT id FROM t WHERE x = 'b' AND y = 1;
EXPLAIN SELECT id FROM t WHERE x > 'b' AND y = 1;
EXPLAIN SELECT id FROM t WHERE x > 'b' AND y > 1;
-- msg: CREATE INDEX 1
-- msg: CREATE INDEX 1
-- msg: CREATE INDEX 1
-- msg: CREATE INDEX 1
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.T (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER) RANGE ID = 1
-- EXPLAIN: WHERE X = 'b'
-- EXPLAIN: EXPR (ID INTEGER NOT NULL)
-- EXPLAIN: INDEX ":memory:".PUBLIC.T_X ON ":memory:".PUBLIC.T (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER) RANGE X = 'b'
-- EXPLAIN: WHERE ID > 1 AND X = 'b'
-- EXPLAIN: EXPR (ID INTEGER NOT NULL)
-- EXPLAIN: INDEX ":memory:".PUBLIC.T_XY ON ":memory:".PUBLIC.T (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER) RANGE X = 'b' AND Y > 1
-- EXPLAIN: WHERE X = 'b' AND Y > 1
-- EXPLAIN: EXPR (ID INTEGER NOT NULL)
-- EXPLAIN: INDEX ":memory:".PUBLIC.T_XY ON ":memory:".PUBLIC.T (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER) RANGE X = 'b' AND Y = 1
-- EXPLAIN: WHERE X = 'b' AND Y = 1
-- EXPLAIN: EXPR (ID INTEGER NOT NULL)
-- EXPLAIN: INDEX ":memory:".PUBLIC.T_Y ON ":memory:".PUBLIC.T (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER) RANGE Y = 1
-- EXPLAIN: WHERE X > 'b'
-- EXPLAIN: EXPR (ID INTEGER NOT NULL)
-- EXPLAIN: INDEX ":memory:".PUBLIC.T_X ON ":memory:".PUBLIC.T (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER) RANGE X > 'b'
-- EXPLAIN: WHERE X > 'b' AND Y > 1
-- EXPLAIN: EXPR (ID INTEGER NOT NULL)

-- # An OR can be true for any row, so no index is used.
/* extensions V001-01 V002-01 */
CREATE INDEX t_x ON t (x);
EXPLAIN SELECT id FROM t WHERE x = 'a' OR x = 'b';
-- msg: CREATE INDEX 1
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER)
-- EXPLAIN: WHERE X = 'a' OR X = 'b'
-- EXPLAIN: EXPR (ID INTEGER NOT NULL)

-- # A correlation name, with new names for the columns.
/* extensions V002-01 */
CREATE INDEX t_x ON t (x);
SELECT * FROM t AS z (a, b, c) WHERE b = 'b';
SELECT * FROM t AS z (a, b, c) WHERE b = 'b' AND z.a > 1;
-- msg: CREATE INDEX 1
-- A: 1 B: b C: 5
-- A: 4 B: b C: 2
-- A: 4 B: b C: 2

-- # UPDATE and DELETE use the index too, including to find rows whose indexed
-- # column changes.
/* extensions V002-01 */
CREATE INDEX t_x ON t (x);
UPDATE t SET x = 'd' WHERE x = 'b';
SELECT * FROM t WHERE x = 'b';
SELECT * FROM t WHERE x = 'd';
DELETE FROM t WHERE x = 'd' AND y = 2;
SELECT * FROM t WHERE x >= 'c';
-- msg: CREATE INDEX 1
-- msg: UPDATE 2
-- ID: 1 X: d Y: 5
-- ID: 4 X: d Y: 2
-- msg: DELETE 1
-- ID: 3 X: c Y: 1
-- ID: 1 X: d Y: 5

-- # Inside a transaction, the changes are seen through the index, and are gone
-- # after ROLLBACK.
/* extensions V002-01 */
CREATE INDEX t_x ON t (x);
START TRANSACTION;
UPDATE t SET x = 'd' WHERE id = 1;
UPDATE t SET y = 9 WHERE x = 'd';
INSERT INTO t (id, x, y) VALUES (7, 'd', 0);
SELECT * FROM t WHERE x = 'd';
SELECT * FROM t WHERE x = 'b';
ROLLBACK;
SELECT * FROM t WHERE x = 'd';
SELECT * FROM t WHERE x = 'b';
-- msg: CREATE INDEX 1
-- msg: START TRANSACTION
-- msg: UPDATE 1
-- msg: UPDATE 1
-- msg: INSERT 1
-- ID: 1 X: d Y: 9
-- ID: 7 X: d Y: 0
-- ID: 4 X: b Y: 2
-- msg: ROLLBACK
-- ID: 1 X: b Y: 5
-- ID: 4 X: b Y: 2

-- # A table without a PRIMARY KEY.
/* extensions V002-01 */
CREATE TABLE t2 (a INT, b INT);
INSERT INTO t2 (a, b) VALUES (3, 1), (1, 2), (1, 3), (2, 4);
CREATE INDEX t2_a ON t2 (a);
SELECT * FROM t2 WHERE a = 1;
SELECT * FROM t2 WHERE a > 1;
-- msg: CREATE TABLE 1
-- msg: INSERT 4
-- msg: CREATE INDEX 1
-- A: 1 B: 2
-- A: 1 B: 3
-- A: 2 B: 4
-- A: 3 B: 1

-- # Every type, in both orders. The row ID is after the values of every column
-- # of the index, including NULL. NULL is before every value of an ascending
-- # column (like ORDER BY), so it's last in a descending one.
/* extensions V002-01 V003-01 */
CREATE TABLE types (b BOOLEAN, s SMALLINT, i INTEGER, bi BIGINT, r REAL, d DOUBLE PRECISION, n NUMERIC(10, 2), de DECIMAL(5, 1), c CHAR(3), vc VARCHAR(5), dt DATE, tm TIME, tmz TIME WITH TIME ZONE, ts TIMESTAMP, tsz TIMESTAMP WITH TIME ZONE);
INSERT INTO types VALUES (TRUE, 1, 2, 3, 1.5, -2.5, 12.34, -0.5, 'ab', 'a b', DATE '2022-07-04', TIME '12:34:56', TIME '12:34:56+05:00', TIMESTAMP '2022-07-04 12:34:56', TIMESTAMP '2022-07-04 12:34:56+05:00');
INSERT INTO types VALUES (FALSE, -1, -2, -3, -1.5, 0, 0, 0, '', '', DATE '2000-01-01', TIME '00:00:00', TIME '00:00:00-05:00', TIMESTAMP '2000-01-01 00:00:00', TIMESTAMP '2000-01-01 00:00:00-05:00');
INSERT INTO types VALUES (TRUE, NULL, NULL, NULL, NULL, NULL, -7.25, NULL, NULL, NULL, DATE '1999-12-31', NULL, NULL, NULL, NULL);
CREATE INDEX types_1 ON types (b, s, i, bi, r, d, n);
CREATE INDEX types_2 ON types (n, de, c, vc, s);
CREATE INDEX types_3 ON types (dt, tm, tmz, ts, tsz, s);
CREATE INDEX types_4 ON types (b DESC, s DESC, i DESC, bi DESC, r DESC, d DESC, n DESC);
CREATE INDEX types_5 ON types (n DESC, de DESC, c DESC, vc DESC, s DESC);
CREATE INDEX types_6 ON types (dt DESC, tm DESC, tmz DESC, ts DESC, tsz DESC, s DESC);
SELECT b, s, n FROM types WHERE b = TRUE;
SELECT s, n FROM types WHERE n > -100;
SELECT s, dt FROM types WHERE dt > DATE '1900-01-01';
DROP INDEX types_1;
DROP INDEX types_2;
DROP INDEX types_3;
SELECT b, s, n FROM types WHERE b = TRUE;
SELECT s, n FROM types WHERE n > -100;
SELECT s, dt FROM types WHERE dt > DATE '1900-01-01';
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: CREATE INDEX 1
-- msg: CREATE INDEX 1
-- msg: CREATE INDEX 1
-- msg: CREATE INDEX 1
-- msg: CREATE INDEX 1
-- msg: CREATE INDEX 1
-- B: TRUE S: NULL N: -7.25
-- B: TRUE S: 1 N: 12.34
-- S: NULL N: -7.25
-- S: -1 N: 0.00
-- S: 1 N: 12.34
-- S: NULL DT: 1999-12-31
-- S: -1 DT: 2000-01-01
-- S: 1 DT: 2022-07-04
-- msg: DROP INDEX 1
-- msg: DROP INDEX 1
-- msg: DROP INDEX 1
-- B: TRUE S: 1 N: 12.34
-- B: TRUE S: NULL N: -7.25
-- S: 1 N: 12.34
-- S: -1 N: 0.00
-- S: NULL N: -7.25
-- S: 1 DT: 2022-07-04
-- S: -1 DT: 2000-01-01
-- S: NULL DT: 1999-12-31
