-- # The start position and string length of SUBSTRING must be an exact numeric
-- # with scale 0. A host parameter may be any whole number.
VALUES SUBSTRING('hello' FROM 2.5);
-- error 42601: syntax error: SUBSTRING start position must be an exact numeric with scale 0, got NUMERIC(2, 1)

VALUES SUBSTRING('hello' FROM 1 FOR 2.9);
-- error 42601: syntax error: SUBSTRING string length must be an exact numeric with scale 0, got NUMERIC(2, 1)

VALUES SUBSTRING('hello' FROM 1e0);
-- error 42601: syntax error: SUBSTRING start position must be an exact numeric with scale 0, got DOUBLE PRECISION

VALUES SUBSTRING('hello' FROM CAST(2 AS NUMERIC(3)) FOR CAST(2 AS BIGINT));
-- COL1: el

VALUES SUBSTRING('hello' FROM 1 + 1);
-- COL1: ello

/* set pos 2e0 */
VALUES SUBSTRING('hello' FROM :pos);
-- COL1: ello

/* set pos 1.5 */
VALUES SUBSTRING('hello' FROM :pos);
-- error 42601: syntax error: SUBSTRING start position must be a whole number, got 1.5e0

/* set len 2.5e0 */
VALUES SUBSTRING('hello' FROM 1 FOR :len);
-- error 42601: syntax error: SUBSTRING string length must be a whole number, got 2.5e0
