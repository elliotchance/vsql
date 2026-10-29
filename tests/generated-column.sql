CREATE TABLE foo (x INT, y INT GENERATED ALWAYS AS (x * 2));
INSERT INTO foo (x) VALUES (1), (2);
INSERT INTO foo (x, y) VALUES (3, DEFAULT);
INSERT INTO foo (x) VALUES (NULL);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: INSERT 1
-- msg: INSERT 1
-- X: 1 Y: 2
-- X: 2 Y: 4
-- X: 3 Y: 6
-- X: NULL Y: NULL

CREATE TABLE foo (x INT, y INT GENERATED ALWAYS AS (x * 2));
INSERT INTO foo (x, y) VALUES (1, 2);
-- msg: CREATE TABLE 1
-- error 428C9: cannot assign a value other than DEFAULT to column Y, which is GENERATED ALWAYS

-- # A generated column is set again when the row is updated.
CREATE TABLE foo (x INT, y INT GENERATED ALWAYS AS (x * 2), z VARCHAR(10));
INSERT INTO foo (x, z) VALUES (1, 'a'), (2, 'b');
UPDATE foo SET x = x + 10 WHERE x = 1;
UPDATE foo SET z = 'c', y = DEFAULT WHERE x = 2;
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: UPDATE 1
-- msg: UPDATE 1
-- X: 11 Y: 22 Z: a
-- X: 2 Y: 4 Z: c

CREATE TABLE foo (x INT, y INT GENERATED ALWAYS AS (x * 2));
INSERT INTO foo (x) VALUES (1);
UPDATE foo SET y = 5;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 428C9: cannot assign a value other than DEFAULT to column Y, which is GENERATED ALWAYS

CREATE TABLE foo (x INT, y INT GENERATED ALWAYS AS (x * 2));
UPDATE foo SET y = DEFAULT;
-- msg: CREATE TABLE 1
-- warning 02000: no data
-- msg: UPDATE 0

-- # The value is cast to the type of the column.
CREATE TABLE foo (x INT, z VARCHAR(3) GENERATED ALWAYS AS ('abc' || 'def'));
INSERT INTO foo (x) VALUES (1);
-- msg: CREATE TABLE 1
-- error 22001: string data right truncation for CHARACTER VARYING(3)

CREATE TABLE foo (x DOUBLE PRECISION, y INT GENERATED ALWAYS AS (x + x));
INSERT INTO foo (x) VALUES (1.3);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- X: 1.3e0 Y: 2

-- # Without a data type, the column has the type of the expression.
CREATE TABLE foo (x VARCHAR(5), y GENERATED ALWAYS AS (x || 'a'), z GENERATED ALWAYS AS (CHAR_LENGTH(x) < 5));
INSERT INTO foo (x) VALUES ('3');
SELECT * FROM foo;
SELECT COLUMN_NAME, DATA_TYPE, IS_GENERATED, GENERATION_EXPRESSION FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'FOO';
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- X: 3 Y: 3a Z: TRUE
-- COLUMN_NAME: X DATA_TYPE: CHARACTER VARYING IS_GENERATED: NEVER GENERATION_EXPRESSION: NULL
-- COLUMN_NAME: Y DATA_TYPE: CHARACTER VARYING IS_GENERATED: ALWAYS GENERATION_EXPRESSION: X || 'a'
-- COLUMN_NAME: Z DATA_TYPE: BOOLEAN IS_GENERATED: ALWAYS GENERATION_EXPRESSION: CHAR_LENGTH(X) < 5

CREATE TABLE foo (x VARCHAR(10), y INT GENERATED ALWAYS AS (x));
-- error 42846: cannot coerce CHARACTER VARYING(10) to INTEGER

CREATE TABLE foo (x INT, y DATE GENERATED ALWAYS AS (x));
-- error 42846: cannot coerce INTEGER to DATE

-- # The expression can only use base columns of the table.
CREATE TABLE foo (x INT, y INT GENERATED ALWAYS AS (x * 2), z INT GENERATED ALWAYS AS (y + 1));
-- error 42601: syntax error: generation expression of Z cannot use generated column Y

