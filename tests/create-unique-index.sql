-- # CREATE UNIQUE INDEX is a vsql extension (V002-02, as well as V002-01 for
-- # CREATE INDEX). No two rows can have the same values in the columns of the
-- # index, unless one of them is NULL.

/* setup */
CREATE TABLE t (id INT PRIMARY KEY, u INT, x VARCHAR(10));
INSERT INTO t (id, u, x) VALUES (1, 10, 'a'), (2, 20, 'b'), (3, NULL, 'b'), (4, NULL, 'c');

/* extensions V002-01 V002-02 */
/* flags */
CREATE UNIQUE INDEX t_u ON t (u);
-- flags: V002-01, V002-02
-- msg: CREATE INDEX 1

-- # The index can't be created when two rows have the same values, but NULLs
-- # are never the same.
/* extensions V002-01 V002-02 */
CREATE UNIQUE INDEX t_x ON t (x);
CREATE UNIQUE INDEX t_u ON t (u);
CREATE UNIQUE INDEX t_x ON t (x, u);
-- error 23505: violates unique constraint: UNIQUE INDEX T_X on ":memory:".PUBLIC.T
-- msg: CREATE INDEX 1
-- msg: CREATE INDEX 1

-- # Nothing is created when it fails.
/* extensions V002-01 V002-02 V003-01 */
CREATE UNIQUE INDEX t_x ON t (x);
DROP INDEX t_x;
-- error 23505: violates unique constraint: UNIQUE INDEX T_X on ":memory:".PUBLIC.T
-- error 42704: no such index: ":memory:".PUBLIC.T_X

/* extensions V002-01 V002-02 */
CREATE UNIQUE INDEX t_u ON t (u);
INSERT INTO t (id, u) VALUES (5, 10);
INSERT INTO t (id, u) VALUES (5, 30), (6, 30);
INSERT INTO t (id, u) VALUES (5, NULL), (6, NULL), (7, 30);
SELECT * FROM t;
-- msg: CREATE INDEX 1
-- error 23505: violates unique constraint: UNIQUE INDEX T_U on ":memory:".PUBLIC.T
-- error 23505: violates unique constraint: UNIQUE INDEX T_U on ":memory:".PUBLIC.T
-- msg: INSERT 3
-- ID: 1 U: 10 X: a
-- ID: 2 U: 20 X: b
-- ID: 3 U: NULL X: b
-- ID: 4 U: NULL X: c
-- ID: 5 U: NULL X: NULL
-- ID: 6 U: NULL X: NULL
-- ID: 7 U: 30 X: NULL

-- # The values are checked once every row of the statement has been changed, so
-- # the rows can swap values.
/* extensions V002-01 V002-02 */
CREATE UNIQUE INDEX t_u ON t (u DESC);
UPDATE t SET u = u + 10;
UPDATE t SET u = CASE u WHEN 20 THEN 30 ELSE 20 END WHERE u IS NOT NULL;
UPDATE t SET u = 30 WHERE id = 4;
UPDATE t SET u = 40 WHERE id IN (3, 4);
SELECT * FROM t;
-- msg: CREATE INDEX 1
-- msg: UPDATE 4
-- msg: UPDATE 2
-- error 23505: violates unique constraint: UNIQUE INDEX T_U on ":memory:".PUBLIC.T
-- error 23505: violates unique constraint: UNIQUE INDEX T_U on ":memory:".PUBLIC.T
-- ID: 1 U: 30 X: a
-- ID: 2 U: 20 X: b
-- ID: 3 U: NULL X: b
-- ID: 4 U: NULL X: c

-- # A row that's deleted (or changed) frees its values for another row, in the
-- # same statement or transaction.
/* extensions V002-01 V002-02 */
CREATE UNIQUE INDEX t_u ON t (u);
START TRANSACTION;
DELETE FROM t WHERE id = 1;
INSERT INTO t (id, u) VALUES (5, 10);
UPDATE t SET u = 10 WHERE id = 2;
UPDATE t SET id = 6 WHERE id = 5;
UPDATE t SET u = 30, id = 7 WHERE id = 6;
COMMIT;
SELECT * FROM t;
-- msg: CREATE INDEX 1
-- msg: START TRANSACTION
-- msg: DELETE 1
-- msg: INSERT 1
-- error 23505: violates unique constraint: UNIQUE INDEX T_U on ":memory:".PUBLIC.T
-- msg: UPDATE 1
-- msg: UPDATE 1
-- msg: COMMIT
-- ID: 2 U: 20 X: b
-- ID: 3 U: NULL X: b
-- ID: 4 U: NULL X: c
-- ID: 7 U: 30 X: NULL

