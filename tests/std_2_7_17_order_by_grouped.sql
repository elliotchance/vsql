/* setup */
CREATE TABLE t (x INT, y INT);
INSERT INTO t (x, y) VALUES (1, 2), (2, 1), (1, 2);

-- # A sort key of a grouped query can reference a grouping column that isn't in
-- # the select list, which needs F868 (Conformance Rules, 25).
/* flags */
SELECT x FROM t GROUP BY x, y ORDER BY y;
SELECT COUNT(*) AS c FROM t GROUP BY x ORDER BY x DESC;
-- flags: F868
-- X: 2
-- X: 1
-- flags: F868
-- C: 1
-- C: 2

-- # A column of the result doesn't need it, and neither does a query that isn't
-- # grouped.
/* flags */
SELECT x FROM t GROUP BY x ORDER BY x;
SELECT x AS z FROM t GROUP BY x ORDER BY z;
SELECT x FROM t ORDER BY y, x;
-- flags:
-- X: 1
-- X: 2
-- flags:
-- Z: 1
-- Z: 2
-- flags:
-- X: 2
-- X: 1
-- X: 1

-- # A column that isn't a grouping column still can't be used.
SELECT x FROM t GROUP BY x ORDER BY y;
-- error 42803: column Y must be in the GROUP BY clause or used in an aggregate function
