-- # A concatenation is a CHARACTER LARGE OBJECT when either operand is, with
-- # the combined length, or the maximum length when either one has it (6.32,
-- # Syntax Rules, 3.b.i).
/* types */
CREATE TABLE t (a CLOB(5), b CLOB, c VARCHAR(3), d CHAR(2));
INSERT INTO t VALUES ('ab', 'cd', 'ef', 'g');
SELECT a || a, a || c, d || a, a || b, c || b FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: abab (CHARACTER LARGE OBJECT(10)) COL2: abef (CHARACTER LARGE OBJECT(8)) COL3: g ab (CHARACTER LARGE OBJECT(7)) COL4: abcd (CHARACTER LARGE OBJECT) COL5: efcd (CHARACTER LARGE OBJECT)

-- # The result is NULL if either is NULL (6.32, General Rules, 2.b.i).
/* types */
CREATE TABLE t (a CLOB(5));
INSERT INTO t VALUES (NULL);
SELECT a || 'x' FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: NULL (CHARACTER LARGE OBJECT(6))

-- # A CHARACTER LARGE OBJECT can be longer than a CHARACTER VARYING.
CREATE TABLE t (a CLOB);
INSERT INTO t SELECT CAST(x AS CLOB) || x FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (VALUES CAST('xxxxxxxxxx' AS VARCHAR(10))) AS t0 (a)) AS t1 (a)) AS t2 (a)) AS t3 (a)) AS t4 (a)) AS s (x);
SELECT CHAR_LENGTH(a), SUBSTRING(a FROM 20971519) FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 20971520 COL2: xx

-- # A concatenation whose type is a CHARACTER LARGE OBJECT is Feature T040.
/* flags */
VALUES CAST('a' AS CLOB) || 'b';
-- flags: F641, F661, T040, T046
-- COL1: ab
