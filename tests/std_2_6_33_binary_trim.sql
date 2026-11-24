-- # A <binary trim function> removes X'00' octets without a trim octet (6.33,
-- # Syntax Rules, 22.a.i.3 and 22.a.ii). Its type is a BINARY VARYING with the
-- # length of the source, or a BINARY LARGE OBJECT of the same maximum length
-- # for one (6.33, Syntax Rules, 22.b).
/* types */
VALUES TRIM(X'0000010200');
-- COL1: 0102 (BINARY VARYING(5))

/* types */
VALUES TRIM(LEADING FROM X'0000010200');
-- COL1: 010200 (BINARY VARYING(5))

/* types */
VALUES TRIM(TRAILING FROM X'0000010200');
-- COL1: 00000102 (BINARY VARYING(5))

/* types */
VALUES TRIM(BOTH X'01' FROM X'0101020101');
-- COL1: 02 (BINARY VARYING(5))

/* types */
VALUES TRIM(X'01' FROM X'0101');
-- COL1:  (BINARY VARYING(2))

/* types */
CREATE TABLE t (a BINARY(4), b BLOB(8), c BLOB);
INSERT INTO t VALUES (X'0102', X'00FF00', X'FF');
SELECT TRIM(a), TRIM(b), TRIM(X'FF' FROM c) FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 0102 (BINARY VARYING(4)) COL2: FF (BINARY LARGE OBJECT(8)) COL3:  (BINARY LARGE OBJECT)

-- # The trim octet must be one octet (6.33, General Rules, 18.d).
VALUES TRIM(X'0102' FROM X'0102');
-- error 22027: trim error

VALUES TRIM(X'' FROM X'0102');
-- error 22027: trim error

-- # The result is NULL if either is NULL (6.33, General Rules, 18.c).
/* types */
CREATE TABLE t (a VARBINARY(3));
INSERT INTO t VALUES (NULL);
SELECT TRIM(a), TRIM(a FROM X'01') FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: NULL (BINARY VARYING(3)) COL2: NULL (BINARY VARYING(1))

-- # The trim octet and the source must both be binary strings.
VALUES TRIM('a' FROM X'01');
-- error 42883: function does not exist: TRIM(CHARACTER(1) FROM BINARY(1))

VALUES TRIM(X'01' FROM 'a');
-- error 42883: function does not exist: TRIM(BINARY(1) FROM CHARACTER(1))

/* extensions V001-01 */
EXPLAIN SELECT * FROM (VALUES ROW(1)) AS t (x) WHERE TRIM(X'0102') IS NOT NULL AND TRIM(LEADING X'01' FROM X'0102') IS NOT NULL;
-- EXPLAIN: T:
-- EXPLAIN:   VALUES (X SMALLINT) = ROW(1)
-- EXPLAIN: TABLE T (X SMALLINT)
-- EXPLAIN: WHERE TRIM(BOTH FROM X'0102') IS NOT NULL AND TRIM(LEADING X'01' FROM X'0102') IS NOT NULL
-- EXPLAIN: EXPR (T.X SMALLINT)

-- # A <binary trim function> is a <binary value function> (Feature T022), and
-- # it's also Feature T047 for a BINARY LARGE OBJECT.
/* flags */
VALUES TRIM(X'0001');
-- flags: F641, F661, T021, T022
-- COL1: 01

/* flags */
VALUES TRIM(CAST(X'0001' AS BLOB));
-- flags: F641, F661, T021, T022, T045, T047
-- COL1: 01
