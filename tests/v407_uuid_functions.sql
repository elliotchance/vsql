-- # GENERATE_UUID_V4, GENERATE_UUID_V7, UUID_TO_BINARY and BINARY_TO_UUID are
-- # vsql extensions (V407-01 to V407-04) that generate a UUID (RFC 9562) as
-- # lower case text with dashes, and convert it to and from a BINARY(16).

-- # A version 4 UUID is random, other than its version (4) and variant (8, 9,
-- # a or b).
/* types */
VALUES GENERATE_UUID_V4() LIKE '________-____-4___-____-____________';
-- COL1: TRUE (BOOLEAN)

/* types */
VALUES CHAR_LENGTH(GENERATE_UUID_V4());
-- COL1: 36 (INTEGER)

VALUES ROW(SUBSTRING(GENERATE_UUID_V4() FROM 20 FOR 1) IN ('8', '9', 'a', 'b'), GENERATE_UUID_V4() <> GENERATE_UUID_V4());
-- COL1: TRUE COL2: TRUE

-- # The digits are in lower case.
CREATE TABLE t (u VARCHAR(36));
INSERT INTO t VALUES (GENERATE_UUID_V4()), (GENERATE_UUID_V7());
SELECT u = LOWER(u) AS ok FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- OK: TRUE
-- OK: TRUE

-- # A version 7 UUID starts with the time, so each one that a connection
-- # generates is greater than the last.
/* types */
VALUES GENERATE_UUID_V7() LIKE '________-____-7___-____-____________';
-- COL1: TRUE (BOOLEAN)

VALUES ROW(SUBSTRING(GENERATE_UUID_V7() FROM 20 FOR 1) IN ('8', '9', 'a', 'b'), GENERATE_UUID_V7() < GENERATE_UUID_V7());
-- COL1: TRUE COL2: TRUE

CREATE TABLE t (n INT, u VARCHAR(36));
INSERT INTO t VALUES (1, GENERATE_UUID_V7()), (2, GENERATE_UUID_V7()), (3, GENERATE_UUID_V7()), (4, GENERATE_UUID_V7());
INSERT INTO t VALUES (5, GENERATE_UUID_V7());
SELECT n FROM t ORDER BY u;
-- msg: CREATE TABLE 1
-- msg: INSERT 4
-- msg: INSERT 1
-- N: 1
-- N: 2
-- N: 3
-- N: 4
-- N: 5

-- # They're different each time, so they can't be in a CHECK.
CREATE TABLE c (u VARCHAR(36) CHECK (u <> GENERATE_UUID_V4()));
-- error 42601: syntax error: non-deterministic function GENERATE_UUID_V4 cannot be used in a CHECK constraint

CREATE TABLE c (u VARCHAR(36) CHECK (u <> GENERATE_UUID_V7()));
-- error 42601: syntax error: non-deterministic function GENERATE_UUID_V7 cannot be used in a CHECK constraint

-- # UUID_TO_BINARY accepts upper or lower case digits, and BINARY_TO_UUID is
-- # the opposite.
/* types */
VALUES UUID_TO_BINARY('F81D4FAE-7dec-11d0-a765-00a0c91e6bf6');
-- COL1: F81D4FAE7DEC11D0A76500A0C91E6BF6 (BINARY(16))

/* types */
VALUES BINARY_TO_UUID(X'F81D4FAE7DEC11D0A76500A0C91E6BF6');
-- COL1: f81d4fae-7dec-11d0-a765-00a0c91e6bf6 (CHARACTER VARYING(36))

VALUES ROW(BINARY_TO_UUID(UUID_TO_BINARY('00000000-0000-0000-0000-000000000000')), BINARY_TO_UUID(UUID_TO_BINARY('FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF')));
-- COL1: 00000000-0000-0000-0000-000000000000 COL2: ffffffff-ffff-ffff-ffff-ffffffffffff

CREATE TABLE t (u CHAR(36), b BINARY(16), v VARBINARY(16));
INSERT INTO t (u) VALUES (GENERATE_UUID_V4());
UPDATE t SET b = UUID_TO_BINARY(u), v = UUID_TO_BINARY(u);
SELECT BINARY_TO_UUID(b) = u, BINARY_TO_UUID(v) = u FROM t;
INSERT INTO t VALUES (NULL, NULL, NULL);
SELECT UUID_TO_BINARY(u), BINARY_TO_UUID(b) FROM t WHERE u IS NULL;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: UPDATE 1
-- COL1: TRUE COL2: TRUE
-- msg: INSERT 1
-- COL1: NULL COL2: NULL

-- # Anything that isn't a UUID with dashes is an error.
VALUES UUID_TO_BINARY('f81d4fae7dec11d0a76500a0c91e6bf6');
-- error 22018: invalid character value for cast

VALUES UUID_TO_BINARY('{f81d4fae-7dec-11d0-a765-00a0c91e6bf6}');
-- error 22018: invalid character value for cast

VALUES UUID_TO_BINARY('f81d4fae-7dec-11d0-a765-00a0c91e6bfg');
-- error 22018: invalid character value for cast

VALUES UUID_TO_BINARY('f81d4fa--7dec-11d0-a765-00a0c91e-bf6');
-- error 22018: invalid character value for cast

VALUES UUID_TO_BINARY('f81d4fae-7dec-11d0-a765-00a0c91e6bf6-');
-- error 22018: invalid character value for cast

VALUES UUID_TO_BINARY('f81d4fae-7dec-11d0-a765+00a0c91e6bf6');
-- error 22018: invalid character value for cast

-- # A binary string that isn't 16 octets is an error.
VALUES BINARY_TO_UUID(X'F81D4FAE7DEC11D0A76500A0C91E6B');
-- error 22018: invalid character value for cast

VALUES BINARY_TO_UUID(X'F81D4FAE7DEC11D0A76500A0C91E6BF600');
-- error 22018: invalid character value for cast

-- # The flagger.
/* flags */
VALUES ROW(CHAR_LENGTH(GENERATE_UUID_V4()), CHAR_LENGTH(GENERATE_UUID_V7()), BINARY_TO_UUID(UUID_TO_BINARY('f81d4fae-7dec-11d0-a765-00a0c91e6bf6')));
-- flags: F641, F661, T051, V407-01, V407-02, V407-03, V407-04
-- COL1: 36 COL2: 36 COL3: f81d4fae-7dec-11d0-a765-00a0c91e6bf6
