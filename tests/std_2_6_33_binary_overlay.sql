-- # A <binary overlay function> replaces the octets from the start position,
-- # for the string length or the length of the replacement, with the
-- # replacement (6.33, Syntax Rules, 23). Its type is the <binary
-- # concatenation> of the SUBSTRINGs and the replacement (6.33, Syntax Rules,
-- # 23.c).
/* types */
VALUES OVERLAY(X'0102030405' PLACING X'AABB' FROM 2);
-- COL1: 01AABB0405 (BINARY VARYING(12))

/* types */
VALUES OVERLAY(X'0102030405' PLACING X'AA' FROM 2 FOR 3);
-- COL1: 01AA05 (BINARY VARYING(11))

/* types */
VALUES OVERLAY(X'0102' PLACING X'AA' FROM 5);
-- COL1: 0102AA (BINARY VARYING(5))

/* types */
VALUES OVERLAY(CAST(X'0102' AS BLOB(10)) PLACING X'AA' FROM 1 FOR 0);
-- COL1: AA0102 (BINARY LARGE OBJECT(21))

-- # It's NULL if any argument is NULL, and the start position and length are
-- # used for SUBSTRINGs, so a negative length repeats part of the value.
/* types */
VALUES OVERLAY(X'01' PLACING CAST(NULL AS VARBINARY(2)) FROM 1);
-- COL1: NULL (BINARY VARYING(4))

VALUES OVERLAY(X'0102' PLACING X'AA' FROM 0);
-- error 22011: substring error

VALUES OVERLAY(X'0102' PLACING X'AA' FROM 1 FOR -1);
-- COL1: AA0102

-- # Both must be binary strings, and a binary string can't have USING.
VALUES OVERLAY(X'0102' PLACING 'a' FROM 1);
-- error 42883: function does not exist: OVERLAY(BINARY(2) PLACING CHARACTER(1))

VALUES OVERLAY(X'0102' PLACING X'AA' FROM 1 USING OCTETS);
-- error 42601: syntax error: OVERLAY of BINARY(2) cannot have USING OCTETS

-- # The result can't be longer than the maximum length of a BINARY VARYING.
SELECT OCTET_LENGTH(OVERLAY(a PLACING a FROM 1 FOR 0)) FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (SELECT a || a || a || a || a || a || a || a || a || a || a || a || a || a || a || a FROM (VALUES CAST(X'01020304050607080900' AS VARBINARY(10))) AS t0 (a)) AS t1 (a)) AS t2 (a)) AS t3 (a)) AS t4 (a)) AS s (a);
-- error 22001: string data right truncation for BINARY VARYING(10485760)

/* extensions V001-01 */
EXPLAIN SELECT * FROM (VALUES ROW(1)) AS t (x) WHERE OVERLAY(X'0102' PLACING X'03' FROM 1) IS NOT NULL;
-- EXPLAIN: T:
-- EXPLAIN:   VALUES (X SMALLINT) = ROW(1)
-- EXPLAIN: TABLE T (X SMALLINT)
-- EXPLAIN: WHERE OVERLAY(X'0102' PLACING X'03' FROM 1) IS NOT NULL
-- EXPLAIN: EXPR (T.X SMALLINT)

-- # A <binary overlay function> is a <binary value function> (Feature T022)
-- # and an OVERLAY (Feature T312).
/* flags */
VALUES OVERLAY(X'0102' PLACING X'03' FROM 1);
-- flags: F641, F661, T021, T022, T312
-- COL1: 0302
