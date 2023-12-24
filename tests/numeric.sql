CREATE TABLE foo (bar NUMERIC);
-- error 42601: syntax error: column BAR: NUMERIC must specify a size

CREATE TABLE foo (bar NUMERIC(4, 2));
INSERT INTO foo (bar) VALUES (1.23);
INSERT INTO foo (bar) VALUES (12345);
INSERT INTO foo (bar) VALUES (-1.24);
SELECT * FROM foo;
SELECT -bar FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 22003: numeric value out of range
-- msg: INSERT 1
-- BAR: 1.23
-- BAR: -1.24
-- COL1: -1.23
-- COL1: 1.24

VALUES 0.001;
VALUES .23;
VALUES -.23;
-- COL1: 0.001
-- COL1: 0.23
-- COL1: -0.23

VALUES CAST(1.23 AS NUMERIC(10, 6));
-- COL1: 1.23

VALUES CAST(1.23 AS NUMERIC(10, 2));
-- COL1: 1.23

VALUES CAST(1.23 AS NUMERIC(10, 1));
-- COL1: 1.2

VALUES CAST(1234.5 AS NUMERIC(3, 0));
-- error 22003: numeric value out of range

VALUES CAST(-1.23 AS NUMERIC);
-- COL1: -1.23

VALUES CAST(-12.34 AS NUMERIC(4, 2));
-- COL1: -12.34

VALUES CAST(-12.34 AS NUMERIC(4, 1));
-- COL1: -12.3

VALUES CAST(-12.34 AS NUMERIC(2, 0));
-- COL1: -12

VALUES CAST(-12.34 AS NUMERIC(3, 2));
-- error 22003: numeric value out of range

VALUES CAST(1.23 AS NUMERIC(6, 2)) + CAST(1.5 AS NUMERIC(6, 3));
-- COL1: 2.73

VALUES CAST(1.23 AS NUMERIC(6, 2)) - CAST(1.5 AS NUMERIC(6, 3));
-- COL1: -0.27

VALUES CAST(1.23 AS NUMERIC(6, 2)) - CAST(-1.5 AS NUMERIC(6, 3));
-- COL1: 2.73

VALUES CAST(1.23 AS NUMERIC(6, 2)) * CAST(1.5 AS NUMERIC(6, 3));
-- COL1: 1.845

VALUES CAST(CAST(1.23 AS NUMERIC(6, 2)) * CAST(1.5 AS NUMERIC(6, 3)) AS NUMERIC(6, 4));
-- COL1: 1.845

VALUES CAST(1.24 AS NUMERIC(6, 2)) / CAST(1.5 AS NUMERIC(6, 3));
-- COL1: 0.82666

VALUES CAST(1.24 AS NUMERIC(6, 3)) / CAST(1.5 AS NUMERIC(6, 2));
-- COL1: 0.82666

VALUES CAST(CAST(1.24 AS NUMERIC(6, 2)) / CAST(1.5 AS NUMERIC(6, 3)) AS NUMERIC(6, 4));
-- COL1: 0.8266

VALUES CAST(1.23 AS NUMERIC(3,2)) / 5;
-- COL1: 0.24

VALUES CAST(CAST(1.23 AS NUMERIC(3,2)) / 5 AS NUMERIC(4, 3));
-- COL1: 0.246

-- # This is an important case because it's described in detail in the docs for
-- # NUMERIC vs DECIMAL.
VALUES CAST(1.23 AS NUMERIC(3,2)) / 5 * 5;
-- COL1: 1.23

-- # This is an important case because it's described in detail in the docs for
-- # NUMERIC vs DECIMAL.
VALUES CAST(1.23 AS NUMERIC(3,2)) / 11;
-- COL1: 0.11

-- # This is an important case because it's described in detail in the docs for
-- # NUMERIC vs DECIMAL.
VALUES CAST(CAST(5 AS NUMERIC(3,2)) / CAST(7 AS NUMERIC(5,4)) AS NUMERIC(5,4));
-- COL1: 0.7142

/* types */
VALUES CAST(10.24 AS NUMERIC(4,2)) + CAST(12.123 AS NUMERIC(8,3));
-- COL1: 22.36 (NUMERIC(8, 3))

/* types */
VALUES CAST(10.24 AS NUMERIC(4,2)) * CAST(12.123 AS NUMERIC(8,3));
-- COL1: 124.13952 (NUMERIC(32, 5))