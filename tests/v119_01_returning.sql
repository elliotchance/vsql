/* setup */
CREATE TABLE t (id INT GENERATED ALWAYS AS IDENTITY, x INT NOT NULL, y VARCHAR(10) DEFAULT 'none');
INSERT INTO t (x, y) VALUES (1, 'a'), (2, 'b');

-- # RETURNING is a vsql extension (like PostgreSQL) for INSERT (V119-01), UPDATE
-- # (V113-02) and DELETE (V112-02).
/* flags */
/* extensions V119-01 */
INSERT INTO t (x) VALUES (3) RETURNING id;
-- flags: V119-01
-- ID: 3

/* flags */
/* extensions V113-02 */
UPDATE t SET x = 3 WHERE x = 1 RETURNING id;
-- flags: V113-02
-- ID: 1

/* flags */
/* extensions V112-02 */
DELETE FROM t WHERE x = 1 RETURNING id;
-- flags: V112-02
-- ID: 1

-- # An INSERT returns its new rows, with the values of the identity column and
-- # the defaults. It's the same as a NEW TABLE.
/* extensions V119-01 */
INSERT INTO t (x) VALUES (3), (4) RETURNING *;
SELECT * FROM t;
-- ID: 3 X: 3 Y: none
-- ID: 4 X: 4 Y: none
-- ID: 1 X: 1 Y: a
-- ID: 2 X: 2 Y: b
-- ID: 3 X: 3 Y: none
-- ID: 4 X: 4 Y: none

/* extensions V119-01 */
INSERT INTO t (x, y) SELECT x + 10, y FROM t RETURNING id, x * 2 AS doubled, t.y;
-- ID: 3 DOUBLED: 22 Y: a
-- ID: 4 DOUBLED: 24 Y: b

-- # An UPDATE returns its new rows, and a DELETE its old rows. A column can be
-- # qualified by the correlation name, if there is one.
/* extensions V113-02 */
UPDATE t AS u SET x = x * 10 RETURNING u.id, x;
-- ID: 1 X: 10
-- ID: 2 X: 20

/* extensions V112-02 */
DELETE FROM t WHERE y = 'b' RETURNING y, x;
SELECT * FROM t;
-- Y: b X: 2
-- ID: 1 X: 1 Y: a

-- # Without any rows it's a no data warning.
/* extensions V112-02 */
DELETE FROM t WHERE x = 3 RETURNING x;
-- warning 02000: no data

-- # When RETURNING fails, nothing is changed.
/* extensions V119-01 */
INSERT INTO t (x) VALUES (3) RETURNING x / 0;
SELECT COUNT(*) FROM t;
-- error 22012: division by zero
-- COL1: 2

-- # RETURNING is still a name everywhere else.
/* extensions V112-02 V119-01 */
CREATE TABLE returning (returning INT);
INSERT INTO returning (returning) VALUES (1) RETURNING returning;
DELETE FROM returning AS returning WHERE returning.returning = 1 RETURNING returning.returning;
-- msg: CREATE TABLE 1
-- RETURNING: 1
-- RETURNING: 1

-- # It can't be in a data change delta table.
SELECT * FROM NEW TABLE (INSERT INTO t (x) VALUES (3) RETURNING x);
-- error 42601: syntax error: unexpected RETURNING at line 1, column 55 near "(3) RETURNING x", expecting ")"

-- # It changes the database, so it can't be in a READ ONLY transaction.
/* extensions V119-01 */
START TRANSACTION READ ONLY;
INSERT INTO t (x) VALUES (3) RETURNING x;
-- msg: START TRANSACTION
-- error 25006: read-only sql transaction: cannot execute INSERT

-- # It's a NEW TABLE rather than a FINAL TABLE, so a referential action can
-- # change the same table.
/* extensions V113-02 */
CREATE TABLE tree (id INT NOT NULL PRIMARY KEY, parent INT REFERENCES tree (id) ON UPDATE CASCADE);
INSERT INTO tree (id, parent) VALUES (1, NULL), (2, 1);
UPDATE tree SET id = 10 WHERE id = 1 RETURNING id, parent;
SELECT * FROM tree;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- ID: 10 PARENT: NULL
-- ID: 2 PARENT: 10
-- ID: 10 PARENT: NULL
