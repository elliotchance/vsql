/* setup */
CREATE TABLE t1 (id INT, score INT, name VARCHAR(10));
INSERT INTO t1 VALUES (1, 90, 'a'), (2, 80, 'b'), (3, 80, 'c'), (4, 70, 'd'), (5, 80, 'e'), (6, NULL, 'f'), (7, NULL, 'g');

-- # WITH TIES also keeps the rows after the last fetched row that are its peers,
-- # which have the same value for every sort key (General Rules, 7.d.i). It
-- # needs F867 (Conformance Rules, 24).
/* flags */
SELECT id FROM t1 ORDER BY score DESC FETCH FIRST 2 ROWS WITH TIES;
-- flags: F857, F867
-- ID: 1
-- ID: 2
-- ID: 3
-- ID: 5

-- # With ONLY, it's exactly that many rows.
SELECT id FROM t1 ORDER BY score DESC FETCH FIRST 2 ROWS ONLY;
-- ID: 1
-- ID: 2

-- # A row that isn't tied isn't kept, and when there are no more rows there's
-- # nothing to add. Without a count it's 1, and NEXT and ROW mean the same.
SELECT id FROM t1 ORDER BY score DESC FETCH FIRST 1 ROW WITH TIES;
SELECT id FROM t1 ORDER BY score DESC FETCH NEXT ROW WITH TIES;
SELECT id FROM t1 ORDER BY id FETCH FIRST 7 ROWS WITH TIES;
SELECT id FROM t1 ORDER BY id FETCH FIRST 100 ROWS WITH TIES;
-- ID: 1
-- ID: 1
-- ID: 1
-- ID: 2
-- ID: 3
-- ID: 4
-- ID: 5
-- ID: 6
-- ID: 7
-- ID: 1
-- ID: 2
-- ID: 3
-- ID: 4
-- ID: 5
-- ID: 6
-- ID: 7

-- # Two nulls are peers.
SELECT id FROM t1 ORDER BY score FETCH FIRST 1 ROW WITH TIES;
-- ID: 6
-- ID: 7

-- # With PERCENT, the percentage gives the number of rows (of all the rows,
-- # before OFFSET) and then the peers of the last one are added (General Rules,
-- # 7.b.ii and 7.d.i). 20 percent of 7 rows is 2 rows.
SELECT id FROM t1 ORDER BY score DESC FETCH FIRST 20 PERCENT ROWS WITH TIES;
SELECT id FROM t1 ORDER BY score DESC OFFSET 1 ROW FETCH FIRST 20 PERCENT ROWS WITH TIES;
SELECT id FROM t1 ORDER BY score DESC FETCH FIRST 20 PERCENT ROWS ONLY;
-- ID: 1
-- ID: 2
-- ID: 3
-- ID: 5
-- ID: 2
-- ID: 3
-- ID: 5
-- ID: 1
-- ID: 2

-- # Every sort key must be the same for a row to be a peer.
SELECT id FROM t1 ORDER BY score DESC, name FETCH FIRST 2 ROWS WITH TIES;
-- ID: 1
-- ID: 2

-- # The rows are counted after OFFSET (General Rules, 7.a).
SELECT id FROM t1 ORDER BY score DESC OFFSET 1 ROW FETCH FIRST 1 ROW WITH TIES;
-- ID: 2
-- ID: 3
-- ID: 5

-- # A sort key doesn't have to be in the select list, and it can be an
-- # expression.
SELECT name FROM t1 ORDER BY score / 20 DESC FETCH FIRST 1 ROW WITH TIES;
-- NAME: a
-- NAME: b
-- NAME: c
-- NAME: e

-- # It works on a grouped query, a set operation, a derived table, and in a
-- # subquery.
/* extensions V202-01 V202-03 */
SELECT score, COUNT(*) AS c FROM t1 WHERE score IS NOT NULL GROUP BY score ORDER BY COUNT(*) FETCH FIRST 1 ROW WITH TIES;
SELECT score FROM t1 WHERE id < 3 UNION ALL SELECT score FROM t1 WHERE id > 3 ORDER BY score DESC FETCH FIRST 2 ROWS WITH TIES;
SELECT * FROM (VALUES 3, 1, 1, 2) AS v (x) ORDER BY x FETCH FIRST 1 ROW WITH TIES;
SELECT COUNT(*) FROM (SELECT * FROM t1 ORDER BY score DESC FETCH FIRST 2 ROWS WITH TIES) AS s;
-- SCORE: 70 C: 1
-- SCORE: 90 C: 1
-- SCORE: 90
-- SCORE: 80
-- SCORE: 80
-- X: 1
-- X: 1
-- COL1: 4

-- # It needs an ORDER BY, at the top or in parentheses (Syntax Rules, 30).
SELECT id FROM t1 FETCH FIRST 2 ROWS WITH TIES;
SELECT id FROM t1 OFFSET 1 ROW FETCH FIRST 2 ROWS WITH TIES;
SELECT * FROM (SELECT id FROM t1 FETCH FIRST 1 ROW WITH TIES) AS s;
(SELECT id FROM t1 FETCH FIRST 1 ROW WITH TIES) UNION SELECT id FROM t1;
-- error 42601: syntax error: FETCH FIRST WITH TIES requires an ORDER BY
-- error 42601: syntax error: FETCH FIRST WITH TIES requires an ORDER BY
-- error 42601: syntax error: FETCH FIRST WITH TIES requires an ORDER BY
-- error 42601: syntax error: FETCH FIRST WITH TIES requires an ORDER BY

-- # LIMIT doesn't have WITH TIES.
SELECT id FROM t1 ORDER BY score LIMIT 1 WITH TIES;
-- error 42601: syntax error: unexpected WITH at line 1, column 42 near "score LIMIT 1 WITH TIES"

/* extensions V001-01 */
EXPLAIN SELECT id FROM t1 ORDER BY score DESC FETCH FIRST 2 ROWS WITH TIES;
EXPLAIN SELECT id FROM t1 ORDER BY score DESC FETCH FIRST 20 PERCENT ROWS WITH TIES;
-- EXPLAIN: TABLE ":memory:".PUBLIC.T1 (ID INTEGER, SCORE INTEGER, NAME CHARACTER VARYING(10))
-- EXPLAIN: ORDER BY SCORE DESC
-- EXPLAIN: FETCH FIRST 2 ROWS WITH TIES
-- EXPLAIN: EXPR (ID INTEGER)
-- EXPLAIN: TABLE ":memory:".PUBLIC.T1 (ID INTEGER, SCORE INTEGER, NAME CHARACTER VARYING(10))
-- EXPLAIN: ORDER BY SCORE DESC
-- EXPLAIN: FETCH FIRST 20 PERCENT ROWS WITH TIES
-- EXPLAIN: EXPR (ID INTEGER)
