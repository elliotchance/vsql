-- # LIKE and SIMILAR TO of a CHARACTER LARGE OBJECT are Feature T042 (8.5,
-- # Conformance Rules, 5 and 6, and 8.6, Conformance Rules, 2).
/* flags */
VALUES CAST('abc' AS CLOB) LIKE 'a%';
-- flags: F281, F641, F661, T042, T046
-- COL1: TRUE

/* flags */
VALUES 'abc' LIKE CAST('a%' AS CLOB);
-- flags: F281, F641, F661, T042, T046
-- COL1: TRUE

/* flags */
VALUES CAST('abc' AS CLOB) SIMILAR TO 'a%';
-- flags: F641, F661, T042, T046, T141
-- COL1: TRUE
