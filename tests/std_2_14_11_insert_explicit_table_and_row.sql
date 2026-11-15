/* setup */
CREATE TABLE t (x INT, y VARCHAR(10) DEFAULT 'def');
CREATE TABLE s (x INT, y VARCHAR(10));
INSERT INTO s (x, y) VALUES (1, 'a'), (2, 'b');

-- # The source of an INSERT can be an <explicit table>, on its own or as part
-- # of a larger query.
INSERT INTO t TABLE s;
SELECT * FROM t;
-- msg: INSERT 2
-- X: 1 Y: a
-- X: 2 Y: b

INSERT INTO t (x, y) TABLE s UNION ALL TABLE s;
SELECT COUNT(*) FROM t;
-- msg: INSERT 4
-- COL1: 4

INSERT INTO t (x, y) TABLE s UNION ALL SELECT 3, 'c' FROM s ORDER BY x FETCH FIRST 3 ROWS ONLY;
SELECT * FROM t;
-- msg: INSERT 3
-- X: 1 Y: a
-- X: 2 Y: b
-- X: 3 Y: c

INSERT INTO t TABLE t;
SELECT COUNT(*) FROM t;
-- warning 02000: no data
-- msg: INSERT 0
-- COL1: 0

INSERT INTO t TABLE nope;
-- error 42P01: no such table: ":memory:".PUBLIC.NOPE

/* flags */
INSERT INTO t TABLE s;
-- flags: F661
-- msg: INSERT 2

/* flags */
INSERT INTO t TABLE t;
-- flags: F661, F781
-- warning 02000: no data
-- msg: INSERT 0

-- # Each row of a VALUES can start with ROW, and can then have NULL and DEFAULT
-- # like a row in parentheses.
INSERT INTO t VALUES ROW(1, 'a');
INSERT INTO t VALUES ROW(2, DEFAULT), ROW(3, NULL), (4, 'd');
INSERT INTO t (x) VALUES ROW(5);
SELECT * FROM t;
-- msg: INSERT 1
-- msg: INSERT 3
-- msg: INSERT 1
-- X: 1 Y: a
-- X: 2 Y: def
-- X: 3 Y: NULL
-- X: 4 Y: d
-- X: 5 Y: def

INSERT INTO t VALUES ROW(1, 'a') UNION ALL VALUES ROW(2, 'b');
SELECT * FROM t;
-- msg: INSERT 2
-- X: 1 Y: a
-- X: 2 Y: b

INSERT INTO t VALUES ROW(1);
-- error 42601: syntax error: INSERT has less values than columns

/* flags */
INSERT INTO t VALUES ROW(1, 'a');
-- flags: T051
-- msg: INSERT 1

/* flags */
INSERT INTO t VALUES ROW(1, 'a'), ROW(2, DEFAULT);
-- flags: F641, T051
-- msg: INSERT 2

-- # In a query, a row after ROW still can't have NULL or DEFAULT.
VALUES ROW(1, NULL);
-- error 42601: syntax error: unexpected NULL

VALUES ROW(DEFAULT, 1);
-- error 42601: syntax error: unexpected DEFAULT

VALUES ROW(1, 2), ROW(3, 4);
-- COL1: 1 COL2: 2
-- COL1: 3 COL2: 4
