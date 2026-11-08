-- # A timestamp literal without a time zone is a TIMESTAMP WITHOUT TIME ZONE
-- # whose precision is the number of fractional digits (Syntax Rules, 27).
/* types */
VALUES TIMESTAMP '2022-06-30 21:47:32.123456';
-- COL1: 2022-06-30T21:47:32.123456 (TIMESTAMP(6) WITHOUT TIME ZONE)

-- # vsql's TIMESTAMP can't be more precise than 6 (6.1, Syntax Rules, 38), so a
-- # seventh digit is an error. A period must also have digits after it.
VALUES TIMESTAMP '2022-06-30 21:47:32.1234567';
-- error 42601: syntax error: TIMESTAMP '2022-06-30 21:47:32.1234567' is not valid

VALUES TIMESTAMP '2022-06-30 21:47:32.';
-- error 42601: syntax error: TIMESTAMP '2022-06-30 21:47:32.' is not valid

VALUES TIMESTAMP '2022-06-30 21:47:32.+05:12';
-- error 42601: syntax error: TIMESTAMP '2022-06-30 21:47:32.+05:12' is not valid

-- # The date and time are separated by exactly one space, every field but the
-- # year has two digits (Syntax Rules, 31), and a time zone is a sign then
-- # hours:minutes.
VALUES TIMESTAMP '2022-06-30  21:47:32';
-- error 42601: syntax error: TIMESTAMP '2022-06-30  21:47:32' is not valid

VALUES TIMESTAMP '2022-06-30 21:47:32+0512';
-- error 42601: syntax error: TIMESTAMP '2022-06-30 21:47:32+0512' is not valid

VALUES TIMESTAMP '2022-06-30 21:47:32 05:12';
-- error 42601: syntax error: TIMESTAMP '2022-06-30 21:47:32 05:12' is not valid

VALUES TIMESTAMP '2022-6-30 21:47:32';
-- error 42601: syntax error: TIMESTAMP '2022-6-30 21:47:32' is not valid

VALUES TIMESTAMP '2022-06-30 21:47:3x';
-- error 42601: syntax error: TIMESTAMP '2022-06-30 21:47:3x' is not valid
