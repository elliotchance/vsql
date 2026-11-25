-- # FORMAT_SIZE and PARSE_SIZE are vsql extensions (V410-01 and V410-02) that
-- # format a number of bytes as a size, such as 23 MiB, and parse it back.

-- # Without a unit, FORMAT_SIZE uses the largest decimal unit that isn't more
-- # than the bytes. The significant figures (0 by default rounds to a whole
-- # number) don't have zeros at the end, and never round the whole number.
SELECT x, FORMAT_SIZE(x), FORMAT_SIZE(x, 3) FROM (VALUES (0), (512), (999), (1000), (1500), (999000), (999999), (1234567), (12345678), (24117248), (123456789), (1234567890), (-24117248), (-1)) AS t (x);
-- X: 0 COL2: 0 B COL3: 0 B
-- X: 512 COL2: 512 B COL3: 512 B
-- X: 999 COL2: 999 B COL3: 999 B
-- X: 1000 COL2: 1 kB COL3: 1 kB
-- X: 1500 COL2: 2 kB COL3: 1.5 kB
-- X: 999000 COL2: 999 kB COL3: 999 kB
-- X: 999999 COL2: 1 MB COL3: 1 MB
-- X: 1234567 COL2: 1 MB COL3: 1.23 MB
-- X: 12345678 COL2: 12 MB COL3: 12.3 MB
-- X: 24117248 COL2: 24 MB COL3: 24.1 MB
-- X: 123456789 COL2: 123 MB COL3: 123 MB
-- X: 1234567890 COL2: 1 GB COL3: 1.23 GB
-- X: -24117248 COL2: -24 MB COL3: -24.1 MB
-- X: -1 COL2: -1 B COL3: -1 B

-- # The largest BIGINT, and a NUMERIC with a fraction (rounded to whole bytes)
-- # or more than a BIGINT, which stays in YB.
/* types */
VALUES ROW(FORMAT_SIZE(9223372036854775807), FORMAT_SIZE(9223372036854775807, 3));
VALUES ROW(FORMAT_SIZE(1499.5), FORMAT_SIZE(1499.4, 4), FORMAT_SIZE(CAST(0.4 AS DECIMAL(3, 1))), FORMAT_SIZE(-0.4));
VALUES ROW(FORMAT_SIZE(1000000000000000000000000), FORMAT_SIZE(1000000000000000000000000000, 2), FORMAT_SIZE(1000000000000000000000000000000));
-- COL1: 9 EB (CHARACTER VARYING) COL2: 9.22 EB (CHARACTER VARYING)
-- COL1: 2 kB (CHARACTER VARYING) COL2: 1.499 kB (CHARACTER VARYING) COL3: 0 B (CHARACTER VARYING) COL4: 0 B (CHARACTER VARYING)
-- COL1: 1 YB (CHARACTER VARYING) COL2: 1000 YB (CHARACTER VARYING) COL3: 1000000 YB (CHARACTER VARYING)

-- # More significant figures, rounding up to the next unit, and rounding
-- # to 1000 of the largest unit.
VALUES ROW(FORMAT_SIZE(1234567890, 10), FORMAT_SIZE(1234567890, 20), FORMAT_SIZE(999999999, 3), FORMAT_SIZE(999999999, 20), FORMAT_SIZE(999999999999999999999999999, 3));
-- COL1: 1.23456789 GB COL2: 1.23456789 GB COL3: 1 GB COL4: 999.999999 MB COL5: 1000 YB

-- # A unit gives the result in that unit, which can be binary, and written in
-- # any way that PARSE_SIZE can read (an empty unit is bytes).
VALUES ROW(FORMAT_SIZE(1073741824, 0, 'MiB'), FORMAT_SIZE(24117248, 3, 'GiB'), FORMAT_SIZE(512, 0, 'MiB'), FORMAT_SIZE(512, 3, 'mib'));
VALUES ROW(FORMAT_SIZE(24117248, 3, 'MB'), FORMAT_SIZE(24117248, 0, 'kilobytes'), FORMAT_SIZE(24117248, 0, 'B'), FORMAT_SIZE(24117248, 0, ''), FORMAT_SIZE(1023, 3, ' k i b '));
VALUES ROW(FORMAT_SIZE(1048575, 0, 'KiB'), FORMAT_SIZE(5000000000000000000, 0, 'EB'), FORMAT_SIZE(1, 3, 'YB'), FORMAT_SIZE(-512, 0, 'MiB'));
-- COL1: 1024 MiB COL2: 0.0225 GiB COL3: 0 MiB COL4: 0.000488 MiB
-- COL1: 24.1 MB COL2: 24117 kB COL3: 24117248 B COL4: 24117248 B COL5: 0.999 KiB
-- COL1: 1024 KiB COL2: 5 EB COL3: 0.000000000000000000000001 YB COL4: 0 MiB

