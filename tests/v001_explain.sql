-- # EXPLAIN (V001-01) returns the plan of a query, one line per row, without
-- # running it. TABLE reads every row of the table and EXPR is the columns that
-- # are returned. Like any keyword, EXPLAIN can be in lower case.
/* extensions V001-01 */
CREATE TABLE t1 (x INT);
EXPLAIN SELECT * FROM t1;
-- msg: CREATE TABLE 1
-- EXPLAIN: TABLE ":memory:".PUBLIC.T1 (X INTEGER)
-- EXPLAIN: EXPR (":memory:".PUBLIC.T1.X INTEGER)

/* extensions V001-01 */
CREATE TABLE t1 (x INT);
explain SELECT * FROM t1;
-- msg: CREATE TABLE 1
-- EXPLAIN: TABLE ":memory:".PUBLIC.T1 (X INTEGER)
-- EXPLAIN: EXPR (":memory:".PUBLIC.T1.X INTEGER)

-- # Each clause is a line of the plan, after the rows are read. ROW and ROWS
-- # mean the same, so the plan always says ROWS.
/* extensions V001-01 */
CREATE TABLE t1 (x INT);
EXPLAIN SELECT * FROM t1 WHERE x > 100;
-- msg: CREATE TABLE 1
-- EXPLAIN: TABLE ":memory:".PUBLIC.T1 (X INTEGER)
-- EXPLAIN: WHERE X > 100
-- EXPLAIN: EXPR (":memory:".PUBLIC.T1.X INTEGER)

/* extensions V001-01 */
CREATE TABLE t1 (x INT);
EXPLAIN SELECT * FROM t1 OFFSET 5 ROW;
-- msg: CREATE TABLE 1
-- EXPLAIN: TABLE ":memory:".PUBLIC.T1 (X INTEGER)
-- EXPLAIN: OFFSET 5 ROWS
-- EXPLAIN: EXPR (":memory:".PUBLIC.T1.X INTEGER)

/* extensions V001-01 */
CREATE TABLE t1 (x INT);
EXPLAIN SELECT * FROM t1 FETCH FIRST 2 ROW ONLY;
-- msg: CREATE TABLE 1
-- EXPLAIN: TABLE ":memory:".PUBLIC.T1 (X INTEGER)
-- EXPLAIN: FETCH FIRST 2 ROWS ONLY
-- EXPLAIN: EXPR (":memory:".PUBLIC.T1.X INTEGER)

/* extensions V001-01 */
CREATE TABLE t1 (x INT);
EXPLAIN SELECT * FROM t1 OFFSET 3 ROWS FETCH FIRST 2 ROWS ONLY;
-- msg: CREATE TABLE 1
-- EXPLAIN: TABLE ":memory:".PUBLIC.T1 (X INTEGER)
-- EXPLAIN: OFFSET 3 ROWS FETCH FIRST 2 ROWS ONLY
-- EXPLAIN: EXPR (":memory:".PUBLIC.T1.X INTEGER)

/* extensions V001-01 */
CREATE TABLE t1 (x INT);
EXPLAIN SELECT * FROM t1
WHERE x >= 123 AND x <= 456
OFFSET 3 ROWS FETCH FIRST 2 ROWS ONLY;
-- msg: CREATE TABLE 1
-- EXPLAIN: TABLE ":memory:".PUBLIC.T1 (X INTEGER)
-- EXPLAIN: WHERE X >= 123 AND X <= 456
-- EXPLAIN: OFFSET 3 ROWS FETCH FIRST 2 ROWS ONLY
-- EXPLAIN: EXPR (":memory:".PUBLIC.T1.X INTEGER)

-- # A dynamic parameter is shown with its value in place. A number in params
-- # is a DOUBLE PRECISION, so 2 is 2e0.
/* extensions V001-01 */
CREATE TABLE t1 (x INT);
/* params 2 */
EXPLAIN SELECT * FROM t1 WHERE x = ?;
-- msg: CREATE TABLE 1
-- sql: EXPLAIN SELECT * FROM t1 WHERE x = 2.0e0
-- EXPLAIN: TABLE ":memory:".PUBLIC.T1 (X INTEGER)
-- EXPLAIN: WHERE X = 2e0
-- EXPLAIN: EXPR (":memory:".PUBLIC.T1.X INTEGER)

