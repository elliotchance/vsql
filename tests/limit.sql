-- # LIMIT is a vsql extension (V203-01) that's the same as FETCH FIRST.

/* setup */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
INSERT INTO t (x) VALUES (2);
INSERT INTO t (x) VALUES (3);
INSERT INTO t (x) VALUES (4);

/* extensions V203-01 */
SELECT * FROM t LIMIT 2;
-- X: 1
-- X: 2

/* extensions V203-01 */
select * from t limit 2;
-- X: 1
-- X: 2

/* extensions V203-01 */
SELECT * FROM t LIMIT /* comment */ 1;
-- X: 1

/* extensions V203-01 V203-02 */
SELECT * FROM t LIMIT 2 OFFSET 1;
-- X: 2
-- X: 3

/* extensions V203-01 */
SELECT * FROM t LIMIT 2 OFFSET 1 ROW;
-- X: 2
-- X: 3

/* extensions V203-01 */
SELECT * FROM t LIMIT 2 OFFSET 1 ROWS;
-- X: 2
-- X: 3

/* extensions V203-01 V203-02 */
SELECT * FROM t OFFSET 1 LIMIT 2;
-- X: 2
-- X: 3

/* extensions V203-01 */
SELECT * FROM t OFFSET 1 ROWS LIMIT 2;
-- X: 2
-- X: 3

-- # OFFSET without ROW or ROWS (V203-02), which doesn't need a LIMIT.
/* extensions V203-02 */
SELECT * FROM t OFFSET 1;
-- X: 2
-- X: 3
-- X: 4

/* extensions V203-02 */
SELECT * FROM t ORDER BY x DESC OFFSET 1;
-- X: 3
-- X: 2
-- X: 1

/* extensions V203-02 */
SELECT * FROM t OFFSET 1 FETCH FIRST 1 ROW ONLY;
-- X: 2

/* extensions V203-02 */
SELECT * FROM t ORDER BY x DESC OFFSET 1 FETCH FIRST 1 ROW ONLY;
-- X: 3

/* extensions V203-02 */
SELECT * FROM t OFFSET 10;

/* extensions V203-02 */
SELECT * FROM t OFFSET -1;
-- error 2201X: invalid row count in result offset clause

/* extensions V203-02 */
SELECT * FROM t OFFSET 1.5;
-- error 42601: syntax error: OFFSET row count must be an exact numeric with scale 0, got NUMERIC(2, 1)

-- # LIMIT offset, count (V203-03), the offset is first.
/* extensions V203-03 */
SELECT * FROM t LIMIT 1, 2;
-- X: 2
-- X: 3

/* extensions V203-03 */
select * from t limit 1, 2;
-- X: 2
-- X: 3

/* extensions V203-03 */
SELECT * FROM t ORDER BY x DESC LIMIT 1, 2;
-- X: 3
-- X: 2

/* extensions V203-03 */
SELECT * FROM t LIMIT 0, 1;
-- X: 1

/* extensions V203-03 */
SELECT * FROM t LIMIT 10, 1;

/* extensions V203-03 */
SELECT * FROM (SELECT x FROM t ORDER BY x LIMIT 2, 1) AS s;
-- X: 3

/* extensions V001-01 V203-03 */
EXPLAIN SELECT * FROM t LIMIT 1, 2;
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (X INTEGER)
-- EXPLAIN: OFFSET 1 ROWS FETCH FIRST 2 ROWS ONLY
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.X INTEGER)

/* extensions V203-03 */
SELECT * FROM t LIMIT -1, 1;
-- error 2201X: invalid row count in result offset clause

/* extensions V203-03 */
SELECT * FROM t LIMIT 1, -1;
-- error 2201W: invalid row count in fetch first clause

/* extensions V203-03 */
SELECT * FROM t LIMIT 1.5, 1;
-- error 42601: syntax error: OFFSET row count must be an exact numeric with scale 0, got NUMERIC(2, 1)

/* extensions V203-03 */
SELECT * FROM t LIMIT 1, 1.5;
-- error 42601: syntax error: FETCH FIRST row count must be an exact numeric with scale 0, got NUMERIC(2, 1)

SELECT * FROM t LIMIT 1, 2 OFFSET 1;
-- error 42601: syntax error: unexpected OFFSET

SELECT * FROM t LIMIT 1, 2, 3;
-- error 42601: syntax error: unexpected ","

SELECT * FROM t OFFSET 1 LIMIT 1, 2;
-- error 42601: syntax error: unexpected ","