-- # With more than one column, rows conflict only when all of the values are the
-- # same, and none of them are NULL.
/* extensions V002-01 V002-02 */
CREATE UNIQUE INDEX t_x_u ON t (x, u);
INSERT INTO t (id, x, u) VALUES (5, 'a', 20), (6, 'b', NULL), (7, NULL, 20);
INSERT INTO t (id, x, u) VALUES (8, 'b', 20);
-- msg: CREATE INDEX 1
-- msg: INSERT 3
-- error 23505: violates unique constraint: UNIQUE INDEX T_X_U on ":memory:".PUBLIC.T

-- # Values that are equal are the same, like a UNIQUE constraint.
/* extensions V002-01 V002-02 */
CREATE TABLE t2 (c CHAR(5), n NUMERIC(10, 2), d DOUBLE PRECISION, v VARCHAR(10));
CREATE UNIQUE INDEX t2_c ON t2 (c);
CREATE UNIQUE INDEX t2_n ON t2 (n);
CREATE UNIQUE INDEX t2_d ON t2 (d DESC);
CREATE UNIQUE INDEX t2_v ON t2 (v);
INSERT INTO t2 (c, n, d, v) VALUES ('a', 1.5, -2.5, 'a');
INSERT INTO t2 (c) VALUES ('a  ');
INSERT INTO t2 (n) VALUES (1.50);
INSERT INTO t2 (d) VALUES (-2.50);
INSERT INTO t2 (v) VALUES ('A');
SELECT * FROM t2;
-- msg: CREATE TABLE 1
-- msg: CREATE INDEX 1
-- msg: CREATE INDEX 1
-- msg: CREATE INDEX 1
-- msg: CREATE INDEX 1
-- msg: INSERT 1
-- error 23505: violates unique constraint: UNIQUE INDEX T2_C on ":memory:".PUBLIC.T2
-- error 23505: violates unique constraint: UNIQUE INDEX T2_N on ":memory:".PUBLIC.T2
-- error 23505: violates unique constraint: UNIQUE INDEX T2_D on ":memory:".PUBLIC.T2
-- msg: INSERT 1
-- C: a     N: 1.50 D: -2.5e0 V: a
-- C: NULL N: NULL D: NULL V: A

-- # A table without a PRIMARY KEY.
/* extensions V002-01 V002-02 */
CREATE TABLE t3 (a INT);
INSERT INTO t3 (a) VALUES (1), (2);
CREATE UNIQUE INDEX t3_a ON t3 (a);
UPDATE t3 SET a = 3 - a;
UPDATE t3 SET a = 1;
INSERT INTO t3 (a) VALUES (3), (3);
SELECT * FROM t3;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: CREATE INDEX 1
-- msg: UPDATE 2
-- error 23505: violates unique constraint: UNIQUE INDEX T3_A on ":memory:".PUBLIC.T3
-- error 23505: violates unique constraint: UNIQUE INDEX T3_A on ":memory:".PUBLIC.T3
-- A: 2
-- A: 1

-- # The rows that a FOREIGN KEY changes are checked too.
/* extensions V002-01 V002-02 */
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (id INT PRIMARY KEY, p INT DEFAULT 0 REFERENCES parent ON DELETE SET DEFAULT);
INSERT INTO parent (id) VALUES (0), (1), (2);
INSERT INTO child (id, p) VALUES (1, 1), (2, 2);
CREATE UNIQUE INDEX child_p ON child (p);
DELETE FROM parent WHERE id = 1;
DELETE FROM parent WHERE id = 2;
SELECT * FROM child;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- msg: INSERT 2
-- msg: CREATE INDEX 1
-- msg: DELETE 1
-- error 23505: violates unique constraint: UNIQUE INDEX CHILD_P on ":memory:".PUBLIC.CHILD
-- ID: 1 P: 0
-- ID: 2 P: 2
