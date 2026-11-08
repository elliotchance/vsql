/* setup */
CREATE TABLE t1 (x INT);
INSERT INTO t1 (x) VALUES (1);
INSERT INTO t1 (x) VALUES (2);
INSERT INTO t1 (x) VALUES (3);

SELECT * FROM t1 OFFSET -1 ROWS;
-- error 2201X: invalid row count in result offset clause

SELECT * FROM t1 FETCH FIRST -1 ROWS ONLY;
-- error 2201W: invalid row count in fetch first clause

SELECT * FROM t1 FETCH FIRST 0 ROWS ONLY;
-- error 2201W: invalid row count in fetch first clause

SELECT * FROM t1 OFFSET 1.5 ROWS;
-- error 42601: syntax error: OFFSET row count must be an exact numeric with scale 0, got NUMERIC(2, 1)

SELECT * FROM t1 OFFSET 'a' ROWS;
-- error 42601: syntax error: OFFSET row count must be an exact numeric with scale 0, got CHARACTER(1)

SELECT * FROM t1 FETCH FIRST 1.5 ROWS ONLY;
-- error 42601: syntax error: FETCH FIRST row count must be an exact numeric with scale 0, got NUMERIC(2, 1)

SELECT * FROM t1 FETCH FIRST 1e0 ROWS ONLY;
-- error 42601: syntax error: FETCH FIRST row count must be an exact numeric with scale 0, got DOUBLE PRECISION

SELECT * FROM t1 OFFSET 1 ROW FETCH FIRST 9223372036854775807 ROWS ONLY;
-- X: 2
-- X: 3

VALUES 1, 2, 3 OFFSET -1 ROWS;
-- error 2201X: invalid row count in result offset clause

SELECT * FROM (SELECT * FROM t1 FETCH FIRST 0 ROWS ONLY) AS s;
-- error 2201W: invalid row count in fetch first clause

VALUES 1, 2, 3 FETCH FIRST 0 ROWS ONLY;
-- error 2201W: invalid row count in fetch first clause
