-- # The shorter of two character strings is padded with spaces before they're
-- # compared (8.2, General Rules, 3.b), so trailing spaces don't matter but
-- # leading spaces do (E021-12).
VALUES ROW(1, 'hello' = 'hello   ');
VALUES ROW(2, 'hello  ' = 'hello');
VALUES ROW(3, 'hello  ' = 'hello  ');
VALUES ROW(4, '  hello' = 'hello');
VALUES ROW(5, 'hello' = '  hello');
VALUES ROW(6, '  hello' = '  hello');
-- COL1: 1 COL2: TRUE
-- COL1: 2 COL2: TRUE
-- COL1: 3 COL2: TRUE
-- COL1: 4 COL2: FALSE
-- COL1: 5 COL2: FALSE
-- COL1: 6 COL2: TRUE

-- # Datetimes are only comparable if they have the same fields.
VALUES DATE '2020-01-01' = TIMESTAMP '2020-01-01 00:00:00';
-- error 42883: cannot compare DATE and TIMESTAMP(0) WITHOUT TIME ZONE

VALUES DATE '2020-01-01' = TIME '00:00:00';
-- error 42883: cannot compare DATE and TIME(0) WITHOUT TIME ZONE

VALUES TIME '00:00:00' < TIMESTAMP '2020-01-01 00:00:00';
-- error 42883: cannot compare TIME(0) WITHOUT TIME ZONE and TIMESTAMP(0) WITHOUT TIME ZONE

-- # A datetime can be cast to have the same fields, and times with a time zone
-- # are compared.
VALUES ROW(DATE '2020-01-01' = CAST(TIMESTAMP '2020-01-01 10:00:00' AS DATE), TIMESTAMP '2020-01-01 00:00:00+00:00' = TIMESTAMP '2020-01-01 00:00:00+00:00');
-- COL1: TRUE COL2: TRUE