/* extensions V203-01 */
SELECT * FROM t ORDER BY x DESC LIMIT 1;
-- X: 4

/* extensions V203-01 V203-02 */
SELECT * FROM t ORDER BY x DESC LIMIT 1 OFFSET 1;
-- X: 3

/* extensions V203-01 V203-02 */
SELECT * FROM t ORDER BY x DESC OFFSET 1 LIMIT 1;
-- X: 3

/* extensions V203-01 */
SELECT * FROM t ORDER BY x DESC OFFSET 2 ROWS LIMIT 1;
-- X: 2

-- # A LIMIT past the end returns all of the rows.
/* extensions V203-01 V203-02 */
SELECT * FROM t LIMIT 10 OFFSET 3;
-- X: 4

-- # Subqueries, set operations and VALUES.
/* extensions V203-01 */
SELECT * FROM (SELECT * FROM t ORDER BY x DESC LIMIT 2) AS s ORDER BY x LIMIT 1;
-- X: 3

/* extensions V203-01 */
SELECT x FROM t WHERE x = (SELECT x FROM t ORDER BY x DESC LIMIT 1);
-- X: 4

/* extensions V203-01 */
SELECT x FROM t WHERE x IN (SELECT x FROM t LIMIT 1);
-- X: 1

/* extensions V203-01 */
SELECT x FROM t WHERE x = 1 AND EXISTS (SELECT x FROM t LIMIT 1);
-- X: 1

/* extensions V203-01 */
SELECT x FROM t UNION SELECT x FROM t ORDER BY x LIMIT 1;
-- X: 1

/* extensions V203-01 */
(SELECT x FROM t ORDER BY x LIMIT 1) UNION (SELECT x FROM t ORDER BY x DESC LIMIT 1) ORDER BY x;
-- X: 1
-- X: 4

/* extensions V203-01 */
VALUES 1, 2, 3 LIMIT 2;
-- COL1: 1
-- COL1: 2

/* extensions V203-01 V203-02 */
VALUES 1, 2, 3 LIMIT 1 OFFSET 2;
-- COL1: 3

-- # A cursor is a query_expression too.
/* extensions V108-01 V109-01 V110-01 V111-01 V203-01 V203-02 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM t LIMIT 1 OFFSET 1;
OPEN c;
FETCH NEXT FROM c;
FETCH NEXT FROM c;
CLOSE c;
COMMIT;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- X: 2
-- warning 02000: no data
-- msg: CLOSE
-- msg: COMMIT

-- # It's the same plan.
/* extensions V001-01 V203-01 V203-02 */
EXPLAIN SELECT * FROM t LIMIT 2 OFFSET 1;
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (X INTEGER)
-- EXPLAIN: OFFSET 1 ROWS FETCH FIRST 2 ROWS ONLY
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.X INTEGER)

/* extensions V001-01 */
EXPLAIN SELECT * FROM t OFFSET 1 ROWS FETCH FIRST 2 ROWS ONLY;
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (X INTEGER)
-- EXPLAIN: OFFSET 1 ROWS FETCH FIRST 2 ROWS ONLY
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.X INTEGER)

-- # The same errors as FETCH FIRST and OFFSET.
/* extensions V203-01 */
SELECT * FROM t LIMIT 0;
-- error 2201W: invalid row count in fetch first clause

/* extensions V203-01 */
SELECT * FROM t LIMIT -1;
-- error 2201W: invalid row count in fetch first clause

/* extensions V203-01 V203-02 */
SELECT * FROM t LIMIT 1 OFFSET -1;
-- error 2201X: invalid row count in result offset clause

/* extensions V203-01 V203-02 */
SELECT * FROM t OFFSET -1 LIMIT 1;
-- error 2201X: invalid row count in result offset clause

/* extensions V203-01 */
SELECT * FROM t ORDER BY x DESC LIMIT -1;
-- error 2201W: invalid row count in fetch first clause

/* extensions V203-01 */
SELECT * FROM t OFFSET 1 ROWS LIMIT -1;
-- error 2201W: invalid row count in fetch first clause

/* extensions V203-01 */
VALUES 1 LIMIT +0;
-- error 2201W: invalid row count in fetch first clause

/* extensions V203-01 */
VALUES 1, 2 LIMIT +1;
-- COL1: 1

/* extensions V203-01 */
SELECT * FROM t LIMIT 1.5;
-- error 42601: syntax error: FETCH FIRST row count must be an exact numeric with scale 0, got NUMERIC(2, 1)

