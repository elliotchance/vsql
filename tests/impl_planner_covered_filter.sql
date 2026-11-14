-- # The parts of the WHERE clause (joined by AND) that the range of a PRIMARY
-- # KEY or index covers exactly aren't checked again for each row. That's only
-- # an integer column compared with =, >= or <= (or BETWEEN) to a constant
-- # integer that the column can hold, when the range is made from it. Anything
-- # else is still checked by the WHERE clause.

/* setup */
CREATE TABLE t (id INT PRIMARY KEY, name VARCHAR(10));
INSERT INTO t (id, name) VALUES (-2, 'minus two'), (1, 'one'), (2, 'two'), (3, 'three'), (5, 'five'), (6, 'six');
CREATE TABLE c (a INT, b INT, x INT, PRIMARY KEY (a, b));
INSERT INTO c (a, b, x) VALUES (1, 1, 1), (1, 2, 2), (1, 3, 3), (2, 1, 4), (2, 2, 5), (3, 1, 6);
CREATE TABLE si (id SMALLINT PRIMARY KEY);
INSERT INTO si (id) VALUES (1), (2), (32767);
CREATE TABLE bi (id BIGINT PRIMARY KEY);
INSERT INTO bi (id) VALUES (9007199254740992), (9007199254740993), (9007199254740994);
CREATE TABLE s (code VARCHAR(10) PRIMARY KEY);
INSERT INTO s (code) VALUES ('a'), ('a b'), ('b');
CREATE TABLE n (id INT PRIMARY KEY, v INT, w INT);
INSERT INTO n (id, v, w) VALUES (1, 1, 1), (2, 2, NULL), (3, NULL, 2), (4, 3, 3), (5, 2, 4), (6, NULL, NULL);

-- # = on the whole PRIMARY KEY covers the condition, so there's no WHERE. The
-- # next key (3) isn't read.
/* extensions V001-01 */
EXPLAIN SELECT * FROM t WHERE id = 2;
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.T (ID INTEGER NOT NULL, NAME CHARACTER VARYING(10)) RANGE ID = 2
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.ID INTEGER NOT NULL, ":memory:".PUBLIC.T.NAME CHARACTER VARYING(10))

SELECT * FROM t WHERE id = 2;
SELECT * FROM t WHERE id = 4;
SELECT * FROM t WHERE 5 = id;
SELECT * FROM t WHERE id = -2;
-- ID: 2 NAME: two
-- ID: 5 NAME: five
-- ID: -2 NAME: minus two

-- # Only the other conditions are left.
/* extensions V001-01 */
EXPLAIN SELECT * FROM t WHERE id = 2 AND name = 'two';
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.T (ID INTEGER NOT NULL, NAME CHARACTER VARYING(10)) RANGE ID = 2
-- EXPLAIN: WHERE NAME = 'two'
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.ID INTEGER NOT NULL, ":memory:".PUBLIC.T.NAME CHARACTER VARYING(10))

/* extensions V001-01 */
EXPLAIN SELECT * FROM t WHERE name <> 'x' AND id = 2 AND (name = 'two' OR name = 'one') AND TRUE;
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.T (ID INTEGER NOT NULL, NAME CHARACTER VARYING(10)) RANGE ID = 2
-- EXPLAIN: WHERE NAME <> 'x' AND (NAME = 'two' OR NAME = 'one') AND TRUE
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.ID INTEGER NOT NULL, ":memory:".PUBLIC.T.NAME CHARACTER VARYING(10))

SELECT * FROM t WHERE id = 2 AND name = 'two';
SELECT * FROM t WHERE id = 2 AND name = 'one';
SELECT * FROM t WHERE name <> 'x' AND id = 3 AND (name = 'two' OR name = 'three') AND TRUE;
-- ID: 2 NAME: two
-- ID: 3 NAME: three

-- # >=, <= and BETWEEN are covered, the last key (6) isn't read for <= 5.
/* extensions V001-01 */
EXPLAIN SELECT * FROM t WHERE id >= 1 AND id <= 5;
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.T (ID INTEGER NOT NULL, NAME CHARACTER VARYING(10)) RANGE ID >= 1 AND ID <= 5
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.ID INTEGER NOT NULL, ":memory:".PUBLIC.T.NAME CHARACTER VARYING(10))

