/* types */
VALUES 1;
-- COL1: 1 (NUMERIC)

/* types */
VALUES 1.23;
-- COL1: 1.23 (NUMERIC)

/* types */
VALUES 1.;
-- COL1: 1 (NUMERIC)

/* types */
VALUES .23;
-- COL1: 0.23 (NUMERIC)

/* types */
VALUES 789;
-- COL1: 789 (NUMERIC)

/* types */
VALUES 'hello';
-- COL1: hello (CHARACTER(5))

/* types */
VALUES ROW(123, 456);
-- COL1: 123 (NUMERIC) COL2: 456 (NUMERIC)

/* types */
VALUES ROW(2 + 3 * 5, (2 + 3) * 5);
-- COL1: 17 (INTEGER) COL2: 25 (INTEGER)
