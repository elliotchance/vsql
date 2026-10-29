/* setup */
CREATE TABLE t1 (x FLOAT);

INSERT INTO t1 (x) VALUES (?);
-- error 42P02: parameter does not exist: ?1

/* params 2 */
INSERT INTO t1 (x) VALUES (?);
SELECT * FROM t1;
-- sql: INSERT INTO t1 (x) VALUES (2.0e0)
-- msg: INSERT 1
-- X: 2e0

/* types */
/* params 2 */
VALUES ?;
-- sql: VALUES 2.0e0
-- COL1: 2e0 (DOUBLE PRECISION)

/* params 'hello' */
INSERT INTO t1 (x) VALUES (?);
-- sql: INSERT INTO t1 (x) VALUES ('hello')
-- error 42846: cannot coerce CHARACTER(5) to DOUBLE PRECISION

/* types */
/* params 'hello' */
VALUES ?;
-- sql: VALUES 'hello'
-- COL1: hello (CHARACTER(5))

CREATE TABLE t2 (x VARCHAR(10));
/* params 'hello' */
INSERT INTO t2 (x) VALUES (?);
SELECT * FROM t2;
-- msg: CREATE TABLE 1
-- sql: INSERT INTO t2 (x) VALUES ('hello')
-- msg: INSERT 1
-- X: hello

EXPLAIN UPDATE t1 SET x = ?;
-- EXPLAIN: TABLE ":memory:".PUBLIC.T1 (X DOUBLE PRECISION)

UPDATE t1 SET x = ?;
-- error 42P02: parameter does not exist: ?1

INSERT INTO t1 (x) VALUES (100);
/* params 321 */
UPDATE t1 SET x = ?;
SELECT * FROM t1;
-- msg: INSERT 1
-- sql: UPDATE t1 SET x = 321.0e0
-- msg: UPDATE 1
-- X: 321e0

-- # The WHERE is checked even when there are no rows.
DELETE FROM t1 WHERE x = ?;
-- error 42P02: parameter does not exist: ?1

INSERT INTO t1 (x) VALUES (200);
DELETE FROM t1 WHERE x = ?;
-- msg: INSERT 1
-- error 42P02: parameter does not exist: ?1

INSERT INTO t1 (x) VALUES (100);
/* params 100 */
DELETE FROM t1 WHERE x = ?;
SELECT * FROM t1;
-- msg: INSERT 1
-- sql: DELETE FROM t1 WHERE x = 100.0e0
-- msg: DELETE 1

INSERT INTO t1 (x) VALUES (100);
/* params NULL INT */
UPDATE t1 SET x = ?;
SELECT * FROM t1;
-- msg: INSERT 1
-- sql: UPDATE t1 SET x = CAST(NULL AS INTEGER)
-- msg: UPDATE 1
-- X: NULL

/* types */
/* params NULL INT */
VALUES ?;
-- sql: VALUES CAST(NULL AS INTEGER)
-- COL1: NULL (INTEGER)

CREATE TABLE t2 (x INT NOT NULL);
/* params NULL INT */
UPDATE t2 SET x = ?;
SELECT * FROM t2;
-- msg: CREATE TABLE 1
-- sql: UPDATE t2 SET x = CAST(NULL AS INTEGER)
-- error 23502: violates non-null constraint: column X