/* extensions V001-01 */
EXPLAIN SELECT * FROM t WHERE id BETWEEN 1 AND 5;
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.T (ID INTEGER NOT NULL, NAME CHARACTER VARYING(10)) RANGE ID >= 1 AND ID <= 5
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.ID INTEGER NOT NULL, ":memory:".PUBLIC.T.NAME CHARACTER VARYING(10))

SELECT * FROM t WHERE id >= 1 AND id <= 5;
SELECT * FROM t WHERE id BETWEEN 2 AND 3;
SELECT * FROM t WHERE id <= 2;
SELECT * FROM t WHERE 5 <= id;
SELECT * FROM t WHERE id BETWEEN 3 AND 1;
-- ID: 1 NAME: one
-- ID: 2 NAME: two
-- ID: 3 NAME: three
-- ID: 5 NAME: five
-- ID: 2 NAME: two
-- ID: 3 NAME: three
-- ID: -2 NAME: minus two
-- ID: 1 NAME: one
-- ID: 2 NAME: two
-- ID: 5 NAME: five
-- ID: 6 NAME: six

-- # Two bounds on the same side are both covered, since the tightest one is
-- # used.
/* extensions V001-01 */
EXPLAIN SELECT * FROM t WHERE id >= 1 AND id >= 2 AND id <= 5 AND id <= 3;
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.T (ID INTEGER NOT NULL, NAME CHARACTER VARYING(10)) RANGE ID >= 1 AND ID >= 2 AND ID <= 5 AND ID <= 3
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.ID INTEGER NOT NULL, ":memory:".PUBLIC.T.NAME CHARACTER VARYING(10))

SELECT * FROM t WHERE id >= 1 AND id >= 2 AND id <= 5 AND id <= 3;
-- ID: 2 NAME: two
-- ID: 3 NAME: three

-- # > and < include the bound in the range, so they're still checked.
/* extensions V001-01 */
EXPLAIN SELECT * FROM t WHERE id > 1 AND id <= 5;
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.T (ID INTEGER NOT NULL, NAME CHARACTER VARYING(10)) RANGE ID > 1 AND ID <= 5
-- EXPLAIN: WHERE ID > 1
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.ID INTEGER NOT NULL, ":memory:".PUBLIC.T.NAME CHARACTER VARYING(10))

SELECT * FROM t WHERE id > 1 AND id < 5;
SELECT * FROM t WHERE id > 1 AND id >= 1 AND id < 3;
-- ID: 2 NAME: two
-- ID: 3 NAME: three
-- ID: 2 NAME: two

-- # Only the last = of a column is used for the range, the others (and any
-- # bounds of the same column) are still checked.
/* extensions V001-01 */
EXPLAIN SELECT * FROM t WHERE id = 2 AND id = 3;
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.T (ID INTEGER NOT NULL, NAME CHARACTER VARYING(10)) RANGE ID = 2 AND ID = 3
-- EXPLAIN: WHERE ID = 2
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.ID INTEGER NOT NULL, ":memory:".PUBLIC.T.NAME CHARACTER VARYING(10))

/* extensions V001-01 */
EXPLAIN SELECT * FROM t WHERE id >= 5 AND id = 3;
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.T (ID INTEGER NOT NULL, NAME CHARACTER VARYING(10)) RANGE ID >= 5 AND ID = 3
-- EXPLAIN: WHERE ID >= 5
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.ID INTEGER NOT NULL, ":memory:".PUBLIC.T.NAME CHARACTER VARYING(10))

SELECT * FROM t WHERE id = 2 AND id = 3;
SELECT * FROM t WHERE id = 3 AND id = 3;
SELECT * FROM t WHERE id >= 5 AND id = 3;
SELECT * FROM t WHERE id >= 2 AND id = 3;
-- ID: 3 NAME: three
-- ID: 3 NAME: three

-- # An OR can be true for any row, so it reads the whole table.
/* extensions V001-01 */
EXPLAIN SELECT * FROM t WHERE id = 1 OR id = 2;
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (ID INTEGER NOT NULL, NAME CHARACTER VARYING(10))
-- EXPLAIN: WHERE ID = 1 OR ID = 2
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.ID INTEGER NOT NULL, ":memory:".PUBLIC.T.NAME CHARACTER VARYING(10))