-- # Only a query, DELETE or UPDATE can be explained. Any other statement is a
-- # syntax error.
EXPLAIN CREATE TABLE t1 (x INT);
-- error 42601: syntax error: Cannot EXPLAIN CREATE TABLE

EXPLAIN DROP TABLE t1 RESTRICT;
-- error 42601: syntax error: Cannot EXPLAIN DROP TABLE

EXPLAIN INSERT INTO t1 (x) VALUES (0);
-- error 42601: syntax error: Cannot EXPLAIN INSERT

-- # EXPLAIN DELETE (V001-02) and EXPLAIN UPDATE (V001-03) show how the rows
-- # are found. There's no EXPR because they don't return any columns.
/* extensions V001-02 */
CREATE TABLE t1 (x INT);
EXPLAIN DELETE FROM t1;
-- msg: CREATE TABLE 1
-- EXPLAIN: TABLE ":memory:".PUBLIC.T1 (X INTEGER)

/* extensions V001-02 */
CREATE TABLE t1 (x INT);
EXPLAIN DELETE FROM t1 WHERE x = 35;
-- msg: CREATE TABLE 1
-- EXPLAIN: TABLE ":memory:".PUBLIC.T1 (X INTEGER)
-- EXPLAIN: WHERE X = 35

/* extensions V001-03 */
CREATE TABLE t1 (x INT);
EXPLAIN UPDATE t1 SET x = 1;
-- msg: CREATE TABLE 1
-- EXPLAIN: TABLE ":memory:".PUBLIC.T1 (X INTEGER)

/* extensions V001-03 */
CREATE TABLE t1 (x INT);
EXPLAIN UPDATE t1 SET x = 1 WHERE x = 35;
-- msg: CREATE TABLE 1
-- EXPLAIN: TABLE ":memory:".PUBLIC.T1 (X INTEGER)
-- EXPLAIN: WHERE X = 35

-- # A column of the PRIMARY KEY is NOT NULL (11.7, Syntax Rules, 7). A WHERE
-- # that compares the key with = only reads that range of the key, and is still
-- # applied to each row. A WHERE on another column has to read every row.
/* extensions V001-01 */
CREATE TABLE t1 (x INT, PRIMARY KEY(x));
EXPLAIN SELECT * FROM t1;
-- msg: CREATE TABLE 1
-- EXPLAIN: TABLE ":memory:".PUBLIC.T1 (X INTEGER NOT NULL)
-- EXPLAIN: EXPR (":memory:".PUBLIC.T1.X INTEGER NOT NULL)

/* extensions V001-01 */
CREATE TABLE t1 (x INT, PRIMARY KEY(x));
EXPLAIN SELECT * FROM t1 WHERE x = 10;
-- msg: CREATE TABLE 1
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.T1 (X INTEGER NOT NULL) RANGE X = 10
-- EXPLAIN: EXPR (":memory:".PUBLIC.T1.X INTEGER NOT NULL)

/* extensions V001-01 */
CREATE TABLE t1 (x INT, b INT, PRIMARY KEY(x));
EXPLAIN SELECT * FROM t1 WHERE b = 10;
-- msg: CREATE TABLE 1
-- EXPLAIN: TABLE ":memory:".PUBLIC.T1 (X INTEGER NOT NULL, B INTEGER)
-- EXPLAIN: WHERE B = 10
-- EXPLAIN: EXPR (":memory:".PUBLIC.T1.X INTEGER NOT NULL, ":memory:".PUBLIC.T1.B INTEGER)

/* extensions V001-01 */
CREATE TABLE t1 (x INT, b INT, PRIMARY KEY(x));
EXPLAIN SELECT * FROM t1 WHERE x = 10 AND b = 20;
-- msg: CREATE TABLE 1
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.T1 (X INTEGER NOT NULL, B INTEGER) RANGE X = 10
-- EXPLAIN: WHERE B = 20
-- EXPLAIN: EXPR (":memory:".PUBLIC.T1.X INTEGER NOT NULL, ":memory:".PUBLIC.T1.B INTEGER)

