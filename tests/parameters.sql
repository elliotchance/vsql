/* setup */
CREATE TABLE t1 (x FLOAT);

INSERT INTO t1 (x) VALUES (:foo);
-- error 42P02: parameter does not exist: foo

/* set foo 2 */
INSERT INTO t1 (x) VALUES (:foo);
SELECT * FROM t1;
-- msg: INSERT 1
-- X: 2

/* set foo 'hello' */
INSERT INTO t1 (x) VALUES (:foo);
-- error 42804: data type mismatch for column X: expected DOUBLE PRECISION but got CHARACTER VARYING

/* set foo 'hello' */
CREATE TABLE t2 (x VARCHAR(10));
INSERT INTO t2 (x) VALUES (:foo);
SELECT * FROM t2;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- X: hello

UPDATE t1 SET x = :foo;
-- error 42P02: parameter does not exist: foo

/* set foo 321 */
INSERT INTO t1 (x) VALUES (100);
UPDATE t1 SET x = :foo;
SELECT * FROM t1;
-- msg: INSERT 1
-- msg: UPDATE 1
-- X: 321

DELETE FROM t1 WHERE x = :foo;
-- msg: DELETE 0

INSERT INTO t1 (x) VALUES (200);
DELETE FROM t1 WHERE x = :foo;
-- msg: INSERT 1
-- error 42P02: parameter does not exist: foo

/* set foo 100 */
INSERT INTO t1 (x) VALUES (100);
DELETE FROM t1 WHERE x = :foo;
SELECT * FROM t1;
-- msg: INSERT 1
-- msg: DELETE 1
