-- # An <octet like predicate> matches binary strings octet by octet, where
-- # X'25' ("%") is any number of octets and X'5F' ("_") is any one octet (8.5,
-- # General Rules, 4.b-4.f).
VALUES (X'010203' LIKE X'0125', X'010203' LIKE X'015F03', X'010203' LIKE X'0225', X'' LIKE X'', X'0102' NOT LIKE X'2503');
-- COL1: TRUE COL2: TRUE COL3: FALSE COL4: TRUE COL5: TRUE

-- # The escape octet is one octet (8.5, General Rules, 4.d.i.1), which matches
-- # a "%", "_" or itself literally.
VALUES (X'0125' LIKE X'01FF25' ESCAPE X'FF', X'0102' LIKE X'01FF25' ESCAPE X'FF', X'01FF' LIKE X'01FFFF' ESCAPE X'FF');
-- COL1: TRUE COL2: FALSE COL3: TRUE

VALUES X'0102' LIKE X'0125' ESCAPE X'0102';
-- error 2200D: invalid escape octet

VALUES X'0102' LIKE X'01FF' ESCAPE X'FF';
-- error 22025: invalid escape sequence

-- # It's unknown if any operand is NULL (8.5, General Rules, 4.a).
/* types */
CREATE TABLE t (a VARBINARY(3));
INSERT INTO t VALUES (NULL);
SELECT a LIKE X'01', X'01' LIKE a, X'01' LIKE X'01' ESCAPE a FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: UNKNOWN (BOOLEAN) COL2: UNKNOWN (BOOLEAN) COL3: UNKNOWN (BOOLEAN)

-- # The pattern and the escape octet must be binary strings, and there's no
-- # ILIKE of binary strings.
VALUES X'01' LIKE '%';
-- error 42883: operator does not exist: BINARY LIKE CHARACTER

VALUES X'01' LIKE X'01' ESCAPE '#';
-- error 42883: operator does not exist: BINARY LIKE BINARY

/* extensions V302-01 */
VALUES X'01' ILIKE X'01';
-- error 42883: operator does not exist: BINARY ILIKE BINARY

-- # An <octet like predicate> is Feature T022.
/* flags */
VALUES X'01' LIKE X'25';
-- flags: F281, F641, F661, T021, T022
-- COL1: TRUE
