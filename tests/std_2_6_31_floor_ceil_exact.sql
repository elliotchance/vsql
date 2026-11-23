-- # FLOOR and CEIL of an exact number have scale 0 and the radix of the
-- # argument (Syntax Rules, 20.a), so they're a NUMERIC for a NUMERIC or DECIMAL,
-- # and keep the type of a SMALLINT, INTEGER or BIGINT. FLOOR rounds down and CEIL rounds up, so for a negative number FLOOR
-- # moves away from zero (General Rules, 15.b.i and 16.b.i).
/* types */
VALUES ROW(FLOOR(-3), FLOOR(-3.0), FLOOR(CAST(-3 AS NUMERIC(5, 2))), FLOOR(-3.5), FLOOR(-0.5));
-- COL1: -3 (INTEGER) COL2: -3 (NUMERIC(2)) COL3: -3 (NUMERIC(4)) COL4: -4 (NUMERIC(2)) COL5: -1 (NUMERIC(2))

/* types */
VALUES ROW(FLOOR(3), FLOOR(3.0), FLOOR(3.5), FLOOR(0), FLOOR(CAST(5.5 AS DECIMAL(4, 1))));
-- COL1: 3 (INTEGER) COL2: 3 (NUMERIC(2)) COL3: 3 (NUMERIC(2)) COL4: 0 (INTEGER) COL5: 5 (NUMERIC(4))

/* types */
VALUES ROW(CEIL(3), CEIL(3.0), CEIL(CAST(3 AS NUMERIC(5, 2))), CEIL(3.5), CEIL(0.5));
-- COL1: 3 (INTEGER) COL2: 3 (NUMERIC(2)) COL3: 3 (NUMERIC(4)) COL4: 4 (NUMERIC(2)) COL5: 1 (NUMERIC(2))

/* types */
VALUES ROW(CEILING(-3), CEILING(-3.0), CEILING(-3.5), CEILING(-0.5), CEILING(CAST(-5.5 AS DECIMAL(4, 1))));
-- COL1: -3 (INTEGER) COL2: -3 (NUMERIC(2)) COL3: -3 (NUMERIC(2)) COL4: 0 (NUMERIC(2)) COL5: -5 (NUMERIC(4))

-- # An integer is already rounded, so it's the same value for each integer type.
/* types */
VALUES ROW(FLOOR(CAST(-32768 AS SMALLINT)), CEIL(CAST(2147483647 AS INTEGER)), CEILING(CAST(9223372036854775807 AS BIGINT)));
-- COL1: -32768 (SMALLINT) COL2: 2147483647 (INTEGER) COL3: 9223372036854775807 (BIGINT)
