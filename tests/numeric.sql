CREATE TABLE foo (bar NUMERIC);
INSERT INTO foo (bar) VALUES ('hello');
-- msg: CREATE TABLE 1
-- error 42804: data type mismatch for column BAR: expected NUMERIC but got CHARACTER VARYING

CREATE TABLE foo (bar NUMERIC(10));
INSERT INTO foo (bar) VALUES ('hello');
-- msg: CREATE TABLE 1
-- error 42804: data type mismatch for column BAR: expected NUMERIC(10) but got CHARACTER VARYING

CREATE TABLE foo (bar NUMERIC(10, 2));
INSERT INTO foo (bar) VALUES ('hello');
-- msg: CREATE TABLE 1
-- error 42804: data type mismatch for column BAR: expected NUMERIC(10, 2) but got CHARACTER VARYING

CREATE TABLE foo (bar NUMERIC);
INSERT INTO foo (bar) VALUES (123);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- BAR: 123

CREATE TABLE foo (bar NUMERIC);
INSERT INTO foo (bar) VALUES (1.23);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- BAR: 1.23

CREATE TABLE foo (bar NUMERIC);
INSERT INTO foo (bar) VALUES (-123);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- BAR: -123

CREATE TABLE foo (bar NUMERIC);
INSERT INTO foo (bar) VALUES (-1.23);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- BAR: -1.23

CREATE TABLE foo (bar NUMERIC);
INSERT INTO foo (bar) VALUES (+123);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- BAR: 123

CREATE TABLE foo (bar NUMERIC);
INSERT INTO foo (bar) VALUES (+1.23);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- BAR: 1.23

CREATE TABLE foo (bar NUMERIC(3));
INSERT INTO foo (bar) VALUES (1234);
-- msg: CREATE TABLE 1
-- error 22003: numeric overflow: a field with precision 3, scale 0 must round to an absolute value less than 10^3

CREATE TABLE foo (bar NUMERIC(3));
INSERT INTO foo (bar) VALUES (12.34);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- BAR: 12

CREATE TABLE foo (bar NUMERIC(3, 1));
INSERT INTO foo (bar) VALUES (12.34);
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- BAR: 12.3

CREATE TABLE foo (bar NUMERIC(11, 10));
INSERT INTO foo (bar) VALUES (12.34);
-- msg: CREATE TABLE 1
-- error 22003: numeric overflow: a field with precision 11, scale 10 must round to an absolute value less than 10^11
