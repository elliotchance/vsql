VALUES TIMESTAMP '2022-06-30 21:47:32';
-- COL1: 2022-06-30T21:47:32

VALUES TIMESTAMP '2022-06-30 21:47:32+05:12';
-- COL1: 2022-06-30T21:47:32+0512

VALUES TIMESTAMP '21:47:32';
-- error 42601: syntax error: TIMESTAMP '21:47:32' is not valid

VALUES TIMESTAMP '21:47:32+05:12';
-- error 42601: syntax error: TIMESTAMP '21:47:32+05:12' is not valid

VALUES TIMESTAMP '2022-06-30 21:47:32-11:30';
-- COL1: 2022-06-30T21:47:32-1130

VALUES TIMESTAMP '2022-06-30 00:00:00';
-- COL1: 2022-06-30T00:00:00

VALUES TIMESTAMP '2022-06-30 21:47:32.123';
-- COL1: 2022-06-30T21:47:32.123

VALUES TIMESTAMP '2022-06-30 21:47:32.456000+05:12';
-- COL1: 2022-06-30T21:47:32.456000+0512

VALUES TIMESTAMP '2022-06-30T21:47:32';
-- error 42601: syntax error: TIMESTAMP '2022-06-30T21:47:32' is not valid

VALUES TIMESTAMP 'a2022-06-30 21:47:32';
-- error 42601: syntax error: TIMESTAMP 'a2022-06-30 21:47:32' is not valid

VALUES TIMESTAMP '2022-06-30 21:47:32a';
-- error 42601: syntax error: TIMESTAMP '2022-06-30 21:47:32a' is not valid

VALUES TIMESTAMP '2022-06-30';
-- error 42601: syntax error: TIMESTAMP '2022-06-30' is not valid

VALUES TIMESTAMP '21:47:32';
-- error 42601: syntax error: TIMESTAMP '21:47:32' is not valid

VALUES TIMESTAMP 'FOO BAR';
-- error 42601: syntax error: TIMESTAMP 'FOO BAR' is not valid

VALUES TIMESTAMP '2022-06-30 21:47:75';
-- COL1: 2022-06-30T21:48:15

VALUES TIMESTAMP '10000-06-30T21:47:32';
-- error 42601: syntax error: TIMESTAMP '10000-06-30T21:47:32' is not valid

VALUES TIMESTAMP '-1-06-30T21:47:32';
-- error 42601: syntax error: TIMESTAMP '-1-06-30T21:47:32' is not valid

VALUES TIMESTAMP '2022-06-30 21:47:32+12:00';
-- error 42601: syntax error: TIMESTAMP '2022-06-30 21:47:32+12:00' is not valid

VALUES TIMESTAMP '2022-06-30 21:47:32-12:00';
-- error 42601: syntax error: TIMESTAMP '2022-06-30 21:47:32-12:00' is not valid

CREATE TABLE foo (f1 TIMESTAMP WITHOUT TIME ZONE);
INSERT INTO foo (f1) VALUES (TIMESTAMP '2022-06-30 21:47:32');
INSERT INTO foo (f1) VALUES (TIMESTAMP '2022-06-30 01:47:32+05:12');
INSERT INTO foo (f1) VALUES (TIMESTAMP '2022-06-30 21:47:32.123');
INSERT INTO foo (f1) VALUES (TIMESTAMP '2022-06-30 01:47:32.123456+05:12');
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 42804: data type mismatch for column F1: expected TIMESTAMP(6) WITHOUT TIME ZONE but got TIMESTAMP(0) WITH TIME ZONE
-- msg: INSERT 1
-- error 42804: data type mismatch for column F1: expected TIMESTAMP(6) WITHOUT TIME ZONE but got TIMESTAMP(6) WITH TIME ZONE
-- F1: 2022-06-30T21:47:32.000000
-- F1: 2022-06-30T21:47:32.123000

CREATE TABLE foo (f1 TIMESTAMP WITH TIME ZONE);
INSERT INTO foo (f1) VALUES (TIMESTAMP '2022-06-30 21:47:32');
INSERT INTO foo (f1) VALUES (TIMESTAMP '2022-06-30 01:47:32+05:12');
INSERT INTO foo (f1) VALUES (TIMESTAMP '2022-06-30 21:47:32.123');
INSERT INTO foo (f1) VALUES (TIMESTAMP '2022-06-30 01:47:32.123456+05:12');
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- error 42804: data type mismatch for column F1: expected TIMESTAMP(6) WITH TIME ZONE but got TIMESTAMP(0) WITHOUT TIME ZONE
-- msg: INSERT 1
-- error 42804: data type mismatch for column F1: expected TIMESTAMP(6) WITH TIME ZONE but got TIMESTAMP(3) WITHOUT TIME ZONE
-- msg: INSERT 1
-- F1: 2022-06-30T01:47:32.000000+0512
-- F1: 2022-06-30T01:47:32.123456+0512

CREATE TABLE foo (f1 TIMESTAMP (3) WITHOUT TIME ZONE);
INSERT INTO foo (f1) VALUES (TIMESTAMP '2022-06-30 21:47:32');
INSERT INTO foo (f1) VALUES (TIMESTAMP '2022-06-30 01:47:32+05:12');
INSERT INTO foo (f1) VALUES (TIMESTAMP '2022-06-30 21:47:32.123');
INSERT INTO foo (f1) VALUES (TIMESTAMP '2022-06-30 01:47:32.123456+05:12');
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 42804: data type mismatch for column F1: expected TIMESTAMP(3) WITHOUT TIME ZONE but got TIMESTAMP(0) WITH TIME ZONE
-- msg: INSERT 1
-- error 42804: data type mismatch for column F1: expected TIMESTAMP(3) WITHOUT TIME ZONE but got TIMESTAMP(6) WITH TIME ZONE
-- F1: 2022-06-30T21:47:32.000
-- F1: 2022-06-30T21:47:32.123

CREATE TABLE foo (f1 TIMESTAMP (3) WITH TIME ZONE);
INSERT INTO foo (f1) VALUES (TIMESTAMP '2022-06-30 21:47:32');
INSERT INTO foo (f1) VALUES (TIMESTAMP '2022-06-30 01:47:32+05:12');
INSERT INTO foo (f1) VALUES (TIMESTAMP '2022-06-30 21:47:32.123');
INSERT INTO foo (f1) VALUES (TIMESTAMP '2022-06-30 01:47:32.123456+05:12');
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- error 42804: data type mismatch for column F1: expected TIMESTAMP(3) WITH TIME ZONE but got TIMESTAMP(0) WITHOUT TIME ZONE
-- msg: INSERT 1
-- error 42804: data type mismatch for column F1: expected TIMESTAMP(3) WITH TIME ZONE but got TIMESTAMP(3) WITHOUT TIME ZONE
-- error 42804: data type mismatch for column F1: expected TIMESTAMP(3) WITH TIME ZONE but got TIMESTAMP(6) WITH TIME ZONE
-- F1: 2022-06-30T01:47:32.000+0512
