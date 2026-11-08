/* setup */
CREATE TABLE t1 (x INT);
INSERT INTO t1 (x) VALUES (1);
INSERT INTO t1 (x) VALUES (2);
INSERT INTO t1 (x) VALUES (3);
INSERT INTO t1 (x) VALUES (4);
INSERT INTO t1 (x) VALUES (5);

-- # OFFSET skips that many rows, and ROW and ROWS mean the same. Skipping as
-- # many rows as there are, or more, leaves none (General Rules, 6.c.i).
-- # Without ORDER BY the order is implementation-dependent (General Rules,
-- # 5.a); vsql reads the rows in the order they were inserted.
SELECT * FROM t1
OFFSET 0 ROWS;
-- X: 1
-- X: 2
-- X: 3
-- X: 4
-- X: 5

SELECT * FROM t1
OFFSET 2 ROW;
-- X: 3
-- X: 4
-- X: 5

SELECT * FROM t1
OFFSET 5 ROWS;

SELECT * FROM t1
OFFSET 50 ROW;

-- # FETCH FIRST keeps at most that many rows, with ROW or ROWS. Without a count
-- # it keeps one (General Rules, 7.b.iii).
SELECT * FROM t1
FETCH FIRST 1 ROW ONLY;
-- X: 1

SELECT * FROM t1
FETCH FIRST 2 ROWS ONLY;
-- X: 1
-- X: 2

SELECT * FROM t1
FETCH FIRST ROW ONLY;
-- X: 1

SELECT * FROM t1
FETCH FIRST ROWS ONLY;
-- X: 1

-- # NEXT means the same as FIRST.
SELECT * FROM t1
FETCH NEXT 2 ROWS ONLY;
-- X: 1
-- X: 2

SELECT * FROM t1
OFFSET 1 ROW
FETCH NEXT ROW ONLY;
-- X: 2

-- # OFFSET is applied before FETCH FIRST, so rows are counted from the first
-- # one that isn't skipped (General Rules, 7.a). An OFFSET past the end leaves
-- # nothing to fetch.
SELECT * FROM t1
OFFSET 1 ROW
FETCH FIRST ROW ONLY;
-- X: 2

SELECT * FROM t1
OFFSET 1 ROW
FETCH FIRST 2 ROWS ONLY;
-- X: 2
-- X: 3

SELECT * FROM t1
OFFSET 10 ROWS
FETCH FIRST 2 ROWS ONLY;

SELECT * FROM t1
OFFSET 1 ROW
FETCH FIRST 2 ROWS ONLY;
-- X: 2
-- X: 3
