-- # A cast between NUMERIC and DECIMAL without a size (such as for the argument
-- # of a function) changes the type, but keeps the precision and scale.
/* types */
VALUES MOD(CAST(7.5 AS DECIMAL(2,1)), CAST(2 AS NUMERIC(1)));
-- COL1: 1.5 (NUMERIC(4, 1))

/* types */
VALUES FLOOR(CAST(1.5 AS DECIMAL(2,1)));
-- COL1: 1 (NUMERIC(1))
