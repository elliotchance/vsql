/* setup */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1), (2), (3);
CREATE TABLE t2 (x INT);
CREATE SEQUENCE seq;

-- # A constant expression is only evaluated once, but it's still the value of
-- # each row and keeps its type.
/* types */
SELECT x, 1 + 2, -(2 * 3), CAST('3' AS INT), ABS(-3), 1.5 + 1.5 FROM t;
-- X: 1 (INTEGER) COL2: 3 (SMALLINT) COL3: -6 (SMALLINT) COL4: 3 (INTEGER) COL5: 3 (SMALLINT) COL6: 3.0 (NUMERIC(3, 1))
-- X: 2 (INTEGER) COL2: 3 (SMALLINT) COL3: -6 (SMALLINT) COL4: 3 (INTEGER) COL5: 3 (SMALLINT) COL6: 3.0 (NUMERIC(3, 1))
-- X: 3 (INTEGER) COL2: 3 (SMALLINT) COL3: -6 (SMALLINT) COL4: 3 (INTEGER) COL5: 3 (SMALLINT) COL6: 3.0 (NUMERIC(3, 1))

SELECT x FROM t WHERE x = 1 + 1;
-- X: 2

SELECT x FROM t WHERE x > ABS(-1) * 2 - 1;
-- X: 2
-- X: 3

-- # A constant expression is part of an expression that isn't constant.
SELECT x + (1 + 2) * 2 FROM t;
-- COL1: 7
-- COL1: 8
-- COL1: 9

-- # An error is only raised if there's a row.
SELECT x FROM t2 WHERE x = 1 / 0;

SELECT 1 / 0 FROM t2;

SELECT x FROM t WHERE x = 1 / 0;
-- error 22012: division by zero

SELECT CAST('a' AS INT) FROM t;
-- error 22018: invalid character value for cast

-- # A parameter is constant.
/* params 2 */
SELECT x FROM t WHERE x = ? + 1;
-- sql: SELECT x FROM t WHERE x = 2.0e0 + 1
-- X: 3

-- # NEXT VALUE FOR is never constant.
SELECT NEXT VALUE FOR seq + 1 FROM t;
-- COL1: 2
-- COL1: 3
-- COL1: 4

-- # A CAST to a string adds a warning for each row that's truncated.
SELECT CAST('abc' AS VARCHAR(1)) FROM t;
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- COL1: a
-- COL1: a
-- COL1: a
