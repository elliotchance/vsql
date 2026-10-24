/* setup */
CREATE TABLE t1 (x INT, y VARCHAR(10));
CREATE TABLE t2 (x INT, y VARCHAR(10) NOT NULL);

INSERT INTO t1 (x, y) VALUES (1, DEFAULT);
SELECT * FROM t1;
-- msg: INSERT 1
-- X: 1 Y: NULL

INSERT INTO t1 (x) VALUES (DEFAULT);
SELECT * FROM t1;
-- msg: INSERT 1
-- X: NULL Y: NULL

INSERT INTO t1 (x) VALUES DEFAULT;
SELECT * FROM t1;
-- msg: INSERT 1
-- X: NULL Y: NULL

INSERT INTO t1 (x, y) VALUES (DEFAULT, DEFAULT), (2, 'foo'), (DEFAULT, 'bar');
SELECT * FROM t1;
-- msg: INSERT 3
-- X: NULL Y: NULL
-- X: 2 Y: foo
-- X: NULL Y: bar

INSERT INTO t2 (x, y) VALUES (1, DEFAULT);
-- error 23502: violates non-null constraint: column Y

INSERT INTO t2 (x, y) VALUES (1, 'foo'), (2, DEFAULT);
SELECT * FROM t2;
-- error 23502: violates non-null constraint: column Y

INSERT INTO t1 (x, y) VALUES (1, 'foo'), (2, 'bar');
UPDATE t1 SET y = DEFAULT WHERE x = 1;
SELECT * FROM t1;
-- msg: INSERT 2
-- msg: UPDATE 1
-- X: 1 Y: NULL
-- X: 2 Y: bar

INSERT INTO t1 (x, y) VALUES (1, 'foo');
UPDATE t1 SET x = DEFAULT, y = DEFAULT;
SELECT * FROM t1;
-- msg: INSERT 1
-- msg: UPDATE 1
-- X: NULL Y: NULL

INSERT INTO t2 (x, y) VALUES (1, 'foo');
UPDATE t2 SET y = DEFAULT;
-- msg: INSERT 1
-- error 23502: violates non-null constraint: column Y

UPDATE t2 SET y = DEFAULT;
-- error 23502: violates non-null constraint: column Y

UPDATE t1 SET x = DEFAULT;
-- warning 02000: no data
-- msg: UPDATE 0

INSERT INTO t1 (x) VALUES (DEFAULT + 1);
-- error 42601: syntax error: unexpected "+", expecting ","

UPDATE t1 SET x = DEFAULT + 1;
-- error 42601: syntax error: unexpected "+"

SELECT DEFAULT FROM t1;
-- error 42601: syntax error: unexpected DEFAULT

SELECT * FROM t1 WHERE x = DEFAULT;
-- error 42601: syntax error: unexpected DEFAULT

VALUES (DEFAULT);
-- error 42601: syntax error: unexpected ")", expecting ","

VALUES CAST(DEFAULT AS INT);
-- error 42601: syntax error: unexpected DEFAULT