CREATE TABLE foo (x INT, y INT GENERATED ALWAYS AS (y + 1));
-- error 42601: syntax error: generation expression of Y cannot use generated column Y

CREATE TABLE foo (x INT, y INT GENERATED ALWAYS AS (w + 1));
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.W

CREATE TABLE bar (w INT);
CREATE TABLE foo (x INT, y INT GENERATED ALWAYS AS (bar.w + 1));
-- msg: CREATE TABLE 1
-- error 42P01: no such table: ":memory:".PUBLIC.BAR

CREATE TABLE bar (w INT);
CREATE TABLE foo (x INT, y INT GENERATED ALWAYS AS ((SELECT w FROM bar)));
-- msg: CREATE TABLE 1
-- error 42601: syntax error: a subquery cannot be used in a generation expression

CREATE TABLE foo (x INT, y INT GENERATED ALWAYS AS (COUNT(x)));
-- error 42601: syntax error: an aggregate function cannot be used in a generation expression

CREATE TABLE foo (x INT, y TIMESTAMP(0) GENERATED ALWAYS AS (CURRENT_TIMESTAMP(0)));
-- error 42601: syntax error: CURRENT_TIMESTAMP(0) cannot be used in a generation expression

CREATE SEQUENCE seq;
CREATE TABLE foo (x INT, y INT GENERATED ALWAYS AS (NEXT VALUE FOR seq));
-- msg: CREATE SEQUENCE 1
-- error 42601: syntax error: NEXT VALUE FOR cannot be used in a generation expression

/* params 1 */
CREATE TABLE foo (x INT, y INT GENERATED ALWAYS AS (x + ?));
-- sql: CREATE TABLE foo (x INT, y INT GENERATED ALWAYS AS (x + 1.0e0))
-- error 42601: syntax error: parameter ?1 cannot be used in a generation expression

CREATE TABLE products (price NUMERIC(10, 2), quantity INTEGER, total NUMERIC(12, 2) GENERATED ALWAYS AS (price * quantity));
INSERT INTO products (price, quantity) VALUES (1.25, 4);
SELECT * FROM products;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- PRICE: 1.25 QUANTITY: 4 TOTAL: 5.00

-- # A generated column can have constraints, which are checked with its value.
CREATE TABLE foo (x INT, y INT GENERATED ALWAYS AS (x * 2) NOT NULL CHECK (y < 10) UNIQUE);
INSERT INTO foo (x) VALUES (1);
INSERT INTO foo (x) VALUES (NULL);
INSERT INTO foo (x) VALUES (5);
INSERT INTO foo (x) VALUES (1);
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 23502: violates non-null constraint: column Y
-- error 23514: violates check constraint: CHECK (Y < 10) on ":memory:".PUBLIC.FOO
-- error 23505: violates unique constraint: UNIQUE (Y) on ":memory:".PUBLIC.FOO

CREATE TABLE foo (x INT, y INT GENERATED ALWAYS AS (x * 2) PRIMARY KEY);
INSERT INTO foo (x) VALUES (1), (2);
UPDATE foo SET x = 3 WHERE x = 1;
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: UPDATE 1
-- X: 2 Y: 4
-- X: 3 Y: 6

-- # ALTER TABLE.
CREATE TABLE foo (x INT, y INT GENERATED ALWAYS AS (x * 2));
ALTER TABLE foo ALTER COLUMN y SET DEFAULT 3;
-- msg: CREATE TABLE 1
-- error 42601: syntax error: cannot set the default of generated column Y

CREATE TABLE foo (x INT, y INT GENERATED ALWAYS AS (x * 2));
ALTER TABLE foo ALTER COLUMN y RESTART;
-- msg: CREATE TABLE 1
-- error 42601: syntax error: column Y is not an identity column

