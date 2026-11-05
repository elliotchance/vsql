-- # A join finds the rows of the inner side (the right side, or the left side
-- # of a RIGHT JOIN) that can match each row of the outer side with an index
-- # or the PRIMARY KEY of the inner table, like a WHERE clause does (see
-- # index-range.sql). The whole join condition is still applied to them.

/* setup */
CREATE TABLE a (id INT PRIMARY KEY, x VARCHAR(10), y INT);
CREATE TABLE b (id INT PRIMARY KEY, x VARCHAR(10), y INT, z DOUBLE PRECISION);
INSERT INTO a (id, x, y) VALUES (1, 'b', 5), (2, 'a', NULL), (3, 'c', 1), (4, NULL, 2), (5, 'b', 3);
INSERT INTO b (id, x, y, z) VALUES (10, 'b', 1, 1.5), (11, 'a', 2, 2), (12, 'b', 3, 3), (13, NULL, 4, 4), (14, 'd', 5, 5);

/* extensions V001-01 V002-01 */
CREATE INDEX b_x ON b (x);
EXPLAIN SELECT a.id, b.id FROM a JOIN b ON b.x = a.x;
EXPLAIN SELECT a.id, b.id FROM a LEFT JOIN b ON a.x = b.x;
EXPLAIN SELECT a.id, b.id FROM b RIGHT JOIN a ON b.x = a.x;
-- msg: CREATE INDEX 1
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.A (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   INDEX ":memory:".PUBLIC.B_X ON ":memory:".PUBLIC.B (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER, Z DOUBLE PRECISION) RANGE B.X = A.X
-- EXPLAIN: INNER JOIN ON B.X = A.X (":memory:".PUBLIC.A.ID INTEGER NOT NULL, ":memory:".PUBLIC.A.X CHARACTER VARYING(10), ":memory:".PUBLIC.A.Y INTEGER, ":memory:".PUBLIC.B.ID INTEGER NOT NULL, ":memory:".PUBLIC.B.X CHARACTER VARYING(10), ":memory:".PUBLIC.B.Y INTEGER, ":memory:".PUBLIC.B.Z DOUBLE PRECISION)
-- EXPLAIN: EXPR (ID INTEGER NOT NULL, ID INTEGER NOT NULL)
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.A (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   INDEX ":memory:".PUBLIC.B_X ON ":memory:".PUBLIC.B (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER, Z DOUBLE PRECISION) RANGE B.X = A.X
-- EXPLAIN: LEFT JOIN ON A.X = B.X (":memory:".PUBLIC.A.ID INTEGER NOT NULL, ":memory:".PUBLIC.A.X CHARACTER VARYING(10), ":memory:".PUBLIC.A.Y INTEGER, ":memory:".PUBLIC.B.ID INTEGER, ":memory:".PUBLIC.B.X CHARACTER VARYING(10), ":memory:".PUBLIC.B.Y INTEGER, ":memory:".PUBLIC.B.Z DOUBLE PRECISION)
-- EXPLAIN: EXPR (ID INTEGER NOT NULL, ID INTEGER)
-- EXPLAIN: $1:
-- EXPLAIN:   INDEX ":memory:".PUBLIC.B_X ON ":memory:".PUBLIC.B (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER, Z DOUBLE PRECISION) RANGE B.X = A.X
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.A (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER)
-- EXPLAIN: RIGHT JOIN ON B.X = A.X (":memory:".PUBLIC.B.ID INTEGER, ":memory:".PUBLIC.B.X CHARACTER VARYING(10), ":memory:".PUBLIC.B.Y INTEGER, ":memory:".PUBLIC.B.Z DOUBLE PRECISION, ":memory:".PUBLIC.A.ID INTEGER NOT NULL, ":memory:".PUBLIC.A.X CHARACTER VARYING(10), ":memory:".PUBLIC.A.Y INTEGER)
-- EXPLAIN: EXPR (ID INTEGER NOT NULL, ID INTEGER)

/* extensions V002-01 */
CREATE INDEX b_x ON b (x);
SELECT a.id, b.id FROM a JOIN b ON b.x = a.x;
SELECT a.id, b.id FROM a LEFT JOIN b ON a.x = b.x;
SELECT a.id, b.id FROM b RIGHT JOIN a ON b.x = a.x;
SELECT a.id, b.id FROM a JOIN b ON b.x = a.x AND b.y < a.y;
-- msg: CREATE INDEX 1
-- ID: 1 ID: 10
-- ID: 1 ID: 12
-- ID: 2 ID: 11
-- ID: 5 ID: 10
-- ID: 5 ID: 12
-- ID: 1 ID: 10
-- ID: 1 ID: 12
-- ID: 2 ID: 11
-- ID: 3 ID: NULL
-- ID: 4 ID: NULL
-- ID: 5 ID: 10
-- ID: 5 ID: 12
-- ID: 1 ID: 10
-- ID: 1 ID: 12
-- ID: 2 ID: 11
-- ID: 3 ID: NULL
-- ID: 4 ID: NULL
-- ID: 5 ID: 10
-- ID: 5 ID: 12
-- ID: 1 ID: 10
-- ID: 1 ID: 12
-- ID: 5 ID: 10

-- # The PRIMARY KEY.
/* extensions V001-01 */
EXPLAIN SELECT a.id, b.x FROM a JOIN b ON b.id = a.y + 9;
SELECT a.id, b.x FROM a JOIN b ON b.id = a.y + 9;
SELECT a.id, b.x FROM a LEFT JOIN b ON b.id = a.y + 9;
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.A (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   PRIMARY KEY ":memory:".PUBLIC.B (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER, Z DOUBLE PRECISION) RANGE B.ID = A.Y + 9
-- EXPLAIN: INNER JOIN ON B.ID = A.Y + 9 (":memory:".PUBLIC.A.ID INTEGER NOT NULL, ":memory:".PUBLIC.A.X CHARACTER VARYING(10), ":memory:".PUBLIC.A.Y INTEGER, ":memory:".PUBLIC.B.ID INTEGER NOT NULL, ":memory:".PUBLIC.B.X CHARACTER VARYING(10), ":memory:".PUBLIC.B.Y INTEGER, ":memory:".PUBLIC.B.Z DOUBLE PRECISION)
-- EXPLAIN: EXPR (ID INTEGER NOT NULL, X CHARACTER VARYING(10))
-- ID: 1 X: d
-- ID: 3 X: b
-- ID: 4 X: a
-- ID: 5 X: b
-- ID: 1 X: d
-- ID: 2 X: NULL
-- ID: 3 X: b
-- ID: 4 X: a
-- ID: 5 X: b

-- # A value that's the same for every row can also be used.
/* extensions V001-01 V002-01 */
CREATE INDEX b_x ON b (x);
EXPLAIN SELECT a.id, b.id FROM a JOIN b ON b.x = 'b';
SELECT a.id, b.id FROM a JOIN b ON b.x = 'b' AND a.id < 3;
-- msg: CREATE INDEX 1
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.A (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   INDEX ":memory:".PUBLIC.B_X ON ":memory:".PUBLIC.B (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER, Z DOUBLE PRECISION) RANGE B.X = 'b'
-- EXPLAIN: INNER JOIN ON B.X = 'b' (":memory:".PUBLIC.A.ID INTEGER NOT NULL, ":memory:".PUBLIC.A.X CHARACTER VARYING(10), ":memory:".PUBLIC.A.Y INTEGER, ":memory:".PUBLIC.B.ID INTEGER NOT NULL, ":memory:".PUBLIC.B.X CHARACTER VARYING(10), ":memory:".PUBLIC.B.Y INTEGER, ":memory:".PUBLIC.B.Z DOUBLE PRECISION)
-- EXPLAIN: EXPR (ID INTEGER NOT NULL, ID INTEGER NOT NULL)
-- ID: 1 ID: 10
-- ID: 1 ID: 12
-- ID: 2 ID: 10
-- ID: 2 ID: 12

-- # A correlation name, with or without new names for the columns.
/* extensions V001-01 V002-01 */
CREATE INDEX b_x ON b (x);
EXPLAIN SELECT a.id, c.id FROM a JOIN b AS c ON c.x = a.x;
SELECT a.id, c.id FROM a JOIN b AS c ON c.x = a.x;
SELECT a.id, c.i, c.j FROM a LEFT JOIN b AS c (i, j, k, l) ON a.x = c.j;
SELECT c.i, a.id FROM b AS c (i, j, k, l) RIGHT JOIN a ON a.x = c.j;
-- msg: CREATE INDEX 1
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.A (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   C:
-- EXPLAIN:     INDEX ":memory:".PUBLIC.B_X ON ":memory:".PUBLIC.B (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER, Z DOUBLE PRECISION) RANGE C.X = A.X
-- EXPLAIN:   TABLE C (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER, Z DOUBLE PRECISION)
-- EXPLAIN: INNER JOIN ON C.X = A.X (":memory:".PUBLIC.A.ID INTEGER NOT NULL, ":memory:".PUBLIC.A.X CHARACTER VARYING(10), ":memory:".PUBLIC.A.Y INTEGER, C.ID INTEGER NOT NULL, C.X CHARACTER VARYING(10), C.Y INTEGER, C.Z DOUBLE PRECISION)
-- EXPLAIN: EXPR (ID INTEGER NOT NULL, ID INTEGER NOT NULL)
-- ID: 1 ID: 10
-- ID: 1 ID: 12
-- ID: 2 ID: 11
-- ID: 5 ID: 10
-- ID: 5 ID: 12
-- ID: 1 I: 10 J: b
-- ID: 1 I: 12 J: b
-- ID: 2 I: 11 J: a
-- ID: 3 I: NULL J: NULL
-- ID: 4 I: NULL J: NULL
-- ID: 5 I: 10 J: b
-- ID: 5 I: 12 J: b
-- I: 10 ID: 1
-- I: 12 ID: 1
-- I: 11 ID: 2
-- I: NULL ID: 3
-- I: NULL ID: 4
-- I: 10 ID: 5
-- I: 12 ID: 5

-- # USING.
/* extensions V001-01 V002-01 */
CREATE INDEX b_x ON b (x);
EXPLAIN SELECT x, a.id, b.id FROM a JOIN b USING (x);
SELECT x, a.id, b.id FROM a JOIN b USING (x);
SELECT x, a.id, b.id FROM a LEFT JOIN b USING (x);
-- msg: CREATE INDEX 1
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.A (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   INDEX ":memory:".PUBLIC.B_X ON ":memory:".PUBLIC.B (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER, Z DOUBLE PRECISION) RANGE ":memory:".PUBLIC.B.X = ":memory:".PUBLIC.A.X
-- EXPLAIN: INNER JOIN ON ":memory:".PUBLIC.A.X = ":memory:".PUBLIC.B.X ($USING2.X CHARACTER VARYING(10) NOT NULL, ":memory:".PUBLIC.A.ID INTEGER NOT NULL, ":memory:".PUBLIC.A.Y INTEGER, ":memory:".PUBLIC.B.ID INTEGER NOT NULL, ":memory:".PUBLIC.B.Y INTEGER, ":memory:".PUBLIC.B.Z DOUBLE PRECISION)
-- EXPLAIN: EXPR (X CHARACTER VARYING(10) NOT NULL, ID INTEGER NOT NULL, ID INTEGER NOT NULL)
-- X: b ID: 1 ID: 10
-- X: b ID: 1 ID: 12
-- X: a ID: 2 ID: 11
-- X: b ID: 5 ID: 10
-- X: b ID: 5 ID: 12
-- X: b ID: 1 ID: 10
-- X: b ID: 1 ID: 12
-- X: a ID: 2 ID: 11
-- X: c ID: 3 ID: NULL
-- X: NULL ID: 4 ID: NULL
-- X: b ID: 5 ID: 10
-- X: b ID: 5 ID: 12

-- # The leading columns of an index, then a range.
/* extensions V001-01 V002-01 */
CREATE INDEX b_x_y ON b (x, y DESC);
CREATE INDEX b_y ON b (y);
EXPLAIN SELECT a.id, b.id FROM a JOIN b ON b.x = a.x AND b.y >= a.y;
EXPLAIN SELECT a.id, b.id FROM a JOIN b ON b.y > a.y AND b.y <= a.y + 2;
SELECT a.id, b.id FROM a JOIN b ON b.x = a.x AND b.y >= a.y;
SELECT a.id, b.id FROM a JOIN b ON b.y > a.y AND b.y <= a.y + 2;
-- msg: CREATE INDEX 1
-- msg: CREATE INDEX 1
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.A (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   INDEX ":memory:".PUBLIC.B_X_Y ON ":memory:".PUBLIC.B (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER, Z DOUBLE PRECISION) RANGE B.X = A.X AND B.Y >= A.Y
-- EXPLAIN: INNER JOIN ON B.X = A.X AND B.Y >= A.Y (":memory:".PUBLIC.A.ID INTEGER NOT NULL, ":memory:".PUBLIC.A.X CHARACTER VARYING(10), ":memory:".PUBLIC.A.Y INTEGER, ":memory:".PUBLIC.B.ID INTEGER NOT NULL, ":memory:".PUBLIC.B.X CHARACTER VARYING(10), ":memory:".PUBLIC.B.Y INTEGER, ":memory:".PUBLIC.B.Z DOUBLE PRECISION)
-- EXPLAIN: EXPR (ID INTEGER NOT NULL, ID INTEGER NOT NULL)
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.A (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   INDEX ":memory:".PUBLIC.B_Y ON ":memory:".PUBLIC.B (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER, Z DOUBLE PRECISION) RANGE B.Y > A.Y AND B.Y <= A.Y + 2
-- EXPLAIN: INNER JOIN ON B.Y > A.Y AND B.Y <= A.Y + 2 (":memory:".PUBLIC.A.ID INTEGER NOT NULL, ":memory:".PUBLIC.A.X CHARACTER VARYING(10), ":memory:".PUBLIC.A.Y INTEGER, ":memory:".PUBLIC.B.ID INTEGER NOT NULL, ":memory:".PUBLIC.B.X CHARACTER VARYING(10), ":memory:".PUBLIC.B.Y INTEGER, ":memory:".PUBLIC.B.Z DOUBLE PRECISION)
-- EXPLAIN: EXPR (ID INTEGER NOT NULL, ID INTEGER NOT NULL)
-- ID: 5 ID: 12
-- ID: 3 ID: 11
-- ID: 3 ID: 12
-- ID: 4 ID: 12
-- ID: 4 ID: 13
-- ID: 5 ID: 13
-- ID: 5 ID: 14

-- # A row of the outer side with a NULL can't match any row, so none are read.
-- # The rows of a nested join are the outer side of the next join.
/* extensions V002-01 */
CREATE TABLE c (id INT PRIMARY KEY, w VARCHAR(10));
INSERT INTO c (id, w) VALUES (100, 'a'), (101, 'b');
CREATE INDEX c_w ON c (w);
SELECT a.id, b.id, c.id FROM a LEFT JOIN b ON b.id = a.y + 9 LEFT JOIN c ON c.w = b.x;
SELECT a.id, b.id, c.id FROM c RIGHT JOIN (a LEFT JOIN b ON b.id = a.y + 9) ON c.w = b.x;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: CREATE INDEX 1
-- ID: 1 ID: 14 ID: NULL
-- ID: 2 ID: NULL ID: NULL
-- ID: 3 ID: 10 ID: 101
-- ID: 4 ID: 11 ID: 100
-- ID: 5 ID: 12 ID: 101
-- ID: 1 ID: 14 ID: NULL
-- ID: 2 ID: NULL ID: NULL
-- ID: 3 ID: 10 ID: 101
-- ID: 4 ID: 11 ID: 100
-- ID: 5 ID: 12 ID: 101

-- # A value that the column can't hold exactly is ignored, so the rows are
-- # found with the rest of the join condition (or all of them are read).
/* extensions V002-01 */
CREATE INDEX b_y ON b (y);
SELECT b.id, a.id FROM b JOIN a ON a.id = b.z;
SELECT a.id, b.id FROM a JOIN b ON b.y = a.y / 2.0;
-- msg: CREATE INDEX 1
-- ID: 11 ID: 2
-- ID: 12 ID: 3
-- ID: 13 ID: 4
-- ID: 14 ID: 5
-- ID: 4 ID: 10

-- # An index isn't used when the join condition has an OR, compares the inner
-- # side with itself, or the inner side isn't a table.
/* extensions V001-01 V002-01 */
CREATE INDEX b_x ON b (x);
EXPLAIN SELECT a.id, b.id FROM a JOIN b ON b.x = a.x OR b.id = 10;
EXPLAIN SELECT a.id, b.id FROM a JOIN b ON b.x = b.x;
EXPLAIN SELECT a.id, d.id FROM a JOIN (SELECT * FROM b) AS d ON d.x = a.x;
SELECT a.id, b.id FROM a JOIN b ON b.x = a.x OR b.id = 10;
-- msg: CREATE INDEX 1
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.A (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.B (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER, Z DOUBLE PRECISION)
-- EXPLAIN: INNER JOIN ON B.X = A.X OR B.ID = 10 (":memory:".PUBLIC.A.ID INTEGER NOT NULL, ":memory:".PUBLIC.A.X CHARACTER VARYING(10), ":memory:".PUBLIC.A.Y INTEGER, ":memory:".PUBLIC.B.ID INTEGER NOT NULL, ":memory:".PUBLIC.B.X CHARACTER VARYING(10), ":memory:".PUBLIC.B.Y INTEGER, ":memory:".PUBLIC.B.Z DOUBLE PRECISION)
-- EXPLAIN: EXPR (ID INTEGER NOT NULL, ID INTEGER NOT NULL)
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.A (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.B (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER, Z DOUBLE PRECISION)
-- EXPLAIN: INNER JOIN ON B.X = B.X (":memory:".PUBLIC.A.ID INTEGER NOT NULL, ":memory:".PUBLIC.A.X CHARACTER VARYING(10), ":memory:".PUBLIC.A.Y INTEGER, ":memory:".PUBLIC.B.ID INTEGER NOT NULL, ":memory:".PUBLIC.B.X CHARACTER VARYING(10), ":memory:".PUBLIC.B.Y INTEGER, ":memory:".PUBLIC.B.Z DOUBLE PRECISION)
-- EXPLAIN: EXPR (ID INTEGER NOT NULL, ID INTEGER NOT NULL)
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.A (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   D:
-- EXPLAIN:     TABLE ":memory:".PUBLIC.B (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER, Z DOUBLE PRECISION)
-- EXPLAIN:     EXPR (":memory:".PUBLIC.B.ID INTEGER NOT NULL, ":memory:".PUBLIC.B.X CHARACTER VARYING(10), ":memory:".PUBLIC.B.Y INTEGER, ":memory:".PUBLIC.B.Z DOUBLE PRECISION)
-- EXPLAIN:   TABLE D (ID INTEGER NOT NULL, X CHARACTER VARYING(10), Y INTEGER, Z DOUBLE PRECISION)
-- EXPLAIN: INNER JOIN ON D.X = A.X (":memory:".PUBLIC.A.ID INTEGER NOT NULL, ":memory:".PUBLIC.A.X CHARACTER VARYING(10), ":memory:".PUBLIC.A.Y INTEGER, D.ID INTEGER NOT NULL, D.X CHARACTER VARYING(10), D.Y INTEGER, D.Z DOUBLE PRECISION)
-- EXPLAIN: EXPR (ID INTEGER NOT NULL, ID INTEGER NOT NULL)
-- ID: 1 ID: 10
-- ID: 1 ID: 12
-- ID: 2 ID: 10
-- ID: 2 ID: 11
-- ID: 3 ID: 10
-- ID: 4 ID: 10
-- ID: 5 ID: 10
-- ID: 5 ID: 12

-- # The rows that the transaction has inserted or updated are found with the
-- # index, and the rows it has deleted aren't.
/* extensions V002-01 */
CREATE INDEX b_x ON b (x);
START TRANSACTION;
INSERT INTO b (id, x, y, z) VALUES (15, 'c', 6, 6);
UPDATE b SET x = 'c' WHERE id = 11;
DELETE FROM b WHERE id = 10;
SELECT a.id, b.id FROM a JOIN b ON b.x = a.x;
ROLLBACK;
SELECT a.id, b.id FROM a JOIN b ON b.x = a.x;
-- msg: CREATE INDEX 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: UPDATE 1
-- msg: DELETE 1
-- ID: 1 ID: 12
-- ID: 3 ID: 11
-- ID: 3 ID: 15
-- ID: 5 ID: 12
-- msg: ROLLBACK
-- ID: 1 ID: 10
-- ID: 1 ID: 12
-- ID: 2 ID: 11
-- ID: 5 ID: 10
-- ID: 5 ID: 12
