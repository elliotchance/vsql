/* setup */
CREATE TABLE t (id INT PRIMARY KEY, name VARCHAR(10));
INSERT INTO t (id, name) VALUES (-2, 'minus two'), (1, 'one'), (2, 'two'), (3, 'three'), (5, 'five');
CREATE TABLE s (code VARCHAR(10) PRIMARY KEY, n INT);
INSERT INTO s (code, n) VALUES ('a', 1), ('ab', 2), ('b', 3), ('a b', 4);
CREATE TABLE c (a INT, b VARCHAR(5), x INT, PRIMARY KEY (a, b));
INSERT INTO c (a, b, x) VALUES (1, 'x', 1), (1, 'y', 2), (2, 'x', 3), (2, 'y', 4), (3, 'x', 5);

-- # A range of the PRIMARY KEY only reads those rows. The WHERE clause is still
-- # applied to them, except for what the range covers (see
-- # impl_planner_covered_filter.sql).
/* extensions V001-01 */
EXPLAIN SELECT * FROM t WHERE id > 1 AND id <= 3;
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.T (ID INTEGER NOT NULL, NAME CHARACTER VARYING(10)) RANGE ID > 1 AND ID <= 3
-- EXPLAIN: WHERE ID > 1
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.ID INTEGER NOT NULL, ":memory:".PUBLIC.T.NAME CHARACTER VARYING(10))

SELECT * FROM t WHERE id > 1 AND id <= 3;
-- ID: 2 NAME: two
-- ID: 3 NAME: three

SELECT * FROM t WHERE id >= 2 AND id < 5;
-- ID: 2 NAME: two
-- ID: 3 NAME: three

-- # Only one side can be bounded, and the value can be on either side.
SELECT * FROM t WHERE 3 > id;
-- ID: -2 NAME: minus two
-- ID: 1 NAME: one
-- ID: 2 NAME: two

SELECT * FROM t WHERE 3 <= id;
-- ID: 3 NAME: three
-- ID: 5 NAME: five

-- # The tightest bound is used.
/* extensions V001-01 */
EXPLAIN SELECT * FROM t WHERE id > 1 AND id > 2 AND id < 5 AND id < 4;
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.T (ID INTEGER NOT NULL, NAME CHARACTER VARYING(10)) RANGE ID > 1 AND ID > 2 AND ID < 5 AND ID < 4
-- EXPLAIN: WHERE ID > 1 AND ID > 2 AND ID < 5 AND ID < 4
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.ID INTEGER NOT NULL, ":memory:".PUBLIC.T.NAME CHARACTER VARYING(10))

SELECT * FROM t WHERE id > 1 AND id > 2 AND id < 5 AND id < 4;
-- ID: 3 NAME: three

SELECT * FROM t WHERE id = 2 AND id = 3;

-- # BETWEEN is a lower and upper bound. NOT BETWEEN isn't one range, and
-- # SYMMETRIC can have its bounds either way around, so they read the whole
-- # table.
/* extensions V001-01 */
EXPLAIN SELECT * FROM t WHERE id BETWEEN -5 AND 2;
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.T (ID INTEGER NOT NULL, NAME CHARACTER VARYING(10)) RANGE ID >= -5 AND ID <= 2
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.ID INTEGER NOT NULL, ":memory:".PUBLIC.T.NAME CHARACTER VARYING(10))

SELECT * FROM t WHERE id BETWEEN -5 AND 2;
-- ID: -2 NAME: minus two
-- ID: 1 NAME: one
-- ID: 2 NAME: two

SELECT * FROM t WHERE id BETWEEN 3 AND 1;

/* extensions V001-01 */
EXPLAIN SELECT * FROM t WHERE id NOT BETWEEN 1 AND 2;
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (ID INTEGER NOT NULL, NAME CHARACTER VARYING(10))
-- EXPLAIN: WHERE ID NOT BETWEEN 1 AND 2
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.ID INTEGER NOT NULL, ":memory:".PUBLIC.T.NAME CHARACTER VARYING(10))