-- # A NULL number of bytes is NULL, but a NULL significant figures or unit is
-- # the default.
VALUES ROW(FORMAT_SIZE(CAST(NULL AS BIGINT)), FORMAT_SIZE(CAST(NULL AS BIGINT), 3, 'MiB'), FORMAT_SIZE(1536, CAST(NULL AS INT)), FORMAT_SIZE(1536, CAST(NULL AS INT), 'B'), FORMAT_SIZE(1536, 3, CAST(NULL AS VARCHAR(3))));
-- COL1: NULL COL2: NULL COL3: 2 kB COL4: 1536 B COL5: 1.54 kB

-- # A base of 2 without a unit uses the largest binary unit instead, and
-- # rounds up to the next unit at 1024. A base of 10 is the default. With a
-- # unit, a base of 2 or 10 is used for it, like PARSE_SIZE.
SELECT x, FORMAT_SIZE(x, 0, CAST(NULL AS VARCHAR(3)), 2), FORMAT_SIZE(x, 3, CAST(NULL AS VARCHAR(3)), 2) FROM (VALUES (1023), (1024), (1536), (1047552), (1048575), (1289748), (24117248), (1288490189), (-24117248)) AS t (x);
-- X: 1023 COL2: 1023 B COL3: 1023 B
-- X: 1024 COL2: 1 KiB COL3: 1 KiB
-- X: 1536 COL2: 2 KiB COL3: 1.5 KiB
-- X: 1047552 COL2: 1023 KiB COL3: 1023 KiB
-- X: 1048575 COL2: 1 MiB COL3: 1 MiB
-- X: 1289748 COL2: 1 MiB COL3: 1.23 MiB
-- X: 24117248 COL2: 23 MiB COL3: 23 MiB
-- X: 1288490189 COL2: 1 GiB COL3: 1.2 GiB
-- X: -24117248 COL2: -23 MiB COL3: -23 MiB

VALUES ROW(FORMAT_SIZE(1237940039285380274899124223, 3, CAST(NULL AS VARCHAR(3)), 2), FORMAT_SIZE(1073741823, 20, CAST(NULL AS VARCHAR(3)), 2), FORMAT_SIZE(24117248, 3, CAST(NULL AS VARCHAR(3)), 10), FORMAT_SIZE(24117248, 3, CAST(NULL AS VARCHAR(3)), 0), FORMAT_SIZE(1536, 3, CAST(NULL AS VARCHAR(3)), CAST(NULL AS INT)));
VALUES ROW(FORMAT_SIZE(24117248, 3, 'MB', 2), FORMAT_SIZE(24117248, 3, 'MiB', 10), FORMAT_SIZE(24117248, 3, 'B', 2));
-- COL1: 1024 YiB COL2: 1023.9999990463256836 MiB COL3: 24.1 MB COL4: 24.1 MB COL5: 1.54 kB
-- COL1: 23 MB COL2: 24.1 MiB COL3: 24117248 B

-- # The significant figures must be from 0 to 20, the unit must be known, and
-- # the base must be 0, 2 or 10.
VALUES FORMAT_SIZE(1, -1);
VALUES FORMAT_SIZE(1, 21);
VALUES FORMAT_SIZE(1, 0, 'MiBs');
VALUES FORMAT_SIZE(1, 0, CAST(NULL AS VARCHAR(3)), 8);
-- error 22023: invalid parameter value: FORMAT_SIZE: significant figures must be from 0 to 20
-- error 22023: invalid parameter value: FORMAT_SIZE: significant figures must be from 0 to 20
-- error 22023: invalid parameter value: FORMAT_SIZE: unknown unit: MiBs
-- error 22023: invalid parameter value: FORMAT_SIZE: base must be 0, 2 or 10

