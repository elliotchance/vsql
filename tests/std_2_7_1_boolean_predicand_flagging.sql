-- # A comparison whose operand is a boolean operation in parentheses (a boolean
-- # predicand) needs T031 (Part 2, 7.1, Conformance Rules, 5), even when neither
-- # side has a TRUE or FALSE literal.
/* setup */
CREATE TABLE t (x INT NOT NULL, b BOOLEAN);
INSERT INTO t (x, b) VALUES (1, TRUE);

/* flags */
SELECT x FROM t WHERE (x = 1) = (x > 0);
-- flags: T031
-- X: 1

/* flags */
SELECT x FROM t WHERE (x = 1) = b;
-- flags: T031
-- X: 1

/* flags */
SELECT x FROM t WHERE b = (x > 0);
-- flags: T031
-- X: 1

/* flags */
SELECT x FROM t WHERE (x = 1 AND x > 0) = (x > 0);
-- flags: T031
-- X: 1

/* flags */
SELECT x FROM t WHERE (NOT (x = 1)) IS NULL;
-- flags: T031

-- # A search condition in parentheses isn't the operand of a comparison, so it
-- # doesn't need T031.
/* flags */
SELECT x FROM t WHERE (x = 1);
-- flags:
-- X: 1

/* flags */
SELECT x FROM t WHERE (x = 1) AND (x > 0 OR x < 0);
-- flags:
-- X: 1

/* flags */
SELECT x FROM t WHERE ((x = 1));
-- flags:
-- X: 1
