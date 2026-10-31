-- # F812 Basic flagging of a boolean predicand of a comparison (T031) and of the
-- # INFORMATION_SCHEMA views, which are flagged with F391 since the schema name
-- # is 18 characters (#737, #738).
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
