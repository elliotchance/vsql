-- # A comparison whose operand is itself a comparison (a boolean predicand)
-- # needs T031 (Part 2, 7.1, Conformance Rules, 5). TRUE and FALSE are boolean
-- # literals, which need T031 too (Part 2, 5.3, Conformance Rules, 1).
/* setup */
CREATE TABLE t (x INT NOT NULL, b BOOLEAN);
INSERT INTO t (x, b) VALUES (1, TRUE);

/* flags */
SELECT x FROM t WHERE (x = 1) = TRUE;
-- flags: T031
-- X: 1

/* flags */
SELECT x FROM t WHERE (x = 1 AND x > 0) <> FALSE;
-- flags: T031
-- X: 1
