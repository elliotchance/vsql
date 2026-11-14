-- # The WHERE clause of a join is applied to the joined rows, but it can still
-- # use the PRIMARY KEY (or an index) of a table to read only the rows that it
-- # can be true for, like it does for a single table (see
-- # impl_planner_primary_key_range.sql). That's only for a table that's never
-- # NULL-extended: either side of an INNER JOIN, the left side of a LEFT JOIN
-- # and the right side of a RIGHT JOIN. Leaving out a row of the other side
-- # would NULL-extend a row that should have been joined instead.

/* setup */
CREATE TABLE a (id INT PRIMARY KEY, x INT);
CREATE TABLE b (id INT PRIMARY KEY, x INT);
CREATE TABLE c (id INT PRIMARY KEY, x INT);
INSERT INTO a (id, x) VALUES (1, 10), (2, 20), (3, 30), (4, NULL);
INSERT INTO b (id, x) VALUES (10, 1), (20, 2), (40, 4);
INSERT INTO c (id, x) VALUES (1, 100), (2, 200), (3, 300);

/* extensions V001-01 */
EXPLAIN SELECT a.id, b.id FROM a JOIN b ON b.id = a.x WHERE a.id BETWEEN 2 AND 3;
EXPLAIN SELECT a.id, b.id FROM a LEFT JOIN b ON b.x = a.id WHERE a.id = 1 AND b.id = 10;
EXPLAIN SELECT a.id, b.id FROM b RIGHT JOIN a ON b.x = a.id WHERE a.id = 1 AND b.id = 10;
EXPLAIN SELECT a.id, b.id, c.id FROM a LEFT JOIN b ON b.x = a.id JOIN c ON c.x = a.x WHERE a.id < 3 AND b.id > 5 AND c.id = 1;
-- EXPLAIN: $1:
-- EXPLAIN:   PRIMARY KEY ":memory:".PUBLIC.A (ID INTEGER NOT NULL, X INTEGER) RANGE A.ID >= 2 AND A.ID <= 3
-- EXPLAIN: $2:
-- EXPLAIN:   PRIMARY KEY ":memory:".PUBLIC.B (ID INTEGER NOT NULL, X INTEGER) RANGE B.ID = A.X
-- EXPLAIN: INNER JOIN ON B.ID = A.X (":memory:".PUBLIC.A.ID INTEGER NOT NULL, ":memory:".PUBLIC.A.X INTEGER, ":memory:".PUBLIC.B.ID INTEGER NOT NULL, ":memory:".PUBLIC.B.X INTEGER)
-- EXPLAIN: WHERE A.ID BETWEEN 2 AND 3
-- EXPLAIN: EXPR (ID INTEGER NOT NULL, ID INTEGER NOT NULL)
-- EXPLAIN: $1:
-- EXPLAIN:   PRIMARY KEY ":memory:".PUBLIC.A (ID INTEGER NOT NULL, X INTEGER) RANGE A.ID = 1
-- EXPLAIN: $2:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.B (ID INTEGER NOT NULL, X INTEGER)
-- EXPLAIN: LEFT JOIN ON B.X = A.ID (":memory:".PUBLIC.A.ID INTEGER NOT NULL, ":memory:".PUBLIC.A.X INTEGER, ":memory:".PUBLIC.B.ID INTEGER, ":memory:".PUBLIC.B.X INTEGER)
-- EXPLAIN: WHERE A.ID = 1 AND B.ID = 10
-- EXPLAIN: EXPR (ID INTEGER NOT NULL, ID INTEGER)
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.B (ID INTEGER NOT NULL, X INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   PRIMARY KEY ":memory:".PUBLIC.A (ID INTEGER NOT NULL, X INTEGER) RANGE A.ID = 1
-- EXPLAIN: RIGHT JOIN ON B.X = A.ID (":memory:".PUBLIC.B.ID INTEGER, ":memory:".PUBLIC.B.X INTEGER, ":memory:".PUBLIC.A.ID INTEGER NOT NULL, ":memory:".PUBLIC.A.X INTEGER)
-- EXPLAIN: WHERE A.ID = 1 AND B.ID = 10
-- EXPLAIN: EXPR (ID INTEGER NOT NULL, ID INTEGER)
-- EXPLAIN: $1:
-- EXPLAIN:   $1:
-- EXPLAIN:     PRIMARY KEY ":memory:".PUBLIC.A (ID INTEGER NOT NULL, X INTEGER) RANGE A.ID < 3
-- EXPLAIN:   $2:
-- EXPLAIN:     TABLE ":memory:".PUBLIC.B (ID INTEGER NOT NULL, X INTEGER)
-- EXPLAIN:   LEFT JOIN ON B.X = A.ID (":memory:".PUBLIC.A.ID INTEGER NOT NULL, ":memory:".PUBLIC.A.X INTEGER, ":memory:".PUBLIC.B.ID INTEGER, ":memory:".PUBLIC.B.X INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   PRIMARY KEY ":memory:".PUBLIC.C (ID INTEGER NOT NULL, X INTEGER) RANGE C.ID = 1
-- EXPLAIN: INNER JOIN ON C.X = A.X (":memory:".PUBLIC.A.ID INTEGER NOT NULL, ":memory:".PUBLIC.A.X INTEGER, ":memory:".PUBLIC.B.ID INTEGER, ":memory:".PUBLIC.B.X INTEGER, ":memory:".PUBLIC.C.ID INTEGER NOT NULL, ":memory:".PUBLIC.C.X INTEGER)
-- EXPLAIN: WHERE A.ID < 3 AND B.ID > 5 AND C.ID = 1
-- EXPLAIN: EXPR (ID INTEGER NOT NULL, ID INTEGER, ID INTEGER NOT NULL)

SELECT a.id, b.id FROM a JOIN b ON b.id = a.x WHERE a.id BETWEEN 2 AND 3;
SELECT a.id, b.id FROM a LEFT JOIN b ON b.x = a.id WHERE a.id >= 3 AND (b.id = 10 OR b.id IS NULL);
SELECT a.id, b.id FROM b RIGHT JOIN a ON b.x = a.id WHERE a.id <= 2 AND (b.id = 20 OR b.id IS NULL);
-- ID: 2 ID: 20
-- ID: 3 ID: NULL
-- ID: 2 ID: 20
