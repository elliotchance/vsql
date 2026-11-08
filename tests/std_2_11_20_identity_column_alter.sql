-- # A table can only have one identity column, so one can't be added to a table
-- # that has one (11.11, Syntax Rules, 3).
CREATE TABLE foo (id INT GENERATED ALWAYS AS IDENTITY);
ALTER TABLE foo ADD COLUMN id2 INT GENERATED ALWAYS AS IDENTITY;
-- msg: CREATE TABLE 1
-- error 42601: syntax error: table ":memory:".PUBLIC.FOO has more than one identity column

-- # Each existing row gets the next value when an identity column is added.
CREATE TABLE foo (x INT);
INSERT INTO foo (x) VALUES (1), (2);
ALTER TABLE foo ADD COLUMN id INT GENERATED ALWAYS AS IDENTITY (START WITH 10);
INSERT INTO foo (x) VALUES (3);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: ALTER TABLE 1
-- msg: INSERT 1
-- X: 1 ID: 10
-- X: 2 ID: 11
-- X: 3 ID: 12

CREATE TABLE foo (x INT);
ALTER TABLE foo ADD COLUMN id INT GENERATED ALWAYS AS IDENTITY;
INSERT INTO foo (x) VALUES (1);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: ALTER TABLE 1
-- msg: INSERT 1
-- X: 1 ID: 1

-- # If the sequence runs out while the existing rows are given values, the
-- # ALTER fails and the column isn't added (9.29, General Rules, 3.a).
CREATE TABLE foo (x INT);
INSERT INTO foo (x) VALUES (1), (2);
ALTER TABLE foo ADD COLUMN id SMALLINT GENERATED ALWAYS AS IDENTITY (START WITH 32767);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- error 2200H: sequence generator limit exceeded: ":memory:".PUBLIC.FOO.ID
-- X: 1
-- X: 2

-- # The options change the sequence of the column like an ALTER SEQUENCE
-- # (General Rules, 1). A value past the MAXVALUE is an error (9.29, General
-- # Rules, 3.a), and RESTART without a value goes back to the start value
-- # (9.31, Syntax Rules, 9.c).
CREATE TABLE foo (id INT GENERATED ALWAYS AS IDENTITY, x INT);
INSERT INTO foo (x) VALUES (1);
ALTER TABLE foo ALTER COLUMN id RESTART WITH 50;
INSERT INTO foo (x) VALUES (2);
ALTER TABLE foo ALTER COLUMN id SET INCREMENT BY 5 SET MAXVALUE 60;
INSERT INTO foo (x) VALUES (3);
INSERT INTO foo (x) VALUES (4);
INSERT INTO foo (x) VALUES (5);
ALTER TABLE foo ALTER COLUMN id RESTART SET NO MAXVALUE;
INSERT INTO foo (x) VALUES (6);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: ALTER TABLE 1
-- msg: INSERT 1
-- msg: ALTER TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- error 2200H: sequence generator limit exceeded: ":memory:".PUBLIC.FOO.ID
-- msg: ALTER TABLE 1
-- msg: INSERT 1
-- ID: 1 X: 1
-- ID: 50 X: 2
-- ID: 55 X: 3
-- ID: 60 X: 4
-- ID: 1 X: 6

-- # RESTART WITH changes the next value, not the start value. NO MINVALUE and
-- # NO MAXVALUE are implementation-defined (9.31, Syntax Rules, 6.a.i and
-- # 7.a.i): for a descending sequence they're the smallest SMALLINT and -1.
CREATE TABLE foo (id SMALLINT GENERATED ALWAYS AS IDENTITY);
ALTER TABLE foo ALTER COLUMN id SET INCREMENT BY -1 SET NO MINVALUE SET NO MAXVALUE RESTART WITH -1;
SELECT IDENTITY_START, IDENTITY_INCREMENT, IDENTITY_MINIMUM, IDENTITY_MAXIMUM FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'FOO';
-- msg: CREATE TABLE 1
-- msg: ALTER TABLE 1
-- IDENTITY_START: 1 IDENTITY_INCREMENT: -1 IDENTITY_MINIMUM: -32768 IDENTITY_MAXIMUM: -1

-- # The options are checked like those of an ALTER SEQUENCE: a limit must fit
-- # in the type of the column (9.31, Syntax Rules, 10), INCREMENT BY can't be 0
-- # (9.31, Syntax Rules, 5.a.ii), and an option can only be given once (9.31,
-- # Syntax Rules, 4).
CREATE TABLE foo (id SMALLINT GENERATED ALWAYS AS IDENTITY);
ALTER TABLE foo ALTER COLUMN id SET MAXVALUE 40000;
-- msg: CREATE TABLE 1
-- error 42601: syntax error: MAXVALUE (40000) is out of range for SMALLINT

CREATE TABLE foo (id INT GENERATED ALWAYS AS IDENTITY);
ALTER TABLE foo ALTER COLUMN id SET INCREMENT BY 0;
-- msg: CREATE TABLE 1
-- error 42601: syntax error: INCREMENT BY must not be 0

CREATE TABLE foo (id INT GENERATED ALWAYS AS IDENTITY);
ALTER TABLE foo ALTER COLUMN id RESTART RESTART WITH 2;
-- msg: CREATE TABLE 1
-- error 42601: syntax error: RESTART is specified more than once

-- # Only an identity column has a sequence to alter (11.12, Syntax Rules, 7).
CREATE TABLE foo (id INT);
ALTER TABLE foo ALTER COLUMN id RESTART;
-- msg: CREATE TABLE 1
-- error 42601: syntax error: column ID is not an identity column

-- # An identity column that's added after one is dropped starts again.
CREATE TABLE foo (id INT GENERATED ALWAYS AS IDENTITY (START WITH 5), x INT);
INSERT INTO foo (x) VALUES (1);
ALTER TABLE foo DROP COLUMN id RESTRICT;
ALTER TABLE foo ADD COLUMN id INT GENERATED ALWAYS AS IDENTITY;
INSERT INTO foo (x) VALUES (2);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: INSERT 1
-- X: 1 ID: 1
-- X: 2 ID: 2

-- # The NOT NULL of an identity column can't be dropped (#790).
CREATE TABLE foo (id INT GENERATED ALWAYS AS IDENTITY, x INT);
ALTER TABLE foo DROP CONSTRAINT foo_not_null_1 RESTRICT;
INSERT INTO foo (x) VALUES (1);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- error 42601: syntax error: column ID is an identity column, so its NOT NULL cannot be dropped
-- msg: INSERT 1
-- ID: 1 X: 1
