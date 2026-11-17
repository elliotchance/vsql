-- # NULLS FIRST puts null values before every other value and NULLS LAST puts
-- # them after, whichever direction the sort is in (General Rules, 1.e.ii.2
-- # and 1.e.ii.3). Without a <null ordering> they're first for ASC and last for
-- # DESC (see std_2_10_10_order_nulls.sql). A <null ordering> needs T611
-- # (Conformance Rules, 1).
/* setup */
CREATE TABLE t (id INT PRIMARY KEY, x INT, y VARCHAR(10));
INSERT INTO t (id, x, y) VALUES (1, 20, 'b'), (2, NULL, 'a'), (3, 10, NULL), (4, NULL, 'c'), (5, 30, 'a');

SELECT x FROM t ORDER BY x NULLS LAST;
-- X: 10
-- X: 20
-- X: 30
-- X: NULL
-- X: NULL

SELECT x FROM t ORDER BY x ASC NULLS FIRST;
-- X: NULL
-- X: NULL
-- X: 10
-- X: 20
-- X: 30

SELECT x FROM t ORDER BY x DESC NULLS FIRST;
-- X: NULL
-- X: NULL
-- X: 30
-- X: 20
-- X: 10

SELECT x FROM t ORDER BY x DESC NULLS LAST;
-- X: 30
-- X: 20
-- X: 10
-- X: NULL
-- X: NULL

-- # Each sort key has its own <null ordering>.
SELECT id FROM t ORDER BY y NULLS LAST, x DESC NULLS FIRST;
-- ID: 2
-- ID: 5
-- ID: 1
-- ID: 4
-- ID: 3

/* flags */
SELECT x FROM t ORDER BY x NULLS FIRST;
-- flags: T611
-- X: NULL
-- X: NULL
-- X: 10
-- X: 20
-- X: 30

-- # The PRIMARY KEY has the rows in order of id, but the other <null ordering>
-- # of a column that can be null isn't the order of an index, so it's sorted.
/* extensions V001-01 V002-01 */
CREATE INDEX t_x ON t (x);
EXPLAIN SELECT id FROM t ORDER BY id NULLS FIRST;
EXPLAIN SELECT x FROM t ORDER BY x NULLS LAST;
SELECT x FROM t ORDER BY x NULLS LAST;
-- msg: CREATE INDEX 1
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (ID INTEGER NOT NULL, X INTEGER, Y CHARACTER VARYING(10))
-- EXPLAIN: EXPR (ID INTEGER NOT NULL)
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (ID INTEGER NOT NULL, X INTEGER, Y CHARACTER VARYING(10))
-- EXPLAIN: ORDER BY X ASC NULLS LAST
-- EXPLAIN: EXPR (X INTEGER)
-- X: 10
-- X: 20
-- X: 30
-- X: NULL
-- X: NULL

-- # The order of a WITHIN GROUP also has a <null ordering>. Two aggregate
-- # functions that only differ by their <null ordering> are different.
/* flags */
SELECT LISTAGG(y, ',') WITHIN GROUP (ORDER BY x NULLS LAST, y), LISTAGG(y, ',') WITHIN GROUP (ORDER BY x NULLS FIRST, y) FROM t;
-- flags: T611, T625
-- warning 01003: null value eliminated in set function
-- COL1: b,a,a,c COL2: a,c,b,a

/* extensions V001-01 */
EXPLAIN SELECT LISTAGG(y, ',') WITHIN GROUP (ORDER BY x DESC NULLS FIRST, y DESC NULLS LAST) FROM t;
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (ID INTEGER NOT NULL, X INTEGER, Y CHARACTER VARYING(10))
-- EXPLAIN: GROUP BY (LISTAGG(Y, ',') WITHIN GROUP (ORDER BY X DESC NULLS FIRST, Y DESC) CHARACTER VARYING(10485760))
-- EXPLAIN: EXPR (COL1 CHARACTER VARYING(10485760))

-- # A null value is placed by the <null ordering> in a hypothetical set
-- # function too.
SELECT RANK(15) WITHIN GROUP (ORDER BY x), RANK(15) WITHIN GROUP (ORDER BY x NULLS LAST), RANK(15) WITHIN GROUP (ORDER BY x DESC NULLS FIRST), RANK(CAST(NULL AS INT)) WITHIN GROUP (ORDER BY x DESC NULLS FIRST) FROM t;
-- COL1: 4 COL2: 2 COL3: 5 COL4: 1

/* extensions V108-01 V109-01 V110-01 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT id, x FROM t ORDER BY x DESC NULLS FIRST;
OPEN c;
FETCH NEXT FROM c;
FETCH NEXT FROM c;
FETCH NEXT FROM c;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- ID: 2 X: NULL
-- ID: 4 X: NULL
-- ID: 5 X: 30
