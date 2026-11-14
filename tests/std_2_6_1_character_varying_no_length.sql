-- # A CHARACTER VARYING without a length has the implementation-defined
-- # maximum length (T081, Syntax Rules, 7 and Conformance Rules, 22), which
-- # is 10485760.
/* types */
/* flags */
CREATE TABLE t (a VARCHAR, b CHARACTER VARYING, c CHAR VARYING);
INSERT INTO t (a, b, c) VALUES ('hello', 'world', '!');
SELECT * FROM t;
SELECT column_name, character_maximum_length FROM information_schema.columns WHERE table_name = 'T';
-- flags: T081
-- msg: CREATE TABLE 1
-- flags:
-- msg: INSERT 1
-- flags:
-- A: hello (CHARACTER VARYING(10485760)) B: world (CHARACTER VARYING(10485760)) C: ! (CHARACTER VARYING(10485760))
-- flags: F391
-- COLUMN_NAME: A (CHARACTER VARYING(128)) CHARACTER_MAXIMUM_LENGTH: 10485760 (INTEGER)
-- COLUMN_NAME: B (CHARACTER VARYING(128)) CHARACTER_MAXIMUM_LENGTH: 10485760 (INTEGER)
-- COLUMN_NAME: C (CHARACTER VARYING(128)) CHARACTER_MAXIMUM_LENGTH: 10485760 (INTEGER)

/* types */
/* flags */
VALUES CAST(123 AS VARCHAR);
-- flags: F641, F661, T081
-- COL1: 123 (CHARACTER VARYING(10485760))
