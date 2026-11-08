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

-- # A reference to an INFORMATION_SCHEMA view needs F391, Long identifiers
-- # (Part 11, 5.21, Conformance Rules, 1). vsql flags it because the schema
-- # name has 18 characters, not because of the view (#737, #738).
-- # KEY_COLUMN_USAGE also needs F341 (Part 11, 5.32, Conformance Rules, 1),
-- # which isn't flagged (#737).
/* flags */
SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'T';
-- flags: F391
-- COL1: 2

/* flags */
SELECT COUNT(*) FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE;
-- flags: F391
-- COL1: 0

/* flags */
SELECT COUNT(*) FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS;
-- flags: F391
-- COL1: 0

/* flags */
SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'T';
-- flags: F391
-- COL1: 1