SELECT * FROM t WHERE id = 1 OR id = 2 OR id = 4;
SELECT * FROM t WHERE (id = 1 OR id = 2) AND id >= 2;
-- ID: 1 NAME: one
-- ID: 2 NAME: two
-- ID: 2 NAME: two

-- # A constant expression is covered, including a parameter, since its value is
-- # cast to the type that it's compared with (an integer).
/* extensions V001-01 */
EXPLAIN SELECT * FROM t WHERE id = 1 + 1;
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.T (ID INTEGER NOT NULL, NAME CHARACTER VARYING(10)) RANGE ID = 1 + 1
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.ID INTEGER NOT NULL, ":memory:".PUBLIC.T.NAME CHARACTER VARYING(10))

/* params 3 */
/* extensions V001-01 */
EXPLAIN SELECT * FROM t WHERE id = CAST(? AS INT);
SELECT * FROM t WHERE id = CAST(? AS INT);
-- sql: EXPLAIN SELECT * FROM t WHERE id = CAST(3.0e0 AS INT)
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.T (ID INTEGER NOT NULL, NAME CHARACTER VARYING(10)) RANGE ID = CAST(3 AS INTEGER)
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.ID INTEGER NOT NULL, ":memory:".PUBLIC.T.NAME CHARACTER VARYING(10))
-- sql: SELECT * FROM t WHERE id = CAST(3.0e0 AS INT)
-- ID: 3 NAME: three

/* params 3 */
/* extensions V001-01 */
EXPLAIN SELECT * FROM t WHERE id = ?;
SELECT * FROM t WHERE id = ?;
-- sql: EXPLAIN SELECT * FROM t WHERE id = 3.0e0
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.T (ID INTEGER NOT NULL, NAME CHARACTER VARYING(10)) RANGE ID = 3
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.ID INTEGER NOT NULL, ":memory:".PUBLIC.T.NAME CHARACTER VARYING(10))
-- sql: SELECT * FROM t WHERE id = 3.0e0
-- ID: 3 NAME: three

-- # A value that isn't an integer is still checked, even when it's equal to
-- # one, since it may not be compared the same way.
/* extensions V001-01 */
EXPLAIN SELECT * FROM t WHERE id = 2.0;
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.T (ID INTEGER NOT NULL, NAME CHARACTER VARYING(10)) RANGE ID = 2.0
-- EXPLAIN: WHERE ID = 2.0
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.ID INTEGER NOT NULL, ":memory:".PUBLIC.T.NAME CHARACTER VARYING(10))

SELECT * FROM t WHERE id = 2.0;
SELECT * FROM t WHERE id = 2.5;
SELECT * FROM t WHERE id <= 2.5 AND id >= 1;
SELECT * FROM t WHERE id = 3e0;
-- ID: 2 NAME: two
-- ID: 1 NAME: one
-- ID: 2 NAME: two
-- ID: 3 NAME: three

-- # A value that the column can't hold isn't used for the range, so it's still
-- # checked.
/* extensions V001-01 */
EXPLAIN SELECT * FROM si WHERE id <= 100000 AND id >= 2;
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.SI (ID SMALLINT NOT NULL) RANGE ID <= 100000 AND ID >= 2
-- EXPLAIN: WHERE ID <= 100000
-- EXPLAIN: EXPR (":memory:".PUBLIC.SI.ID SMALLINT NOT NULL)

SELECT * FROM si WHERE id <= 100000 AND id >= 2;
SELECT * FROM si WHERE id = 100000;
SELECT * FROM si WHERE id = 32767;
-- ID: 2
-- ID: 32767
-- ID: 32767

-- # NULL is never equal to anything, and a value that raises an error must
-- # still raise it.
/* extensions V001-01 */
EXPLAIN SELECT * FROM t WHERE id = CAST(NULL AS INT);
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.T (ID INTEGER NOT NULL, NAME CHARACTER VARYING(10)) RANGE ID = CAST(NULL AS INTEGER)
-- EXPLAIN: WHERE ID = CAST(NULL AS INTEGER)
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.ID INTEGER NOT NULL, ":memory:".PUBLIC.T.NAME CHARACTER VARYING(10))

