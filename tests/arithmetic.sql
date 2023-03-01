/* types */
VALUES 1 + 2;
-- COL1: 3 (SMALLINT)

/* types */
VALUES 1 - 2;
-- COL1: -1 (SMALLINT)

/* types */
VALUES 2 * 3;
-- COL1: 6 (SMALLINT)

/* types */
VALUES 6 / 2;
-- COL1: 3 (SMALLINT)

/* types */
VALUES 1.2 + 2.4;
-- COL1: 3.6 (NUMERIC(2, 1))

/* types */
VALUES 1.7 - 0.5;
-- COL1: 1.2 (NUMERIC(2, 1))

/* types */
VALUES 2.2 * 3.3;
-- COL1: 7.26 (NUMERIC(4, 2))

/* types */
VALUES 6.0 / 2.5;
-- COL1: 2.40 (NUMERIC(4, 2))

/* types */
VALUES 0.0 / 2.5;
-- COL1: 0.00 (NUMERIC(4, 2))

/* types */
VALUES 2.5 / 0.0;
-- error 22012: division by zero

/* types */
VALUES -123;
-- COL1: -123 (SMALLINT)

/* types */
VALUES +1.23;
-- COL1: 1.23 (NUMERIC(3, 2))

/* types */
VALUES 1.5 + 2.4 * 7.0;
-- COL1: 18.30 (NUMERIC(4, 2))

VALUES 30000 + 30000;
-- error 22003: numeric value out of range

VALUES CAST(30000 AS INTEGER) + 30000;
-- COL1: 60000

VALUES 12 * 10.5e0;
-- error 42883: operator does not exist: SMALLINT * DOUBLE PRECISION

VALUES CAST(12 AS DOUBLE PRECISION) * 10.5e0;
-- COL1: 126e0

VALUES 12 * CAST(10.5e0 AS INTEGER);
-- COL1: 120
