-- # ilike isn't a reserved word, so it's still a name wherever a name can be,
-- # including an alias without AS.
/* setup */
CREATE TABLE ilike (ilike VARCHAR(10));
INSERT INTO ilike (ilike) VALUES ('Ab');
CREATE TABLE t (x VARCHAR(10), y INT, z BOOLEAN);
INSERT INTO t (x, y, z) VALUES ('Ab', 2, FALSE);
CREATE TABLE n (ilike INT, b BOOLEAN);
INSERT INTO n (ilike, b) VALUES (2, TRUE);
CREATE TABLE p (id INT PRIMARY KEY);
CREATE TABLE operator_ilike (literal_string INT);
INSERT INTO operator_ilike (literal_string) VALUES (1);

/* flags */
SELECT ilike FROM ilike;
-- flags:
-- ILIKE: Ab

SELECT ilike.ilike FROM ilike;
-- ILIKE: Ab

SELECT ILIKE FROM PUBLIC.ILIKE;
-- ILIKE: Ab

SELECT "ILIKE" FROM ilike;
-- ILIKE: Ab

SELECT ilike AS ilike FROM ilike;
-- ILIKE: Ab

-- # An alias without AS, because what follows it can't start a pattern.
/* flags */
SELECT x ilike FROM t;
-- flags:
-- ILIKE: Ab

SELECT x ilike, y FROM t;
-- ILIKE: Ab Y: 2

SELECT y, x ilike FROM t;
-- Y: 2 ILIKE: Ab

SELECT (x) ilike FROM t;
-- ILIKE: Ab

SELECT x ilike FROM t ORDER BY x;
-- ILIKE: Ab

SELECT x ilike FROM t UNION ALL SELECT x FROM t;
-- ILIKE: Ab
-- ILIKE: Ab

SELECT x FROM t ilike;
-- X: Ab

SELECT ilike.x FROM t ilike;
-- X: Ab

SELECT ilike.x FROM t AS ilike;
-- X: Ab

SELECT ilike.a FROM t ilike (a, b, c);
-- A: Ab

SELECT ilike.a FROM (SELECT x FROM t) ilike (a);
-- A: Ab

SELECT ilike.a FROM t AS ilike (a, b, c);
-- A: Ab

SELECT x FROM t ilike WHERE y = 2;
-- X: Ab

SELECT ilike.x FROM t ilike INNER JOIN t u ON ilike.x = u.x;
-- X: Ab

-- # A column named ilike in an expression and in each kind of statement.
SELECT * FROM ilike WHERE ilike = 'Ab';
-- ILIKE: Ab

SELECT ilike || 'c' FROM ilike;
-- COL1: Abc

SELECT y ilike FROM t WHERE y + 1 = 3;
-- ILIKE: 2

INSERT INTO ilike (ilike) VALUES ('c');
-- msg: INSERT 1

UPDATE ilike SET ilike = 'c';
-- msg: UPDATE 1

DELETE FROM ilike WHERE ilike = 'Ab';
-- msg: DELETE 1

DROP TABLE ilike RESTRICT;
-- msg: DROP TABLE 1

SELECT ilike + 1 FROM n;
-- COL1: 3

SELECT ilike - 1 FROM n;
-- COL1: 1

SELECT 1 + ilike - 1 FROM n;
-- COL1: 2

SELECT CASE WHEN ilike = 2 THEN ilike + 1 END FROM n;
-- COL1: 3

SELECT b FROM n WHERE NOT ilike = 3;
-- B: TRUE

SELECT b FROM n WHERE b AND NOT ilike + 1 = 2;
-- B: TRUE

-- # A column, a constraint, a sequence and a schema named ilike. The foreign
-- # key fails only because the column isn't a PRIMARY KEY or UNIQUE.
ALTER TABLE n ADD ilike2 INT;
-- msg: ALTER TABLE 1

ALTER TABLE n DROP COLUMN ilike RESTRICT;
-- msg: ALTER TABLE 1

CREATE TABLE q (id INT, CONSTRAINT ilike PRIMARY KEY (id));
-- msg: CREATE TABLE 1

CREATE TABLE r (a VARCHAR(10) REFERENCES ilike (ilike));
-- error 42830: invalid foreign key: there is no PRIMARY KEY or UNIQUE (ILIKE) on ":memory:".PUBLIC.ILIKE

ALTER TABLE p ADD ilike INT;
ALTER TABLE p DROP COLUMN ilike RESTRICT;
ALTER TABLE p ADD ilike DATE;
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1

CREATE SEQUENCE ilike;
SELECT NEXT VALUE FOR ilike FROM t;
DROP SEQUENCE ilike RESTRICT;
-- msg: CREATE SEQUENCE 1
-- COL1: 1
-- msg: DROP SEQUENCE 1

CREATE SCHEMA ilike;
DROP SCHEMA ilike RESTRICT;
-- msg: CREATE SCHEMA 1
-- msg: DROP SCHEMA 1

-- # A column named SEQUENCE (or ADD, CONNECTION, CONSTRAINTS or SCHEMA) needs
-- # quotes on the left of ILIKE, since those words can be before a name.
/* extensions V302-01 */
SELECT "SEQUENCE" ILIKE 'a' FROM (SELECT x FROM t) u ("SEQUENCE");
-- COL1: FALSE

-- # The name of the token of the operator isn't a word.
SELECT literal_string FROM operator_ilike;
-- LITERAL_STRING: 1

-- # The operator and the name in the same statement.
/* extensions V302-01 */
/* flags */
SELECT ilike FROM ilike WHERE ilike ILIKE 'AB';
-- flags: V302-01
-- ILIKE: Ab

/* extensions V302-01 */
SELECT ilike ILIKE ilike FROM ilike;
-- COL1: TRUE

/* extensions V302-01 */
SELECT ilike NOT ILIKE ilike FROM ilike;
-- COL1: FALSE

/* extensions V302-01 */
SELECT ilike ILIKE 'ab' ilike FROM ilike;
-- ILIKE: TRUE

/* extensions V302-01 */
SELECT ilike.ilike ILIKE ilike.ilike FROM ilike;
-- COL1: TRUE

-- # A syntax error names the operator.
DROP TABLE t ILIKE 'a';
-- error 42601: syntax error: unexpected ILIKE
