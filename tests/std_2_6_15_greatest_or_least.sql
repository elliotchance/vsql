/* setup */
CREATE TABLE t (x INT, y DOUBLE PRECISION, s VARCHAR(10), d DATE);
INSERT INTO t (x, y, s, d) VALUES (3, 2.5e0, 'b', DATE '2023-01-02');

-- # GREATEST and LEAST are the greatest and least of their arguments (T054,
-- # Conformance Rules, 1), with the combined type of them all (Syntax Rules,
-- # 6).
/* types */
/* flags */
SELECT GREATEST(x, 1, 2), LEAST(x, 1, 2) FROM t;
-- flags: T054
-- COL1: 3 (INTEGER) COL2: 1 (INTEGER)

/* types */
SELECT GREATEST(x, y), LEAST(x, y, 2.75) FROM t;
-- COL1: 3e0 (DOUBLE PRECISION) COL2: 2.5e0 (DOUBLE PRECISION)

/* types */
VALUES ROW(GREATEST(1, 2.5), LEAST(1.25, 10));
-- COL1: 2.5 (NUMERIC(6, 1)) COL2: 1.25 (NUMERIC(7, 2))

SELECT GREATEST(s, 'a', 'c'), LEAST(s, 'a', 'c') FROM t;
-- COL1: c COL2: a

SELECT GREATEST(d, DATE '2023-01-01'), LEAST(d, DATE '2023-01-01') FROM t;
-- COL1: 2023-01-02 COL2: 2023-01-01

VALUES GREATEST(FALSE, TRUE);
-- COL1: TRUE

-- # The result is NULL if any argument is NULL (General Rules, 1).
/* types */
SELECT GREATEST(x, CAST(NULL AS INT)), LEAST(CAST(NULL AS SMALLINT), x, 5) FROM t;
-- COL1: NULL (INTEGER) COL2: NULL (INTEGER)

-- # There must be at least two arguments, and they must be comparable (Syntax
-- # Rules, 4).
VALUES GREATEST(1);
-- error 42601: syntax error: unexpected ")" at line 1, column 18 near "GREATEST(1)", expecting ","

SELECT LEAST(x, s) FROM t;
-- error 42883: cannot compare INTEGER and CHARACTER VARYING(10) in LEAST

SELECT GREATEST(d, TIMESTAMP '2023-01-01 00:00:00') FROM t;
-- error 42883: cannot compare DATE and TIMESTAMP(0) WITHOUT TIME ZONE in GREATEST

-- # A character string or a datetime with a time zone makes it possibly
-- # non-deterministic (9.16, Syntax Rules, 1.f), since 'a' and 'a ' are equal,
-- # so it can't be in a CHECK constraint.
CREATE TABLE c (a VARCHAR(10) CHECK (GREATEST(a, 'b') = 'b'));
-- error 42601: syntax error: GREATEST of CHARACTER VARYING(10) cannot be used in a CHECK constraint

CREATE TABLE c (a INT CHECK (GREATEST(a, 0) < 10));
-- msg: CREATE TABLE 1

-- # It can be used with aggregates.
SELECT GREATEST(MAX(x), 10), LEAST(COUNT(*), 0) FROM t;
-- COL1: 10 COL2: 0
