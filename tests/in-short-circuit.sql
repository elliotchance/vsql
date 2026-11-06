/* setup */
CREATE TABLE t (x INT, d DATE);
CREATE TABLE t0 (x INT);
INSERT INTO t (x, d) VALUES (1, DATE '2020-01-01'), (2, DATE '2020-01-02'), (NULL, NULL);

-- # Comparability is checked from the declared types, so it doesn't depend on
-- # the order of the list, the values or whether there are any rows.
VALUES 1 IN (1, 'a');
-- error 42883: cannot compare SMALLINT and CHARACTER(1)

VALUES 1 IN ('a', 1);
-- error 42883: cannot compare SMALLINT and CHARACTER(1)

SELECT * FROM t0 WHERE x IN (1, 'a');
-- error 42883: cannot compare INTEGER and CHARACTER(1)

SELECT * FROM t0 WHERE x NOT IN (1, 'a');
-- error 42883: cannot compare INTEGER and CHARACTER(1)

SELECT * FROM t0 WHERE x = 'a';
-- error 42883: cannot compare INTEGER and CHARACTER(1)

VALUES CAST(NULL AS INTEGER) = 'a';
-- error 42883: cannot compare INTEGER and CHARACTER(1)

SELECT * FROM t WHERE d IN (TIME '10:00:00');
-- error 42883: cannot compare DATE and TIME(0) WITHOUT TIME ZONE

SELECT * FROM t WHERE d IN (TIMESTAMP '2020-01-01 00:00:00');
-- error 42883: cannot compare DATE and TIMESTAMP(0) WITHOUT TIME ZONE

SELECT * FROM t0 WHERE x IN (SELECT d FROM t);
-- error 42883: cannot compare INTEGER and DATE

SELECT * FROM t0 WHERE x = ANY (SELECT d FROM t);
-- error 42883: cannot compare INTEGER and DATE

-- # It stops at the first value that's equal, so the rest of the list isn't
-- # evaluated.
VALUES 1 IN (1, 1 / 0);
-- COL1: TRUE

VALUES 1 NOT IN (1, 1 / 0);
-- COL1: FALSE

VALUES 2 IN (1, 1 / 0);
-- error 22012: division by zero

SELECT x, x IN (1, 2 / (x - 1)) FROM t;
-- X: 1 COL2: TRUE
-- X: 2 COL2: TRUE
-- X: NULL COL2: UNKNOWN

-- # A null value doesn't decide the result.
VALUES 1 IN (CAST(NULL AS INTEGER), 1);
-- COL1: TRUE

VALUES 2 IN (CAST(NULL AS INTEGER), 1);
-- COL1: UNKNOWN

VALUES 2 NOT IN (1, CAST(NULL AS INTEGER));
-- COL1: UNKNOWN

VALUES 2 NOT IN (1, 3);
-- COL1: TRUE

SELECT x FROM t WHERE x IN (2, 1.0, 3e0);
-- X: 1
-- X: 2

SELECT d FROM t WHERE d IN (DATE '2020-01-02', DATE '2020-01-05');
-- D: 2020-01-02

VALUES ROW(2 = ANY (VALUES 1, 2, 3), 2 = ALL (VALUES 2, 3, 2), 2 = ANY (VALUES 1, CAST(NULL AS INTEGER)));
-- COL1: TRUE COL2: FALSE COL3: UNKNOWN
