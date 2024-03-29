CREATE TABLE foo (x CHARACTER(8));
INSERT INTO foo (x) VALUES ('hello');
SELECT x, CHARACTER_LENGTH(CAST(x AS VARCHAR(10))) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- X: hello    COL2: 8

CREATE TABLE foo (x CHARACTER(8));
INSERT INTO foo (x) VALUES ('hello');
SELECT CAST(x AS VARCHAR(10)), CHARACTER_LENGTH(CAST(x AS VARCHAR(10))) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: hello    COL2: 8

CREATE TABLE foo (x CHARACTER(8));
INSERT INTO foo (x) VALUES ('hello');
SELECT CAST(x AS VARCHAR(4)) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 22001: string data right truncation for CHARACTER VARYING(4)

CREATE TABLE foo (x CHARACTER(8));
INSERT INTO foo (x) VALUES ('hello');
SELECT CAST(x AS CHAR(10)), CHARACTER_LENGTH(CAST(x AS CHAR(10))) FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: hello      COL2: 10