-- # The generation expression is stored with the table.
/* connection 1 */
CREATE TABLE foo (x INT, "a b" INT, "y" INT GENERATED ALWAYS AS (x * 2 + "a b") NOT NULL, z GENERATED ALWAYS AS (CHAR_LENGTH('a''b')));
/* connection 2 */
INSERT INTO foo (x, "a b") VALUES (1, 1);
SELECT * FROM foo;
SELECT COLUMN_NAME, DATA_TYPE, IS_GENERATED, GENERATION_EXPRESSION FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'FOO';
-- 1: msg: CREATE TABLE 1
-- 2: msg: INSERT 1
-- 2: X: 1 a b: 1 y: 3 Z: 3
-- 2: COLUMN_NAME: X DATA_TYPE: INTEGER IS_GENERATED: NEVER GENERATION_EXPRESSION: NULL
-- 2: COLUMN_NAME: a b DATA_TYPE: INTEGER IS_GENERATED: NEVER GENERATION_EXPRESSION: NULL
-- 2: COLUMN_NAME: y DATA_TYPE: INTEGER IS_GENERATED: ALWAYS GENERATION_EXPRESSION: X * 2 + "a b"
-- 2: COLUMN_NAME: Z DATA_TYPE: INTEGER IS_GENERATED: ALWAYS GENERATION_EXPRESSION: CHAR_LENGTH('a''b')

-- # A column that's used by a generation expression can only be dropped with
-- # CASCADE, which also drops the generated column.
CREATE TABLE foo (x INT, w INT, y INT GENERATED ALWAYS AS (x * 2), z INT GENERATED ALWAYS AS (w + 1));
INSERT INTO foo (x, w) VALUES (1, 10);
ALTER TABLE foo DROP COLUMN x;
ALTER TABLE foo DROP COLUMN x CASCADE;
ALTER TABLE foo DROP COLUMN z;
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 2BP01: dependent objects still exist on column Y on ":memory:".PUBLIC.FOO
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- W: 10

CREATE TABLE foo (x INT, y INT GENERATED ALWAYS AS (x * 2));
ALTER TABLE foo DROP COLUMN x CASCADE;
-- msg: CREATE TABLE 1
-- error 42601: syntax error: cannot drop the only column of ":memory:".PUBLIC.FOO

-- # A FOREIGN KEY on a generated column can't change it.
CREATE TABLE p (id INT PRIMARY KEY);
CREATE TABLE c (x INT, y INT GENERATED ALWAYS AS (x) REFERENCES p ON DELETE SET NULL);
CREATE TABLE c (x INT, y INT GENERATED ALWAYS AS (x) REFERENCES p ON UPDATE CASCADE);
CREATE TABLE c (x INT, y INT GENERATED ALWAYS AS (x) REFERENCES p ON DELETE CASCADE);
-- msg: CREATE TABLE 1
-- error 42601: syntax error: FOREIGN KEY on generated column Y cannot use ON DELETE SET NULL
-- error 42601: syntax error: FOREIGN KEY on generated column Y cannot use ON UPDATE CASCADE
-- msg: CREATE TABLE 1

-- # A generated column is set again when a referential action changes the row.
CREATE TABLE p (id INT PRIMARY KEY);
CREATE TABLE c (x INT REFERENCES p ON UPDATE CASCADE ON DELETE SET NULL, y INT GENERATED ALWAYS AS (x * 10));
INSERT INTO p (id) VALUES (1), (2);
INSERT INTO c (x) VALUES (1), (2);
UPDATE p SET id = 3 WHERE id = 1;
DELETE FROM p WHERE id = 2;
SELECT * FROM c;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: INSERT 2
-- msg: UPDATE 1
-- msg: DELETE 1
-- X: 3 Y: 30
-- X: NULL Y: NULL

-- # An override clause doesn't allow a value for a generated column.
CREATE TABLE foo (id INT GENERATED ALWAYS AS IDENTITY, x INT, y INT GENERATED ALWAYS AS (x * 10));
INSERT INTO foo (id, x, y) OVERRIDING SYSTEM VALUE VALUES (10, 1, 5);
INSERT INTO foo (id, x, y) OVERRIDING USER VALUE VALUES (10, 1, 5);
INSERT INTO foo (id, x, y) OVERRIDING SYSTEM VALUE VALUES (10, 1, DEFAULT);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- error 428C9: cannot assign a value other than DEFAULT to column Y, which is GENERATED ALWAYS
-- error 428C9: cannot assign a value other than DEFAULT to column Y, which is GENERATED ALWAYS
-- msg: INSERT 1
-- ID: 10 X: 1 Y: 10
