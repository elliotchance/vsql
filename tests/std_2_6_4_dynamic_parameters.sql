-- # A number is bound as a DOUBLE PRECISION (see the "params" directive in
-- # docs/testing.rst), and cast to the type of the dynamic parameter (see
-- # std_2_20_7_dynamic_parameter_types.sql).
/* types */
/* params 2 */
VALUES CAST(? AS DOUBLE PRECISION);
-- sql: VALUES CAST(2.0e0 AS DOUBLE PRECISION)
-- COL1: 2e0 (DOUBLE PRECISION)

-- # Each ? takes the next value, so a second ? with only one value doesn't
-- # exist.
/* params 'a' 'b' */
VALUES ROW(CAST(? AS VARCHAR(1)), CAST(? AS VARCHAR(1)));
-- sql: VALUES ROW(CAST('a' AS VARCHAR(1)), CAST('b' AS VARCHAR(1)))
-- COL1: a COL2: b

/* params 2 */
VALUES CAST(? AS INT), CAST(? AS INT);
-- sql: VALUES CAST(2.0e0 AS INT), CAST(? AS INT)
-- error 42P02: parameter does not exist: ?2

-- # A ? in a character string literal isn't a parameter, so the type of the
-- # ? can't be determined from the other row.
/* params 'a' */
VALUES ROW('?', ?);
-- sql: VALUES ROW('?', 'a')
-- error 42601: syntax error: the data type of ?1 cannot be determined

/* params 'a' */
VALUES '?', ?;
-- sql: VALUES '?', 'a'
-- COL1: ?
-- COL1: a

-- # A parameter can be inserted into a column, and compared in a WHERE.
/* setup */
CREATE TABLE t1 (x FLOAT, y VARCHAR(10));

/* params 1.5 'hi' */
INSERT INTO t1 (x, y) VALUES (?, ?);
SELECT * FROM t1;
-- sql: INSERT INTO t1 (x, y) VALUES (1.5e0, 'hi')
-- msg: INSERT 1
-- X: 1.5e0 Y: hi

/* params 'hi' */
SELECT * FROM t1 WHERE y = ?;
-- sql: SELECT * FROM t1 WHERE y = 'hi'

-- # Each statement numbers its own parameters, so the "?" in the UPDATE is
-- # "?1".
/* params 3 'a' */
INSERT INTO t1 (x, y) VALUES (?, ?);
/* params 3 */
UPDATE t1 SET x = x + ?;
SELECT * FROM t1;
-- sql: INSERT INTO t1 (x, y) VALUES (3.0e0, 'a')
-- msg: INSERT 1
-- sql: UPDATE t1 SET x = x + 3.0e0
-- msg: UPDATE 1
-- X: 6e0 Y: a

-- # A ? without a value is an error.
VALUES CAST(? AS INT);
-- error 42P02: parameter does not exist: ?1
