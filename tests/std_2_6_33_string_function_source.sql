-- # SUBSTRING and TRIM need a character string source, and the TRIM character
-- # must be comparable with it.
VALUES SUBSTRING(123 FROM 1 FOR 2);
VALUES SUBSTRING(DATE '2024-01-02' FROM 1);
VALUES TRIM(' ' FROM 123);
VALUES TRIM(TRUE);
VALUES TRIM(123 FROM 'abc');
-- error 42883: function does not exist: SUBSTRING(SMALLINT)
-- error 42883: function does not exist: SUBSTRING(DATE)
-- error 42883: function does not exist: TRIM(SMALLINT)
-- error 42883: function does not exist: TRIM(BOOLEAN)
-- error 42883: function does not exist: TRIM(SMALLINT FROM CHARACTER(3))

-- # A NULL source gives NULL (General Rules, 3.d), and the result is a
-- # CHARACTER VARYING as long as the source (Syntax Rules, 4.a.i and 13.b.i).
/* types */
VALUES SUBSTRING(CAST(NULL AS VARCHAR(5)) FROM 1);
-- COL1: NULL (CHARACTER VARYING(5))

/* types */
VALUES TRIM('x' FROM CAST('xax' AS VARCHAR(5)));
-- COL1: a (CHARACTER VARYING(5))
