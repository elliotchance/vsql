-- # A CAST of a CHARACTER LARGE OBJECT or BINARY LARGE OBJECT is Feature T042
-- # (6.13, Conformance Rules, 1 and 3).
/* flags */
VALUES CAST(CAST('ab' AS CLOB) AS VARCHAR(5));
-- flags: F641, F661, T042, T046
-- COL1: ab

/* flags */
VALUES CAST(CAST(X'01' AS BLOB) AS VARBINARY(5));
-- flags: F641, F661, T021, T042, T045
-- COL1: 01
