EXPLAIN VALUES NULLIF(TRUE, TRUE);
-- EXPLAIN: VALUES (COL1 BOOLEAN) = ROW(NULLIF(TRUE, TRUE))

/* types */
VALUES NULLIF(123, 123);
-- COL1: NULL (SMALLINT)

/* types */
VALUES NULLIF(123, 456);
-- COL1: 123 (SMALLINT)

VALUES NULLIF(123, 'hello');
-- error 42804: data type mismatch in NULLIF: expected SMALLINT but got CHARACTER(5)
