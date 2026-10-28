/* types */
/* params 2 */
VALUES ?;
-- sql: VALUES 2.0e0
-- COL1: 2e0 (DOUBLE PRECISION)

/* params 'a' 'b' */
VALUES ROW(?, ?);
-- sql: VALUES ROW('a', 'b')
-- COL1: a COL2: b

/* params 2 */
VALUES ?, ?;
-- sql: VALUES 2.0e0, ?
-- error 42P02: parameter does not exist: ?2

/* params 'a' */
VALUES ROW('?', ?);
-- sql: VALUES ROW('?', 'a')
-- COL1: ? COL2: a

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

VALUES ?;
-- error 42P02: parameter does not exist: ?1
