/* setup */
CREATE TABLE t (k INT, id INT);
INSERT INTO t (k, id) VALUES (3, 1), (1, 2), (NULL, 3), (2, 4), (1, 5), (3, 6), (NULL, 7), (2, 8), (1, 9), (3, 10), (2, 11);

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

SELECT k, COUNT(*) AS c, MIN(id) AS m FROM t GROUP BY k;
-- K: NULL C: 2 M: 3
-- K: 1 C: 3 M: 2
-- K: 2 C: 3 M: 4
-- K: 3 C: 3 M: 1

SELECT * FROM t ORDER BY 10 / (id - 5);
-- error 22012: division by zero

SELECT * FROM t WHERE id > 1 AND id < 5 ORDER BY 10 / (id - 5);
-- K: 2 ID: 4
-- K: NULL ID: 3
-- K: 1 ID: 2

SELECT * FROM t WHERE id = 5 ORDER BY 10 / (id - 5);
-- K: 1 ID: 5

SELECT * FROM t WHERE id > 100 ORDER BY 10 / (id - 5);
