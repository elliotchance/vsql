VALUES TIME '2022-06-30 21:47:32';
-- error 42601: syntax error: TIME '2022-06-30 21:47:32' is not valid

VALUES TIME '2022-06-30 21:47:32+05:12';
-- error 42601: syntax error: TIME '2022-06-30 21:47:32+05:12' is not valid

VALUES TIME '21:47:32';
-- COL1: 21:47:32

VALUES TIME 'a21:47:32';
-- error 42601: syntax error: TIME 'a21:47:32' is not valid

VALUES TIME '21:47:32T';
-- error 42601: syntax error: TIME '21:47:32T' is not valid

VALUES TIME '21:47:32+05:12';
-- COL1: 21:47:32+0512

VALUES TIME '21:47:32-11:30';
-- COL1: 21:47:32-1130

VALUES TIME '21:47:32.123+05:12';
-- COL1: 21:47:32.123+0512

VALUES TIME '2022-06-30 21:47:32-11:30';
-- error 42601: syntax error: TIME '2022-06-30 21:47:32-11:30' is not valid

VALUES TIME '2022-06-30 00:00:00';
-- error 42601: syntax error: TIME '2022-06-30 00:00:00' is not valid

VALUES TIME '2022-06-30 21:47:32.123';
-- error 42601: syntax error: TIME '2022-06-30 21:47:32.123' is not valid

VALUES TIME '2022-06-30 21:47:32.456000+05:12';
-- error 42601: syntax error: TIME '2022-06-30 21:47:32.456000+05:12' is not valid

VALUES TIME '2022-06-30T21:47:32';
-- error 42601: syntax error: TIME '2022-06-30T21:47:32' is not valid

VALUES TIME 'a2022-06-30 21:47:32';
-- error 42601: syntax error: TIME 'a2022-06-30 21:47:32' is not valid

VALUES TIME '2022-06-30 21:47:32a';
-- error 42601: syntax error: TIME '2022-06-30 21:47:32a' is not valid

VALUES TIME '2022-06-30';
-- error 42601: syntax error: TIME '2022-06-30' is not valid

VALUES TIME '21:47:32';
-- COL1: 21:47:32

VALUES TIME 'FOO BAR';
-- error 42601: syntax error: TIME 'FOO BAR' is not valid

VALUES TIME '2022-06-30 21:47:75';
-- error 42601: syntax error: TIME '2022-06-30 21:47:75' is not valid

VALUES TIME '10000-06-30T21:47:32';
-- error 42601: syntax error: TIME '10000-06-30T21:47:32' is not valid

VALUES TIME '-1-06-30T21:47:32';
-- error 42601: syntax error: TIME '-1-06-30T21:47:32' is not valid

VALUES TIME '2022-06-30 21:47:32+12:00';
-- error 42601: syntax error: TIME '2022-06-30 21:47:32+12:00' is not valid

VALUES TIME '2022-06-30 21:47:32-12:00';
-- error 42601: syntax error: TIME '2022-06-30 21:47:32-12:00' is not valid

CREATE TABLE foo (f1 TIME WITHOUT TIME ZONE);
INSERT INTO foo (f1) VALUES (TIME '21:47:32');
INSERT INTO foo (f1) VALUES (TIME '01:47:32+05:12');
INSERT INTO foo (f1) VALUES (TIME '21:47:32.123');
INSERT INTO foo (f1) VALUES (TIME '01:47:32.123456+05:12');
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 42804: data type mismatch for column F1: expected TIME(0) WITHOUT TIME ZONE but got TIME(0) WITH TIME ZONE
-- msg: INSERT 1
-- error 42804: data type mismatch for column F1: expected TIME(0) WITHOUT TIME ZONE but got TIME(6) WITH TIME ZONE
-- F1: 21:47:32
-- F1: 21:47:32

CREATE TABLE foo (f1 TIME WITH TIME ZONE);
INSERT INTO foo (f1) VALUES (TIME '21:47:32');
INSERT INTO foo (f1) VALUES (TIME '01:47:32+05:12');
INSERT INTO foo (f1) VALUES (TIME '21:47:32.123');
INSERT INTO foo (f1) VALUES (TIME '01:47:32.123456+05:12');
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- error 42804: data type mismatch for column F1: expected TIME(0) WITH TIME ZONE but got TIME(0) WITHOUT TIME ZONE
-- msg: INSERT 1
-- error 42804: data type mismatch for column F1: expected TIME(0) WITH TIME ZONE but got TIME(3) WITHOUT TIME ZONE
-- msg: INSERT 1
-- F1: 01:47:32+0512
-- F1: 01:47:32+0512

CREATE TABLE foo (f1 TIME (3) WITHOUT TIME ZONE);
INSERT INTO foo (f1) VALUES (TIME '21:47:32');
INSERT INTO foo (f1) VALUES (TIME '01:47:32+05:12');
INSERT INTO foo (f1) VALUES (TIME '21:47:32.123');
INSERT INTO foo (f1) VALUES (TIME '01:47:32.123456+05:12');
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 42804: data type mismatch for column F1: expected TIME(3) WITHOUT TIME ZONE but got TIME(0) WITH TIME ZONE
-- msg: INSERT 1
-- error 42804: data type mismatch for column F1: expected TIME(3) WITHOUT TIME ZONE but got TIME(6) WITH TIME ZONE
-- F1: 21:47:32.000
-- F1: 21:47:32.123

CREATE TABLE foo (f1 TIME (3) WITH TIME ZONE);
INSERT INTO foo (f1) VALUES (TIME '21:47:32');
INSERT INTO foo (f1) VALUES (TIME '01:47:32+05:12');
INSERT INTO foo (f1) VALUES (TIME '21:47:32.123');
INSERT INTO foo (f1) VALUES (TIME '01:47:32.123456+05:12');
SELECT * FROM foo;
-- msg: CREATE TABLE 1
-- error 42804: data type mismatch for column F1: expected TIME(3) WITH TIME ZONE but got TIME(0) WITHOUT TIME ZONE
-- msg: INSERT 1
-- error 42804: data type mismatch for column F1: expected TIME(3) WITH TIME ZONE but got TIME(3) WITHOUT TIME ZONE
-- msg: INSERT 1
-- F1: 01:47:32.000+0512
-- F1: 01:47:32.123456+0512
