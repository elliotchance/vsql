/* set ?1 2 */
/* types */
VALUES ?;
-- COL1: 2e0 (DOUBLE PRECISION)

/* set ?1 'a' */
/* set ?2 'b' */
VALUES ROW(?, ?);
-- COL1: a COL2: b

/* set ?1 2 */
VALUES ?, ?;
-- error 42P02: parameter does not exist: ?2

/* set ?1 'a' */
VALUES ROW('?', ?);
-- COL1: ? COL2: a

/* setup */
CREATE TABLE t1 (x FLOAT, y VARCHAR(10));

/* set ?1 1.5 */
/* set ?2 'hi' */
INSERT INTO t1 (x, y) VALUES (?, ?);
SELECT * FROM t1;
-- msg: INSERT 1
-- X: 1.5e0 Y: hi

/* set ?1 'hi' */
SELECT * FROM t1 WHERE y = ?;
-- 

-- # Each statement numbers its own parameters, so the "?" in the UPDATE is
-- # "?1".
/* set ?1 3 */
/* set ?2 'a' */
INSERT INTO t1 (x, y) VALUES (?, ?);
UPDATE t1 SET x = x + ?;
SELECT * FROM t1;
-- msg: INSERT 1
-- msg: UPDATE 1
-- X: 6e0 Y: a

VALUES ?;
-- error 42P02: parameter does not exist: ?1
