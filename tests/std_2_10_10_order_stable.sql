/* setup */
CREATE TABLE t (k INT, id INT);
INSERT INTO t (k, id) VALUES (3, 1), (1, 2), (NULL, 3), (2, 4), (1, 5), (3, 6), (NULL, 7), (2, 8), (1, 9), (3, 10), (2, 11);

-- # Rows with the same sort key (peers) stay in the order they were inserted,
-- # because the sort is stable. The standard leaves the order of peers to the
-- # implementation (General Rules, 1.i). DESC reverses the keys, not the peers.
SELECT * FROM t ORDER BY k;
-- K: NULL ID: 3
-- K: NULL ID: 7
-- K: 1 ID: 2
-- K: 1 ID: 5
-- K: 1 ID: 9
-- K: 2 ID: 4
-- K: 2 ID: 8
-- K: 2 ID: 11
-- K: 3 ID: 1
-- K: 3 ID: 6
-- K: 3 ID: 10

SELECT * FROM t ORDER BY k DESC;
-- K: 3 ID: 1
-- K: 3 ID: 6
-- K: 3 ID: 10
-- K: 2 ID: 4
-- K: 2 ID: 8
-- K: 2 ID: 11
-- K: 1 ID: 2
-- K: 1 ID: 5
-- K: 1 ID: 9
-- K: NULL ID: 3
-- K: NULL ID: 7

-- # A second sort key orders the peers of the first (General Rules, 1.h).
SELECT * FROM t ORDER BY k DESC, id DESC;
-- K: 3 ID: 10
-- K: 3 ID: 6
-- K: 3 ID: 1
-- K: 2 ID: 11
-- K: 2 ID: 8
-- K: 2 ID: 4
-- K: 1 ID: 9
-- K: 1 ID: 5
-- K: 1 ID: 2
-- K: NULL ID: 7
-- K: NULL ID: 3

-- # A sort key can be an expression. id / 4 is an integer division, so the rows
-- # are in groups of four ids, each ordered by k.
SELECT * FROM t ORDER BY id / 4, k;
-- K: NULL ID: 3
-- K: 1 ID: 2
-- K: 3 ID: 1
-- K: NULL ID: 7
-- K: 1 ID: 5
-- K: 2 ID: 4
-- K: 3 ID: 6
-- K: 1 ID: 9
-- K: 2 ID: 8
-- K: 2 ID: 11
-- K: 3 ID: 10

-- # A sort key without a column (V202-01) is the same for every row, so every
-- # row is a peer and they keep the order they were inserted.
/* extensions V202-01 */
SELECT * FROM t ORDER BY 0;
-- K: 3 ID: 1
-- K: 1 ID: 2
-- K: NULL ID: 3
-- K: 2 ID: 4
-- K: 1 ID: 5
-- K: 3 ID: 6
-- K: NULL ID: 7
-- K: 2 ID: 8
-- K: 1 ID: 9
-- K: 3 ID: 10
-- K: 2 ID: 11

-- # GROUP BY sorts the rows the same way, so the groups come out in the order
-- # of their key, with the NULL group first.
SELECT k, COUNT(*) AS c, MIN(id) AS m FROM t GROUP BY k;
-- K: NULL C: 2 M: 3
-- K: 1 C: 3 M: 2
-- K: 2 C: 3 M: 4
-- K: 3 C: 3 M: 1

-- # A sort key is evaluated for every row before sorting, so an error in it is
-- # raised. A single row (or no rows) isn't sorted, so its sort key is never
-- # evaluated.
SELECT * FROM t ORDER BY 10 / (id - 5);
-- error 22012: division by zero

SELECT * FROM t WHERE id > 1 AND id < 5 ORDER BY 10 / (id - 5);
-- K: 2 ID: 4
-- K: NULL ID: 3
-- K: 1 ID: 2

SELECT * FROM t WHERE id = 5 ORDER BY 10 / (id - 5);
-- K: 1 ID: 5

SELECT * FROM t WHERE id > 100 ORDER BY 10 / (id - 5);
