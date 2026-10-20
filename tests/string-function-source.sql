-- # SUBSTRING and TRIM need a character string source, and the TRIM character
-- # must be comparable with it.
VALUES SUBSTRING(123 FROM 1 FOR 2);
-- error 42883: function does not exist: SUBSTRING(SMALLINT)

VALUES SUBSTRING(DATE '2024-01-02' FROM 1);
-- error 42883: function does not exist: SUBSTRING(DATE)

VALUES TRIM(' ' FROM 123);
-- error 42883: function does not exist: TRIM(SMALLINT)

VALUES TRIM(TRUE);
-- error 42883: function does not exist: TRIM(BOOLEAN)

VALUES TRIM(123 FROM 'abc');
-- error 42883: function does not exist: TRIM(SMALLINT FROM CHARACTER(3))

/* types */
VALUES SUBSTRING(CAST(NULL AS VARCHAR(5)) FROM 1);
-- COL1: NULL (CHARACTER VARYING(5))

/* types */
VALUES TRIM('x' FROM CAST('xax' AS VARCHAR(5)));
-- COL1: a (CHARACTER VARYING(5))
