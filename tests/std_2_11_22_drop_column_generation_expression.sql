-- # DROP EXPRESSION makes a generated column a base column (General Rules, 2).
-- # The rows keep their values, which aren't generated again, and a value can
-- # be assigned to the column.
CREATE TABLE foo (x INT, y INT GENERATED ALWAYS AS (x * 2));
INSERT INTO foo (x) VALUES (1), (2);
ALTER TABLE foo ALTER COLUMN y DROP EXPRESSION;
UPDATE foo SET x = x + 10;
INSERT INTO foo (x, y) VALUES (3, 30);
INSERT INTO foo (x) VALUES (4);
UPDATE foo SET y = 0 WHERE x = 12;
SELECT * FROM foo;
SELECT IS_GENERATED, GENERATION_EXPRESSION FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'FOO' AND COLUMN_NAME = 'Y';
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: ALTER TABLE 1
-- msg: UPDATE 2
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: UPDATE 1
-- X: 11 Y: 2
-- X: 12 Y: 0
-- X: 3 Y: 30
-- X: 4 Y: NULL
-- IS_GENERATED: NEVER GENERATION_EXPRESSION: NULL

-- # The column keeps the data type that was inferred from the expression, and
-- # its NOT NULL. Without the optional COLUMN.
CREATE TABLE foo (x VARCHAR(5), y GENERATED ALWAYS AS (x || '!') NOT NULL);
INSERT INTO foo (x) VALUES ('hi');
ALTER TABLE foo ALTER y DROP EXPRESSION;
INSERT INTO foo (x) VALUES ('bye');
/* out */
/* in */
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: ALTER TABLE 1
-- error 23502: violates non-null constraint: column Y
-- out: CREATE TABLE "PUBLIC"."FOO" (
-- out:   "X" CHARACTER VARYING(5),
-- out:   "Y" CHARACTER VARYING(6) NOT NULL
-- out: );
-- out: INSERT INTO "PUBLIC"."FOO" ("X", "Y") VALUES ('hi', 'hi!');
-- X: hi Y: hi!

-- # The column no longer uses the columns of its expression, so they can be
-- # dropped without CASCADE.
CREATE TABLE foo (x INT, y INT GENERATED ALWAYS AS (x * 2), z INT);
INSERT INTO foo (x, z) VALUES (1, 5);
ALTER TABLE foo DROP COLUMN x RESTRICT;
ALTER TABLE foo ALTER COLUMN y DROP EXPRESSION;
ALTER TABLE foo DROP COLUMN x RESTRICT;
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 2BP01: dependent objects still exist on column Y on ":memory:".PUBLIC.FOO
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- Y: 2 Z: 5

-- # Only a generated column has an expression to drop (11.12, Syntax Rules, 8),
-- # and an identity column isn't a generated column.
CREATE TABLE foo (x INT DEFAULT 1);
ALTER TABLE foo ALTER COLUMN x DROP EXPRESSION;
-- msg: CREATE TABLE 1
-- error 42601: syntax error: column X is not a generated column

CREATE TABLE foo (id INT GENERATED ALWAYS AS IDENTITY);
ALTER TABLE foo ALTER COLUMN id DROP EXPRESSION;
-- msg: CREATE TABLE 1
-- error 42601: syntax error: column ID is not a generated column

-- # A ROLLBACK brings back the generation expression.
CREATE TABLE foo (x INT, y INT GENERATED ALWAYS AS (x + 1));
START TRANSACTION;
ALTER TABLE foo ALTER COLUMN y DROP EXPRESSION;
ROLLBACK;
INSERT INTO foo (x) VALUES (1);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: ALTER TABLE 1
-- msg: ROLLBACK
-- msg: INSERT 1
-- X: 1 Y: 2

-- # DROP EXPRESSION needs F385 (Conformance Rules, 1), as well as F387 for
-- # ALTER COLUMN.
/* flags */
ALTER TABLE foo ALTER COLUMN y DROP EXPRESSION;
-- flags: F385, F387
-- error 42P01: no such table: ":memory:".PUBLIC.FOO
