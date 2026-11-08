-- # Each column of a VALUES has the combined type of every row, and each value
-- # is converted to it.
/* types */
VALUES TIME '12:00:00', TIME '13:00:00.123';
-- COL1: 12:00:00.000 (TIME(3) WITHOUT TIME ZONE)
-- COL1: 13:00:00.123 (TIME(3) WITHOUT TIME ZONE)

/* types */
VALUES TIMESTAMP '2024-01-02 12:00:00', TIMESTAMP '2024-01-02 13:00:00.12';
-- COL1: 2024-01-02T12:00:00.00 (TIMESTAMP(2) WITHOUT TIME ZONE)
-- COL1: 2024-01-02T13:00:00.12 (TIMESTAMP(2) WITHOUT TIME ZONE)

/* types */
VALUES 'a', 'abc';
-- COL1: a   (CHARACTER(3))
-- COL1: abc (CHARACTER(3))

/* types */
VALUES 'a', CAST('abc' AS VARCHAR(5));
-- COL1: a (CHARACTER VARYING(5))
-- COL1: abc (CHARACTER VARYING(5))

/* types */
VALUES 1.5, 22.25;
-- COL1: 1.50 (NUMERIC(4, 2))
-- COL1: 22.25 (NUMERIC(4, 2))

/* types */
VALUES 1, 22.25;
-- COL1: 1.00 (NUMERIC(7, 2))
-- COL1: 22.25 (NUMERIC(7, 2))

/* types */
VALUES CAST(1.5 AS DECIMAL(2, 1)), 22.25;
-- COL1: 1.50 (DECIMAL(4, 2))
-- COL1: 22.25 (DECIMAL(4, 2))

/* types */
VALUES 1, 1.5e0;
-- COL1: 1e0 (DOUBLE PRECISION)
-- COL1: 1.5e0 (DOUBLE PRECISION)

/* types */
VALUES ROW(1, 'a'), ROW(2.5, 'bcd');
-- COL1: 1.0 (NUMERIC(6, 1)) COL2: a   (CHARACTER(3))
-- COL1: 2.5 (NUMERIC(6, 1)) COL2: bcd (CHARACTER(3))

-- # A NUMERIC without a precision has no limit, so each value keeps its own
-- # precision and scale.
/* types */
VALUES 1.5, 7, ABS(CAST(2.25 AS NUMERIC));
-- COL1: 1.5 (NUMERIC(2, 1))
-- COL1: 7 (NUMERIC)
-- COL1: 2 (NUMERIC)

-- # COALESCE also converts to the combined type.
/* types */
VALUES COALESCE(CAST(NULL AS NUMERIC(2, 1)), 22.25), COALESCE(1.5, 22.25);
-- COL1: 22.25 (NUMERIC(4, 2))
-- COL1: 1.50 (NUMERIC(4, 2))

/* types */
VALUES COALESCE('a', 'abc');
-- COL1: a   (CHARACTER(3))

/* types */
VALUES COALESCE(TIME '12:00:00', TIME '13:00:00.123');
-- COL1: 12:00:00.000 (TIME(3) WITHOUT TIME ZONE)