/* extensions V203-01 */
SELECT * FROM t LIMIT .5;
-- error 42601: syntax error: FETCH FIRST row count must be an exact numeric with scale 0, got NUMERIC(2, 1)

/* extensions V203-01 */
SELECT * FROM t LIMIT -.5;
-- error 42601: syntax error: FETCH FIRST row count must be an exact numeric with scale 0, got NUMERIC(2, 1)

/* extensions V203-01 */
SELECT * FROM t LIMIT 1e0;
-- error 42601: syntax error: FETCH FIRST row count must be an exact numeric with scale 0, got DOUBLE PRECISION

/* extensions V203-01 */
SELECT * FROM t LIMIT 'a';
-- error 42601: syntax error: FETCH FIRST row count must be an exact numeric with scale 0, got CHARACTER(1)

/* extensions V203-01 */
SELECT * FROM t LIMIT TRUE;
-- error 42601: syntax error: FETCH FIRST row count must be an exact numeric with scale 0, got BOOLEAN

/* extensions V203-01 */
SELECT * FROM t LIMIT DATE '2026-11-03';
-- error 42601: syntax error: FETCH FIRST row count must be an exact numeric with scale 0, got DATE

/* extensions V203-01 V203-02 */
SELECT * FROM t LIMIT 1 OFFSET 1.5;
-- error 42601: syntax error: OFFSET row count must be an exact numeric with scale 0, got NUMERIC(2, 1)

-- # A dynamic parameter isn't allowed, the same as FETCH FIRST.
SELECT * FROM t LIMIT ?;
-- error 42601: syntax error: unexpected "?"

SELECT * FROM t FETCH FIRST ? ROWS ONLY;
-- error 42601: syntax error: unexpected "?"

-- # Both of them is a syntax error, in any order.
SELECT * FROM t LIMIT 1 FETCH FIRST 1 ROW ONLY;
-- error 42601: syntax error: unexpected FETCH

SELECT * FROM t FETCH FIRST 1 ROW ONLY LIMIT 1;
-- error 42601: syntax error: unexpected LIMIT

SELECT * FROM t OFFSET 1 ROW FETCH FIRST 1 ROW ONLY LIMIT 1;
-- error 42601: syntax error: unexpected LIMIT

SELECT * FROM t LIMIT 1 LIMIT 1;
-- error 42601: syntax error: unexpected LIMIT

SELECT * FROM t LIMIT 1 OFFSET 1 OFFSET 1;
-- error 42601: syntax error: unexpected OFFSET

SELECT * FROM t LIMIT 1 ORDER BY x;
-- error 42601: syntax error: unexpected ORDER

-- # There's no "LIMIT ALL".
SELECT * FROM t LIMIT ALL;
-- error 42601: syntax error: unexpected ALL

-- # The flagger: LIMIT is V203-01, and FETCH FIRST isn't. They are both a row
-- # count of a query, so they need the same features to be written the standard
-- # way.
/* flags */
/* extensions V203-01 */
SELECT * FROM t ORDER BY x LIMIT 1;
-- flags: F857, V203-01
-- X: 1

/* flags */
SELECT * FROM t ORDER BY x FETCH FIRST 1 ROW ONLY;
-- flags: F857
-- X: 1

/* flags */
/* extensions V203-01 V203-02 */
SELECT * FROM t ORDER BY x LIMIT 1 OFFSET 1;
-- flags: F857, F861, V203-01, V203-02
-- X: 2

/* flags */
SELECT * FROM t ORDER BY x OFFSET 1 ROW FETCH FIRST 1 ROW ONLY;
-- flags: F857, F861
-- X: 2

/* flags */
/* extensions V203-01 V203-02 */
SELECT * FROM t ORDER BY x OFFSET 1.5 LIMIT 2.5;
-- flags: F857, F860, F861, F865, V203-01, V203-02
-- error 42601: syntax error: OFFSET row count must be an exact numeric with scale 0, got NUMERIC(2, 1)

/* flags */
/* extensions V203-02 */
SELECT * FROM t ORDER BY x OFFSET 1 FETCH FIRST 1 ROW ONLY;
-- flags: F857, F861, V203-02
-- X: 2

/* flags */
/* extensions V203-03 */
SELECT * FROM t ORDER BY x LIMIT 1, 1;
-- flags: F857, F861, V203-03
-- X: 2

/* extensions V201-01 V203-01 */
SELECT 1 LIMIT 1;
-- COL1: 1
