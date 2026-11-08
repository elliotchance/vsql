/* setup */
CREATE TABLE t1 (x INT);
INSERT INTO t1 (x) VALUES (1);
INSERT INTO t1 (x) VALUES (2);
INSERT INTO t1 (x) VALUES (3);

-- # A negative OFFSET is an exception (General Rules, 6.b), and so is a FETCH
-- # FIRST count less than 1, including 0 (General Rules, 7.c).
SELECT * FROM t1 OFFSET -1 ROWS;
-- error 2201X: invalid row count in result offset clause

SELECT * FROM t1 FETCH FIRST -1 ROWS ONLY;
-- error 2201W: invalid row count in fetch first clause

SELECT * FROM t1 FETCH FIRST 0 ROWS ONLY;
-- error 2201W: invalid row count in fetch first clause

-- # A row count must be an exact numeric with scale 0, so a decimal, a string
-- # or a float is a syntax error, even when its value is whole (Syntax Rules,
-- # 29 and 30).
SELECT * FROM t1 OFFSET 1.5 ROWS;
-- error 42601: syntax error: OFFSET row count must be an exact numeric with scale 0, got NUMERIC(2, 1)

SELECT * FROM t1 OFFSET 'a' ROWS;
-- error 42601: syntax error: OFFSET row count must be an exact numeric with scale 0, got CHARACTER(1)

SELECT * FROM t1 FETCH FIRST 1.5 ROWS ONLY;
-- error 42601: syntax error: FETCH FIRST row count must be an exact numeric with scale 0, got NUMERIC(2, 1)

SELECT * FROM t1 FETCH FIRST 1e0 ROWS ONLY;
-- error 42601: syntax error: FETCH FIRST row count must be an exact numeric with scale 0, got DOUBLE PRECISION

-- # The largest BIGINT is a valid count, even though it's more rows than there
-- # are.
SELECT * FROM t1 OFFSET 1 ROW FETCH FIRST 9223372036854775807 ROWS ONLY;
-- X: 2
-- X: 3

-- # The same checks apply to VALUES and to a query in a subquery.
VALUES 1, 2, 3 OFFSET -1 ROWS;
-- error 2201X: invalid row count in result offset clause

SELECT * FROM (SELECT * FROM t1 FETCH FIRST 0 ROWS ONLY) AS s;
-- error 2201W: invalid row count in fetch first clause

VALUES 1, 2, 3 FETCH FIRST 0 ROWS ONLY;
-- error 2201W: invalid row count in fetch first clause