-- # Transaction statements can't be explained either.
EXPLAIN START TRANSACTION;
-- error 42601: syntax error: Cannot EXPLAIN START TRANSACTION

EXPLAIN COMMIT;
-- error 42601: syntax error: Cannot EXPLAIN COMMIT

EXPLAIN ROLLBACK;
-- error 42601: syntax error: Cannot EXPLAIN ROLLBACK

-- # Expressions are shown as SQL, and VALUES shows the type of each column.
/* extensions V001-01 */
CREATE TABLE t1 (x INT);
EXPLAIN SELECT * FROM t1 WHERE x = 1 OR x = 2;
-- msg: CREATE TABLE 1
-- EXPLAIN: TABLE ":memory:".PUBLIC.T1 (X INTEGER)
-- EXPLAIN: WHERE X = 1 OR X = 2
-- EXPLAIN: EXPR (":memory:".PUBLIC.T1.X INTEGER)

/* extensions V001-01 */
EXPLAIN VALUES TRUE AND FALSE OR TRUE;
-- EXPLAIN: VALUES (COL1 BOOLEAN) = ROW(TRUE AND FALSE OR TRUE)

/* extensions V001-01 */
EXPLAIN VALUES (1 + 2) * 3;
-- EXPLAIN: VALUES (COL1 SMALLINT) = ROW((1 + 2) * 3)

/* extensions V001-01 */
EXPLAIN VALUES -CAST(1 AS INT);
-- EXPLAIN: VALUES (COL1 INTEGER) = ROW(-CAST(1 AS INTEGER))

/* extensions V001-01 */
EXPLAIN VALUES 'a' || 'b';
-- EXPLAIN: VALUES (COL1 CHARACTER(2)) = ROW('a' || 'b')

/* extensions V001-01 */
EXPLAIN VALUES ROW(TRUE IS TRUE, TRUE IS NOT FALSE, NOT TRUE IS UNKNOWN);
-- EXPLAIN: VALUES (COL1 BOOLEAN, COL2 BOOLEAN, COL3 BOOLEAN) = ROW(TRUE IS TRUE, TRUE IS NOT FALSE, NOT TRUE IS UNKNOWN)

/* extensions V001-01 */
EXPLAIN VALUES ROW(1 IS NULL, 1 IS NOT NULL);
-- EXPLAIN: VALUES (COL1 BOOLEAN, COL2 BOOLEAN) = ROW(1 IS NULL, 1 IS NOT NULL)

/* extensions V001-01 */
EXPLAIN VALUES ROW('a' LIKE 'b', 'a' NOT LIKE 'b');
-- EXPLAIN: VALUES (COL1 BOOLEAN, COL2 BOOLEAN) = ROW('a' LIKE 'b', 'a' NOT LIKE 'b')

/* extensions V001-01 */
EXPLAIN VALUES ROW('a' SIMILAR TO 'b', 'a' NOT SIMILAR TO 'b');
-- EXPLAIN: VALUES (COL1 BOOLEAN, COL2 BOOLEAN) = ROW('a' SIMILAR TO 'b', 'a' NOT SIMILAR TO 'b')

/* extensions V001-01 */
EXPLAIN VALUES CAST(NULL AS INT);
-- EXPLAIN: VALUES (COL1 INTEGER) = ROW(CAST(NULL AS INTEGER))

-- # A string parameter is shown as a literal, which decides the type.
/* params 'abc' */
/* extensions V001-01 */
EXPLAIN VALUES ?;
-- sql: EXPLAIN VALUES 'abc'
-- EXPLAIN: VALUES (COL1 CHARACTER(3)) = ROW('abc')

-- # A derived table is planned first, under its name, and is then read like a
-- # table.
/* extensions V001-01 */
EXPLAIN SELECT * FROM (VALUES 1, 2) AS t (x);
-- EXPLAIN: T:
-- EXPLAIN:   VALUES (X SMALLINT) = ROW(1), ROW(2)
-- EXPLAIN: TABLE T (X SMALLINT)
-- EXPLAIN: EXPR (T.X SMALLINT)
