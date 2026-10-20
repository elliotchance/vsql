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
-- COL1: 3.6 (NUMERIC(3, 1))

/* types */
VALUES 1.7 - 0.5;
-- COL1: 1.2 (NUMERIC(3, 1))

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
-- COL1: 18.30 (NUMERIC(5, 2))

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

/* types */
VALUES 1 + 2.5;
-- COL1: 3.5 (NUMERIC(7, 1))

/* types */
VALUES 2.5 + 1;
-- COL1: 3.5 (NUMERIC(7, 1))

VALUES 1 - 0.5;
-- COL1: 0.5

VALUES CAST(1 AS INTEGER) + 0.5;
-- COL1: 1.5

VALUES CAST(1 AS BIGINT) - 0.25;
-- COL1: 0.75

VALUES 3 * 0.5;
-- COL1: 1.5

/* types */
VALUES CAST(1.5 AS NUMERIC(2,1)) + CAST(1.25 AS DECIMAL(3,2));
-- COL1: 2.75 (DECIMAL(4, 2))

/* types */
VALUES CAST(1.25 AS DECIMAL(3,2)) + CAST(1.5 AS NUMERIC(2,1));
-- COL1: 2.75 (DECIMAL(4, 2))

/* types */
VALUES 9.9 + 9.9;
-- COL1: 19.8 (NUMERIC(3, 1))

CREATE TABLE t (x INT, n NUMERIC(5,2));
INSERT INTO t (x, n) VALUES (1, 2.5);
SELECT x + n, n + x, x - n, x * n FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 3.50 COL2: 3.50 COL3: -1.50 COL4: 2.50