SELECT * FROM t WHERE id = CAST(NULL AS INT);
SELECT * FROM t WHERE id >= 1 AND id <= CAST(NULL AS INT);

SELECT * FROM t WHERE id = 1 / 0;
-- error 22012: division by zero

/* params NULL INTEGER */
/* extensions V001-01 */
EXPLAIN SELECT * FROM t WHERE id = ?;
SELECT * FROM t WHERE id = ?;
-- sql: EXPLAIN SELECT * FROM t WHERE id = CAST(NULL AS INTEGER)
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.T (ID INTEGER NOT NULL, NAME CHARACTER VARYING(10)) RANGE ID = NULL
-- EXPLAIN: WHERE ID = NULL
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.ID INTEGER NOT NULL, ":memory:".PUBLIC.T.NAME CHARACTER VARYING(10))
-- sql: SELECT * FROM t WHERE id = CAST(NULL AS INTEGER)

-- # A value that isn't constant is still checked.
/* extensions V001-01 */
EXPLAIN SELECT * FROM t WHERE id = (SELECT MAX(x) FROM c);
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.T (ID INTEGER NOT NULL, NAME CHARACTER VARYING(10)) RANGE ID = (SELECT MAX(X) FROM C)
-- EXPLAIN: WHERE ID = (SELECT MAX(X) FROM C)
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.ID INTEGER NOT NULL, ":memory:".PUBLIC.T.NAME CHARACTER VARYING(10))

SELECT * FROM t WHERE id = (SELECT MAX(x) FROM c);
-- ID: 6 NAME: six

-- # BIGINT is compared exactly.
SELECT * FROM bi WHERE id = 9007199254740993;
SELECT * FROM bi WHERE id >= 9007199254740993;
-- ID: 9007199254740993
-- ID: 9007199254740993
-- ID: 9007199254740994

-- # A string can be compared differently than its key (such as with trailing
-- # spaces), so it's still checked.
/* extensions V001-01 */
EXPLAIN SELECT * FROM s WHERE code = 'a';
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.S (CODE CHARACTER VARYING(10) NOT NULL) RANGE CODE = 'a'
-- EXPLAIN: WHERE CODE = 'a'
-- EXPLAIN: EXPR (":memory:".PUBLIC.S.CODE CHARACTER VARYING(10) NOT NULL)

SELECT * FROM s WHERE code = 'a';
SELECT * FROM s WHERE code = 'a ';
-- CODE: a
-- CODE: a

-- # Each column of the key before the one with a range has to be covered by =,
-- # otherwise the columns after it aren't used for the range.
/* extensions V001-01 */
EXPLAIN SELECT * FROM c WHERE a = 1 AND b = 2;
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.C (A INTEGER NOT NULL, B INTEGER NOT NULL, X INTEGER) RANGE A = 1 AND B = 2
-- EXPLAIN: EXPR (":memory:".PUBLIC.C.A INTEGER NOT NULL, ":memory:".PUBLIC.C.B INTEGER NOT NULL, ":memory:".PUBLIC.C.X INTEGER)

/* extensions V001-01 */
EXPLAIN SELECT * FROM c WHERE a = 1 AND b >= 2;
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.C (A INTEGER NOT NULL, B INTEGER NOT NULL, X INTEGER) RANGE A = 1 AND B >= 2
-- EXPLAIN: EXPR (":memory:".PUBLIC.C.A INTEGER NOT NULL, ":memory:".PUBLIC.C.B INTEGER NOT NULL, ":memory:".PUBLIC.C.X INTEGER)

/* extensions V001-01 */
EXPLAIN SELECT * FROM c WHERE a >= 2 AND b = 1;
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.C (A INTEGER NOT NULL, B INTEGER NOT NULL, X INTEGER) RANGE A >= 2 AND B = 1
-- EXPLAIN: WHERE B = 1
-- EXPLAIN: EXPR (":memory:".PUBLIC.C.A INTEGER NOT NULL, ":memory:".PUBLIC.C.B INTEGER NOT NULL, ":memory:".PUBLIC.C.X INTEGER)

