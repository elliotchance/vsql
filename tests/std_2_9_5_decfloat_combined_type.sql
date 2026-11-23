-- # If any type is a DECFLOAT, the combined type is a DECFLOAT with the largest
-- # precision of the DECFLOATs (Syntax Rules, 3.c.ii.1).
/* types */
VALUES CAST(1.5 AS DECFLOAT(16)), 2, 2.25, 3e0;
-- COL1: 1.5 (DECFLOAT(16))
-- COL1: 2 (DECFLOAT(16))
-- COL1: 2.25 (DECFLOAT(16))
-- COL1: 3 (DECFLOAT(16))

/* types */
VALUES CAST(1 AS DECFLOAT(16)), CAST(2 AS DECFLOAT);
-- COL1: 1 (DECFLOAT(34))
-- COL1: 2 (DECFLOAT(34))

/* types */
VALUES ROW(COALESCE(CAST(NULL AS DECFLOAT(16)), 2.5), CASE WHEN TRUE THEN 1 ELSE CAST(2 AS DECFLOAT) END, NULLIF(CAST(1.5 AS DECFLOAT), 1.5), GREATEST(CAST(1 AS DECFLOAT(16)), 2.5, 2e0));
-- COL1: 2.5 (DECFLOAT(16)) COL2: 1 (DECFLOAT(34)) COL3: NULL (DECFLOAT(34)) COL4: 2.5 (DECFLOAT(16))

/* types */
SELECT * FROM (VALUES CAST(1.5 AS DECFLOAT(16))) AS t (x) UNION SELECT * FROM (VALUES 1.50) AS u (x);
-- X: 1.5 (DECFLOAT(16))

-- # A DECFLOAT can't be combined with a type that isn't a number.
VALUES CAST(1 AS DECFLOAT), 'a';
-- error 42804: data type mismatch in row 2, column 1 of VALUES: expected DECFLOAT(34) but got CHARACTER(1)
