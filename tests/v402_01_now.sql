-- # NOW() is a vsql extension (V402-01), a function that reads the wall clock
-- # each time it's called. These tests run with a clock that doesn't move, so
-- # it's the same as CURRENT_TIMESTAMP here (test_now_reads_the_clock in
-- # vsql/sql_test.v checks that it moves).

/* setup */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);

-- # It has the type of CURRENT_TIMESTAMP, and with the clock fixed, the same
-- # value, in any case and spacing.
/* extensions V402-01 */
SELECT NOW() = CURRENT_TIMESTAMP AS same FROM t;
-- SAME: TRUE

/* extensions V402-01 */
select now ( ) = current_timestamp as same from t;
-- SAME: TRUE

/* extensions V402-01 */
SELECT CAST(NOW() AS TIMESTAMP(6) WITH TIME ZONE) = CURRENT_TIMESTAMP(6) AS same FROM t;
-- SAME: TRUE

/* extensions V402-01 */
SELECT x FROM t WHERE NOW() > TIMESTAMP '2000-01-01 00:00:00+00:00';
-- X: 1

/* extensions V001-01 V402-01 */
EXPLAIN SELECT NOW() FROM t;
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (X INTEGER)
-- EXPLAIN: EXPR (COL1 TIMESTAMP(6) WITH TIME ZONE)

-- # It's a function, not a datetime value function, so it can't be a DEFAULT.
CREATE TABLE d (x INT, c TIMESTAMP(6) WITH TIME ZONE DEFAULT NOW());
-- error 42601: syntax error: unexpected identifier at line 1, column 62 near "TIME ZONE DEFAULT NOW("

-- # It reads the clock each time, so it's NOT DETERMINISTIC and can't be in a
-- # CHECK.
/* extensions V402-01 */
CREATE TABLE c (a TIMESTAMP(6) WITH TIME ZONE, CHECK (a < NOW()));
-- error 42601: syntax error: non-deterministic function NOW cannot be used in a CHECK constraint

-- # NOW isn't reserved.
CREATE TABLE now (now INT);
INSERT INTO now (now) VALUES (1);
SELECT now FROM now;
SELECT now.now AS now FROM now AS now;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- NOW: 1
-- NOW: 1

-- # It doesn't take arguments, and like any function, its name can be quoted.
/* extensions V402-01 */
SELECT NOW(1) FROM t;
-- error 42883: function does not exist: NOW(SMALLINT)

/* extensions V402-01 */
SELECT "NOW"() = CURRENT_TIMESTAMP AS same FROM t;
-- SAME: TRUE

SELECT PUBLIC.NOW() FROM t;
-- error 42601: syntax error: unexpected "(" at line 1, column 18 near "PUBLIC.NOW()"

-- # The flagger: what CURRENT_TIMESTAMP needs, and which alias was used.
/* flags */
/* extensions V402-01 */
SELECT NOW() = CURRENT_TIMESTAMP AS same FROM t;
-- flags: F411, T031, V402-01
-- SAME: TRUE
