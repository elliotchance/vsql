/* types */
VALUES 1 + 2;
-- COL1: 3 (INTEGER)

/* types */
VALUES 1 - 2;
-- COL1: -1 (INTEGER)

/* types */
VALUES 2 * 3;
-- COL1: 6 (INTEGER)

/* types */
VALUES 6 / 2;
-- COL1: 3 (INTEGER)

/* types */
VALUES 1.2 + 2.4;
-- COL1: 3.6 (DOUBLE PRECISION)

/* types */
VALUES 1.7 - 0.5;
-- COL1: 1.2 (DOUBLE PRECISION)

/* types */
VALUES 2.2 * 3.3;
-- COL1: 7.26 (DOUBLE PRECISION)

/* types */
VALUES 6.0 / 2.5;
-- COL1: 2.4 (DOUBLE PRECISION)

/* types */
VALUES 0.0 / 2.5;
-- COL1: 0 (DOUBLE PRECISION)

/* types */
VALUES 2.5 / 0.0;
-- error 22012: division by zero

/* types */
VALUES -123;
-- COL1: -123 (NUMERIC)

/* types */
VALUES +1.23;
-- COL1: 1.23 (NUMERIC)

/* types */
VALUES 1.5 + 2.4 * 7.0;
-- COL1: 18.3 (DOUBLE PRECISION)