/* extensions V001-01 */
EXPLAIN SELECT * FROM c WHERE a = 1.5 AND b = 1;
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.C (A INTEGER NOT NULL, B INTEGER NOT NULL, X INTEGER) RANGE A = 1.5 AND B = 1
-- EXPLAIN: WHERE A = 1.5 AND B = 1
-- EXPLAIN: EXPR (":memory:".PUBLIC.C.A INTEGER NOT NULL, ":memory:".PUBLIC.C.B INTEGER NOT NULL, ":memory:".PUBLIC.C.X INTEGER)

/* extensions V001-01 */
EXPLAIN SELECT * FROM c WHERE b = 1;
-- EXPLAIN: TABLE ":memory:".PUBLIC.C (A INTEGER NOT NULL, B INTEGER NOT NULL, X INTEGER)
-- EXPLAIN: WHERE B = 1
-- EXPLAIN: EXPR (":memory:".PUBLIC.C.A INTEGER NOT NULL, ":memory:".PUBLIC.C.B INTEGER NOT NULL, ":memory:".PUBLIC.C.X INTEGER)

SELECT x FROM c WHERE a = 1 AND b = 2;
SELECT x FROM c WHERE a = 1 AND b >= 2;
SELECT x FROM c WHERE a = 1 AND b BETWEEN 2 AND 2;
SELECT x FROM c WHERE a >= 2 AND b = 1;
SELECT x FROM c WHERE a = 1.5 AND b = 1;
SELECT x FROM c WHERE a = 2;
-- X: 2
-- X: 2
-- X: 3
-- X: 2
-- X: 4
-- X: 6
-- X: 4
-- X: 5

-- # An index is the same. NULL is never in a range, so it doesn't need to be
-- # checked either.
/* extensions V001-01 V002-01 */
CREATE INDEX n_v ON n (v);
EXPLAIN SELECT id FROM n WHERE v = 2;
-- msg: CREATE INDEX 1
-- EXPLAIN: INDEX ":memory:".PUBLIC.N_V ON ":memory:".PUBLIC.N (ID INTEGER NOT NULL, V INTEGER, W INTEGER) RANGE V = 2
-- EXPLAIN: EXPR (ID INTEGER NOT NULL)

/* extensions V002-01 */
CREATE INDEX n_v ON n (v);
CREATE INDEX n_w ON n (w DESC);
SELECT id FROM n WHERE v = 2;
SELECT id FROM n WHERE v <= 2;
SELECT id FROM n WHERE v >= 2;
SELECT id FROM n WHERE w <= 2;
SELECT id FROM n WHERE w >= 2;
SELECT id FROM n WHERE w BETWEEN 2 AND 3;
-- msg: CREATE INDEX 1
-- msg: CREATE INDEX 1
-- ID: 2
-- ID: 5
-- ID: 1
-- ID: 2
-- ID: 5
-- ID: 2
-- ID: 5
-- ID: 4
-- ID: 3
-- ID: 1
-- ID: 5
-- ID: 4
-- ID: 3
-- ID: 4
-- ID: 3

-- # A correlation name is the same.
/* extensions V001-01 */
EXPLAIN SELECT * FROM t AS x WHERE x.id = 1;
-- EXPLAIN: X:
-- EXPLAIN:   PRIMARY KEY ":memory:".PUBLIC.T (ID INTEGER NOT NULL, NAME CHARACTER VARYING(10)) RANGE X.ID = 1
-- EXPLAIN: TABLE X (ID INTEGER NOT NULL, NAME CHARACTER VARYING(10))
-- EXPLAIN: EXPR (X.ID INTEGER NOT NULL, X.NAME CHARACTER VARYING(10))

SELECT * FROM t AS x (a, b) WHERE a = 1 AND b = 'one';
SELECT * FROM t AS x (a, b) WHERE a = 1 AND b = 'two';
-- A: 1 B: one

-- # UPDATE and DELETE only change the rows in the range.
UPDATE t SET name = 'TWO' WHERE id = 2;
DELETE FROM t WHERE id >= 5 AND id <= 5;
SELECT * FROM t;
-- msg: UPDATE 1
-- msg: DELETE 1
-- ID: -2 NAME: minus two
-- ID: 1 NAME: one
-- ID: 2 NAME: TWO
-- ID: 3 NAME: three
-- ID: 6 NAME: six