/* extensions V001-01 */
EXPLAIN SELECT * FROM t WHERE id BETWEEN SYMMETRIC 2 AND 1;
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (ID INTEGER NOT NULL, NAME CHARACTER VARYING(10))
-- EXPLAIN: WHERE ID BETWEEN SYMMETRIC 2 AND 1
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.ID INTEGER NOT NULL, ":memory:".PUBLIC.T.NAME CHARACTER VARYING(10))

SELECT * FROM t WHERE id BETWEEN SYMMETRIC 2 AND 1;
-- ID: 1 NAME: one
-- ID: 2 NAME: two

-- # Other conditions are only applied by the WHERE clause. <> isn't a range,
-- # so only the other bound is used.
/* extensions V001-01 */
EXPLAIN SELECT * FROM t WHERE id = 2 AND name = 'two';
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.T (ID INTEGER NOT NULL, NAME CHARACTER VARYING(10)) RANGE ID = 2
-- EXPLAIN: WHERE NAME = 'two'
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.ID INTEGER NOT NULL, ":memory:".PUBLIC.T.NAME CHARACTER VARYING(10))

SELECT * FROM t WHERE id = 2 AND name = 'two';
-- ID: 2 NAME: two

SELECT * FROM t WHERE name = 'two' AND id = 3;

/* extensions V001-01 */
EXPLAIN SELECT * FROM t WHERE id <> 2 AND id < 2;
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.T (ID INTEGER NOT NULL, NAME CHARACTER VARYING(10)) RANGE ID < 2
-- EXPLAIN: WHERE ID <> 2 AND ID < 2
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.ID INTEGER NOT NULL, ":memory:".PUBLIC.T.NAME CHARACTER VARYING(10))

-- # The value can be any expression that doesn't depend on the row, including
-- # a subquery. A value that uses a column of the row (id = id) can't be.
/* extensions V001-01 */
EXPLAIN SELECT * FROM t WHERE id = 1 + 1;
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.T (ID INTEGER NOT NULL, NAME CHARACTER VARYING(10)) RANGE ID = 1 + 1
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.ID INTEGER NOT NULL, ":memory:".PUBLIC.T.NAME CHARACTER VARYING(10))

SELECT * FROM t WHERE id = 1 + 1;
-- ID: 2 NAME: two

SELECT * FROM t WHERE id = (SELECT MAX(x) FROM c);
-- ID: 5 NAME: five

/* extensions V001-01 */
EXPLAIN SELECT * FROM t WHERE id = id;
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (ID INTEGER NOT NULL, NAME CHARACTER VARYING(10))
-- EXPLAIN: WHERE ID = ID
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.ID INTEGER NOT NULL, ":memory:".PUBLIC.T.NAME CHARACTER VARYING(10))

SELECT * FROM t WHERE id = CHARACTER_LENGTH(name) - 2;
-- ID: 1 NAME: one
-- ID: 3 NAME: three

-- # An outer reference is different for each row of the outer query.
SELECT a, x FROM c WHERE EXISTS (SELECT * FROM t WHERE t.id = c.a + 1);
-- A: 1 X: 1
-- A: 1 X: 2
-- A: 2 X: 3
-- A: 2 X: 4

SELECT a, (SELECT name FROM t WHERE id = a) AS name FROM c WHERE b = 'x';
-- A: 1 NAME: one
-- A: 2 NAME: two
-- A: 3 NAME: three

-- # A value that the column can't hold exactly (1.5 or a number too big for
-- # INT) isn't used to find the rows, and neither is NULL. The WHERE clause
-- # still decides, so = finds nothing and < or > find the rows either side.
SELECT * FROM t WHERE id = 1.5;

SELECT * FROM t WHERE id < 2.5;
-- ID: -2 NAME: minus two
-- ID: 1 NAME: one
-- ID: 2 NAME: two

SELECT * FROM t WHERE id > 2.5;
-- ID: 3 NAME: three
-- ID: 5 NAME: five

SELECT * FROM t WHERE id = 10000000000;

SELECT * FROM t WHERE id < 10000000000;
-- ID: -2 NAME: minus two
-- ID: 1 NAME: one
-- ID: 2 NAME: two
-- ID: 3 NAME: three
-- ID: 5 NAME: five

SELECT * FROM t WHERE id = 2e0;
-- ID: 2 NAME: two

SELECT * FROM t WHERE id = CAST(NULL AS INT);

