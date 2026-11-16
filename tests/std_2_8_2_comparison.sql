-- # Each comparison operator, with operands that are equal and that differ.
VALUES 1 = 2;
VALUES 1 = 1;
VALUES 1 <> 2;
VALUES 1 <> 1;
VALUES 1 > 2;
VALUES 1 > 1;
VALUES 1 >= 2;
VALUES 1 >= 1;
VALUES 1 < 2;
VALUES 1 < 1;
-- COL1: FALSE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: FALSE
-- COL1: FALSE
-- COL1: FALSE
-- COL1: FALSE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: FALSE

VALUES 1 <= 2;
VALUES 1 <= 1;
-- COL1: TRUE
-- COL1: TRUE

-- # Exact numbers are compared by their value, whatever their precision or
-- # scale.
VALUES 1.0 = 1;
VALUES CAST(1.0 AS NUMERIC(5, 3)) = CAST(1 AS NUMERIC(5, 4));
VALUES CAST(1.0 AS DECIMAL(5, 3)) = CAST(1 AS DECIMAL(5, 4));
VALUES CAST(1.0 AS DECIMAL) = CAST(1 AS DECIMAL);
VALUES CAST(1.0 AS DECIMAL) = 1;
VALUES CAST(1 AS DECIMAL) = 1.0;
-- COL1: TRUE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: TRUE
-- COL1: TRUE
