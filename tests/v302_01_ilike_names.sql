-- # ilike isn't a reserved word, so it's still a name wherever a name can be,
-- # including an alias without AS.
/* setup */
CREATE TABLE ilike (ilike VARCHAR(10));
INSERT INTO ilike (ilike) VALUES ('Ab');
CREATE TABLE n (ilike INT, b BOOLEAN);
INSERT INTO n (ilike, b) VALUES (2, TRUE);

/* define t */
CREATE TABLE t (x VARCHAR(10), y INT, z BOOLEAN);
INSERT INTO t (x, y, z) VALUES ('Ab', 2, FALSE);

/* define operator_ilike */
CREATE TABLE operator_ilike (literal_string INT);
INSERT INTO operator_ilike (literal_string) VALUES (1);

/* flags */
SELECT ilike FROM ilike;
-- flags:
-- ILIKE: Ab

SELECT ilike.ilike FROM ilike;
SELECT ILIKE FROM PUBLIC.ILIKE;
SELECT "ILIKE" FROM ilike;
SELECT ilike AS ilike FROM ilike;
-- ILIKE: Ab
-- ILIKE: Ab
-- ILIKE: Ab
-- ILIKE: Ab

-- # An alias without AS, because what follows it can't start a pattern.
/* include t */
/* flags */
SELECT x ilike FROM t;
-- flags:
-- ILIKE: Ab

/* include t */
SELECT x ilike, y FROM t;
SELECT y, x ilike FROM t;
SELECT (x) ilike FROM t;
SELECT x ilike FROM t ORDER BY x;
-- ILIKE: Ab Y: 2
-- Y: 2 ILIKE: Ab
-- ILIKE: Ab
-- ILIKE: Ab

/* include t */
SELECT x ilike FROM t UNION ALL SELECT x FROM t;
-- ILIKE: Ab
-- ILIKE: Ab

/* include t */
SELECT x FROM t ilike;
SELECT ilike.x FROM t ilike;
SELECT ilike.x FROM t AS ilike;
SELECT ilike.a FROM t ilike (a, b, c);
SELECT ilike.a FROM (SELECT x FROM t) ilike (a);
SELECT ilike.a FROM t AS ilike (a, b, c);
SELECT x FROM t ilike WHERE y = 2;
SELECT ilike.x FROM t ilike INNER JOIN t u ON ilike.x = u.x;
-- X: Ab
-- X: Ab
-- X: Ab
-- A: Ab
-- A: Ab
-- A: Ab
-- X: Ab
-- X: Ab

-- # A column named ilike in an expression and in each kind of statement.
SELECT * FROM ilike WHERE ilike = 'Ab';
SELECT ilike || 'c' FROM ilike;
-- ILIKE: Ab
-- COL1: Abc

/* include t */
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
SELECT ilike - 1 FROM n;
SELECT 1 + ilike - 1 FROM n;
SELECT CASE WHEN ilike = 2 THEN ilike + 1 END FROM n;
SELECT b FROM n WHERE NOT ilike = 3;
SELECT b FROM n WHERE b AND NOT ilike + 1 = 2;
-- COL1: 3
-- COL1: 1
-- COL1: 2
-- COL1: 3
-- B: TRUE
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

CREATE TABLE p (id INT PRIMARY KEY);
ALTER TABLE p ADD ilike INT;
ALTER TABLE p DROP COLUMN ilike RESTRICT;
ALTER TABLE p ADD ilike DATE;
-- msg: CREATE TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1

/* include t */
CREATE SEQUENCE ilike;
SELECT NEXT VALUE FOR ilike FROM t;
DROP SEQUENCE ilike RESTRICT;
-- msg: CREATE SEQUENCE 1
-- COL1: 1
-- msg: DROP SEQUENCE 1

/* include t */
CREATE TABLE p (id INT PRIMARY KEY);
/* include operator_ilike */
CREATE SCHEMA ilike;
DROP SCHEMA ilike RESTRICT;
-- msg: CREATE TABLE 1
-- msg: CREATE SCHEMA 1
-- msg: DROP SCHEMA 1

-- # A column named SEQUENCE (or ADD, CONNECTION, CONSTRAINTS or SCHEMA) needs
-- # quotes on the left of ILIKE, since those words can be before a name.
/* include t */
/* extensions V302-01 */
SELECT "SEQUENCE" ILIKE 'a' FROM (SELECT x FROM t) u ("SEQUENCE");
-- COL1: FALSE

-- # The name of the token of the operator isn't a word.
/* include operator_ilike */
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
/* include t */
DROP TABLE t ILIKE 'a';
-- error 42601: syntax error: unexpected ILIKE at line 1, column 14 near "DROP TABLE t ILIKE 'a'"