SELECT * FROM t WHERE id > CAST(NULL AS INT) AND id = 2;

-- # A value that fails (1 / 0) isn't used to find the rows, so the WHERE
-- # clause raises the error when it's applied to a row.
SELECT * FROM t WHERE id = 1 / 0;
-- error 22012: division by zero

SELECT * FROM t WHERE id > 1 AND id = 1 / 0;
-- error 22012: division by zero

-- # A value that can't be compared with the column is still an error.
SELECT * FROM t WHERE id = 'one';
-- error 42883: cannot compare INTEGER and CHARACTER(3)

-- # A character string key. Trailing spaces are ignored when comparing, so
-- # 'a  ' finds 'a', and 'a b' is before 'ab' because a space is before 'b'.
-- # A value longer than the column isn't used, like 1.5 for INT.
/* extensions V001-01 */
EXPLAIN SELECT * FROM s WHERE code = 'a';
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.S (CODE CHARACTER VARYING(10) NOT NULL, N INTEGER) RANGE CODE = 'a'
-- EXPLAIN: WHERE CODE = 'a'
-- EXPLAIN: EXPR (":memory:".PUBLIC.S.CODE CHARACTER VARYING(10) NOT NULL, ":memory:".PUBLIC.S.N INTEGER)

SELECT * FROM s WHERE code = 'a';
-- CODE: a N: 1

SELECT * FROM s WHERE code = 'a  ';
-- CODE: a N: 1

SELECT * FROM s WHERE code >= 'a' AND code < 'b';
-- CODE: a N: 1
-- CODE: a b N: 4
-- CODE: ab N: 2

SELECT * FROM s WHERE code > 'a';
-- CODE: a b N: 4
-- CODE: ab N: 2
-- CODE: b N: 3

SELECT * FROM s WHERE code = 'longer than ten';

SELECT * FROM s WHERE code < 'longer than ten';
-- CODE: a N: 1
-- CODE: a b N: 4
-- CODE: ab N: 2
-- CODE: b N: 3

-- # A PRIMARY KEY with more than one column uses = on the first columns, then
-- # a range of the next one. Without a condition on the first column, the
-- # whole table is read, since the key is in the order of that column.
/* extensions V001-01 */
EXPLAIN SELECT * FROM c WHERE a = 2 AND b = 'y';
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.C (A INTEGER NOT NULL, B CHARACTER VARYING(5) NOT NULL, X INTEGER) RANGE A = 2 AND B = 'y'
-- EXPLAIN: WHERE B = 'y'
-- EXPLAIN: EXPR (":memory:".PUBLIC.C.A INTEGER NOT NULL, ":memory:".PUBLIC.C.B CHARACTER VARYING(5) NOT NULL, ":memory:".PUBLIC.C.X INTEGER)

SELECT * FROM c WHERE a = 2 AND b = 'y';
-- A: 2 B: y X: 4

SELECT * FROM c WHERE b = 'x' AND a = 3;
-- A: 3 B: x X: 5

SELECT * FROM c WHERE a = 1 AND b > 'x';
-- A: 1 B: y X: 2

SELECT * FROM c WHERE a = 2;
-- A: 2 B: x X: 3
-- A: 2 B: y X: 4

SELECT * FROM c WHERE a <= 2 AND b = 'x';
-- A: 1 B: x X: 1
-- A: 2 B: x X: 3

SELECT * FROM c WHERE a >= 2;
-- A: 2 B: x X: 3
-- A: 2 B: y X: 4
-- A: 3 B: x X: 5

/* extensions V001-01 */
EXPLAIN SELECT * FROM c WHERE b = 'x';
-- EXPLAIN: TABLE ":memory:".PUBLIC.C (A INTEGER NOT NULL, B CHARACTER VARYING(5) NOT NULL, X INTEGER)
-- EXPLAIN: WHERE B = 'x'
-- EXPLAIN: EXPR (":memory:".PUBLIC.C.A INTEGER NOT NULL, ":memory:".PUBLIC.C.B CHARACTER VARYING(5) NOT NULL, ":memory:".PUBLIC.C.X INTEGER)