-- # PARSE_SIZE guesses the base from the unit: 1024 for a binary unit, and
-- # 1000 for a decimal unit.
/* types */
VALUES ROW(PARSE_SIZE('23 MiB'), PARSE_SIZE('  23mib '), PARSE_SIZE('23 mebibytes'), PARSE_SIZE('23 MB'), PARSE_SIZE('23 megabytes'));
VALUES ROW(PARSE_SIZE('1.5GiB'), PARSE_SIZE('1.5e3 KB'), PARSE_SIZE('1,024 KiB'), PARSE_SIZE('512'), PARSE_SIZE('-1 Ki'), PARSE_SIZE('1.5 B'));
VALUES ROW(PARSE_SIZE('1 k'), PARSE_SIZE('2 Kilobyte'), PARSE_SIZE('1 EB'), PARSE_SIZE('1EiB'), PARSE_SIZE('1 byte'), PARSE_SIZE('7 bytes'));
VALUES ROW(PARSE_SIZE('1_048_576'), PARSE_SIZE('1,048,576 B'), PARSE_SIZE('+ 2 KiB'), PARSE_SIZE('- 1.2_5 KiB'), PARSE_SIZE('.5 KiB'), PARSE_SIZE('5. KiB'));
VALUES ROW(PARSE_SIZE('2e-1 KiB'), PARSE_SIZE('2E+1 B'), PARSE_SIZE('1e-9999 YiB'), PARSE_SIZE('9223372036854775807'), PARSE_SIZE('0.5 B'), PARSE_SIZE('0.49 B'));
-- COL1: 24117248 (BIGINT) COL2: 24117248 (BIGINT) COL3: 24117248 (BIGINT) COL4: 23000000 (BIGINT) COL5: 23000000 (BIGINT)
-- COL1: 1610612736 (BIGINT) COL2: 1500000 (BIGINT) COL3: 1048576 (BIGINT) COL4: 512 (BIGINT) COL5: -1024 (BIGINT) COL6: 2 (BIGINT)
-- COL1: 1000 (BIGINT) COL2: 2000 (BIGINT) COL3: 1000000000000000000 (BIGINT) COL4: 1152921504606846976 (BIGINT) COL5: 1 (BIGINT) COL6: 7 (BIGINT)
-- COL1: 1048576 (BIGINT) COL2: 1048576 (BIGINT) COL3: 2048 (BIGINT) COL4: -1280 (BIGINT) COL5: 512 (BIGINT) COL6: 5120 (BIGINT)
-- COL1: 205 (BIGINT) COL2: 20 (BIGINT) COL3: 0 (BIGINT) COL4: 9223372036854775807 (BIGINT) COL5: 1 (BIGINT) COL6: 0 (BIGINT)

-- # A base of 2 or 10 is used for every unit instead, except bytes.
VALUES ROW(PARSE_SIZE('23 MiB', 10), PARSE_SIZE('23 MB', 2), PARSE_SIZE('23 mebibytes', 10), PARSE_SIZE('512 bytes', 2), PARSE_SIZE('23 MiB', 0), PARSE_SIZE('23 MB', CAST(NULL AS INT)));
-- COL1: 23000000 COL2: 24117248 COL3: 23000000 COL4: 512 COL5: 24117248 COL6: 23000000

-- # It's the opposite of FORMAT_SIZE.
VALUES ROW(PARSE_SIZE(FORMAT_SIZE(23000000)), PARSE_SIZE(FORMAT_SIZE(1289748, 3, CAST(NULL AS VARCHAR(3)), 2)), PARSE_SIZE(FORMAT_SIZE(24117248, 3, 'MB')), PARSE_SIZE(FORMAT_SIZE(24117248, 3, 'MB', 2), 2));
-- COL1: 23000000 COL2: 1289748 COL3: 24100000 COL4: 24117248

-- # NULL.
VALUES ROW(PARSE_SIZE(CAST(NULL AS VARCHAR(10))), PARSE_SIZE(CAST(NULL AS VARCHAR(10)), 2), PARSE_SIZE(CAST(NULL AS VARCHAR(10)), 10));
-- COL1: NULL COL2: NULL COL3: NULL

-- # A size that can't be read is a 22018 error, more than a BIGINT is a
-- # 22003 error, and the base must be 0, 2 or 10.
VALUES PARSE_SIZE('1,5 GB');
VALUES PARSE_SIZE('abc');
VALUES PARSE_SIZE('');
VALUES PARSE_SIZE('KiB');
VALUES PARSE_SIZE('1,0245 KiB');
VALUES PARSE_SIZE('1024,000 KiB');
VALUES PARSE_SIZE('1,02 KiB');
VALUES PARSE_SIZE('1__0');
VALUES PARSE_SIZE('_10');
VALUES PARSE_SIZE('1 bits');
VALUES PARSE_SIZE('1 MiBB');
VALUES PARSE_SIZE('100 EiB');
VALUES PARSE_SIZE('9223372036854775808');
VALUES PARSE_SIZE('1e99999');
VALUES PARSE_SIZE('1 KiB', 8);
VALUES PARSE_SIZE('1 KiB', -1);
-- error 22018: invalid character value for cast
-- error 22018: invalid character value for cast
-- error 22018: invalid character value for cast
-- error 22018: invalid character value for cast
-- error 22018: invalid character value for cast
-- error 22018: invalid character value for cast
-- error 22018: invalid character value for cast
-- error 22018: invalid character value for cast
-- error 22018: invalid character value for cast
-- error 22018: invalid character value for cast
-- error 22018: invalid character value for cast
-- error 22003: numeric value out of range
-- error 22003: numeric value out of range
-- error 22003: numeric value out of range
-- error 22023: invalid parameter value: PARSE_SIZE: base must be 0, 2 or 10
-- error 22023: invalid parameter value: PARSE_SIZE: base must be 0, 2 or 10

-- # The flagger.
/* flags */
CREATE TABLE t (b INTEGER, s VARCHAR(10));
INSERT INTO t VALUES (1024, '1 KiB');
SELECT FORMAT_SIZE(b), PARSE_SIZE(s) FROM t;
-- flags:
-- msg: CREATE TABLE 1
-- flags:
-- msg: INSERT 1
-- flags: V410-01, V410-02
-- COL1: 1 kB COL2: 1024
