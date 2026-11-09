-- # NOW() is a vsql extension (V402-01) that's the same as CURRENT_TIMESTAMP.

/* setup */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);

-- # NOW() is replaced by CURRENT_TIMESTAMP, so it has the same type and value:
-- # the statement's timestamp (6.36, General Rules, 1 and 2).
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

-- # It's allowed in a DEFAULT, where only a datetime value function is.
/* extensions V402-01 */
CREATE TABLE d (x INT, c TIMESTAMP(6) WITH TIME ZONE DEFAULT NOW());
INSERT INTO d (x) VALUES (1);
SELECT x, c IS NOT NULL AS has FROM d;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- X: 1 HAS: TRUE

-- # It has the same rules as CURRENT_TIMESTAMP in a CHECK, where a < NOW() is
-- # retrospectively deterministic (6.39, Syntax Rules, 5.c.ii).
/* extensions V402-01 */
CREATE TABLE c (a TIMESTAMP(6) WITH TIME ZONE, CHECK (a < NOW()));
-- msg: CREATE TABLE 1

-- # NOW isn't reserved.
CREATE TABLE now (now INT);
INSERT INTO now (now) VALUES (1);
SELECT now FROM now;
SELECT now.now AS now FROM now AS now;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- NOW: 1
-- NOW: 1

-- # It doesn't take arguments, and only the unquoted, unqualified NOW() is
-- # CURRENT_TIMESTAMP. "NOW"() is looked up as a function that doesn't
-- # exist, and PUBLIC.NOW() isn't valid syntax.
SELECT NOW(1) FROM t;
-- error 42883: function does not exist: NOW(SMALLINT)

SELECT "NOW"() FROM t;
-- error 42883: function does not exist: NOW()

SELECT PUBLIC.NOW() FROM t;
-- error 42601: syntax error: unexpected "(" at line 1, column 18 near "PUBLIC.NOW()"

-- # The flagger: what CURRENT_TIMESTAMP needs, and which alias was used.
/* flags */
/* extensions V402-01 */
SELECT NOW() = CURRENT_TIMESTAMP AS same FROM t;
-- flags: F411, T031, V402-01
-- SAME: TRUE