-- # A correlation name with new column names.
/* extensions V001-01 */
EXPLAIN SELECT * FROM t AS x (a, b) WHERE a >= 2;
-- EXPLAIN: X:
-- EXPLAIN:   PRIMARY KEY ":memory:".PUBLIC.T (ID INTEGER NOT NULL, NAME CHARACTER VARYING(10)) RANGE A >= 2
-- EXPLAIN: TABLE X (A INTEGER NOT NULL, B CHARACTER VARYING(10))
-- EXPLAIN: EXPR (X.A INTEGER NOT NULL, X.B CHARACTER VARYING(10))

SELECT * FROM t AS x (a, b) WHERE a >= 2 AND b <> 'two';
-- A: 3 B: three
-- A: 5 B: five

-- # DELETE and UPDATE find their rows the same way.
/* extensions V001-02 */
EXPLAIN DELETE FROM t WHERE id >= 3;
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.T (ID INTEGER NOT NULL, NAME CHARACTER VARYING(10)) RANGE ID >= 3

DELETE FROM t WHERE id >= 3;
UPDATE t SET name = 'TWO' WHERE id < 3 AND id > 1;
SELECT * FROM t;
-- msg: DELETE 2
-- msg: UPDATE 1
-- ID: -2 NAME: minus two
-- ID: 1 NAME: one
-- ID: 2 NAME: TWO

-- # A key that ends with the byte 0xff (255 and 511). The end of the range is
-- # the next key, which has to carry into the byte before, so 255 is next to
-- # 256.
CREATE TABLE ff (id INT PRIMARY KEY);
INSERT INTO ff (id) VALUES (254), (255), (256), (511), (512);
SELECT * FROM ff WHERE id <= 255;
SELECT * FROM ff WHERE id = 511;
-- msg: CREATE TABLE 1
-- msg: INSERT 5
-- ID: 254
-- ID: 255
-- ID: 511

-- # Other types of keys. A DATE can't be compared with a TIMESTAMP, 1.505
-- # doesn't fit NUMERIC(5, 2) so it isn't used, -0e0 is equal to 0e0, and
-- # times with a time zone are compared as UTC.
CREATE TABLE d (d DATE PRIMARY KEY);
INSERT INTO d (d) VALUES (DATE '2022-06-30'), (DATE '2022-07-01');
SELECT * FROM d WHERE d > DATE '2022-06-30';
SELECT * FROM d WHERE d = TIMESTAMP '2022-06-30 00:00:00';
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- D: 2022-07-01
-- error 42883: cannot compare DATE and TIMESTAMP(0) WITHOUT TIME ZONE

CREATE TABLE n (n NUMERIC(5, 2) PRIMARY KEY);
INSERT INTO n (n) VALUES (1.5), (2.25);
SELECT * FROM n WHERE n = 1.50;
SELECT * FROM n WHERE n > 1.505;
SELECT * FROM n WHERE n < 2.251;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- N: 1.50
-- N: 2.25
-- N: 1.50
-- N: 2.25

CREATE TABLE f (f DOUBLE PRECISION PRIMARY KEY);
INSERT INTO f (f) VALUES (-1.5e0), (0e0), (2.5e0);
SELECT * FROM f WHERE f >= -0e0;
SELECT * FROM f WHERE f < 1;
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- F: 0e0
-- F: 2.5e0
-- F: -1.5e0
-- F: 0e0

CREATE TABLE b (b BOOLEAN PRIMARY KEY);
INSERT INTO b (b) VALUES (TRUE), (FALSE);
SELECT * FROM b WHERE b = TRUE;
SELECT * FROM b WHERE b < TRUE;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- B: TRUE
-- B: FALSE

CREATE TABLE tz (t TIMESTAMP(0) WITH TIME ZONE PRIMARY KEY);
INSERT INTO tz (t) VALUES (TIMESTAMP '2022-06-30 12:00:00+05:00'), (TIMESTAMP '2022-06-30 12:00:00+00:00');
SELECT * FROM tz WHERE t = TIMESTAMP '2022-06-30 07:00:00+00:00';
SELECT * FROM tz WHERE t > TIMESTAMP '2022-06-30 10:00:00+02:00';
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- T: 2022-06-30T12:00:00+0500
-- T: 2022-06-30T12:00:00+0000
