-- # != is a vsql extension (V301-01) that behaves the same as <>. Only != is
-- # flagged, and <> stays Core SQL.
/* setup */
CREATE TABLE t (x INT, y INT);
INSERT INTO t (x, y) VALUES (1, 1);
INSERT INTO t (x, y) VALUES (1, 2);
INSERT INTO t (x, y) VALUES (NULL, 2);

/* flags */
SELECT y FROM t WHERE x <> y;
-- flags:
-- Y: 2

/* extensions V301-01 */
/* flags */
SELECT y FROM t WHERE x != y;
-- flags: V301-01
-- Y: 2

-- # No separator is needed.
/* extensions V301-01 */
SELECT y FROM t WHERE x!=y;
-- Y: 2

/* extensions V301-01 */
SELECT y FROM t WHERE 'a' != 'b' AND 'a' != 'a';

/* extensions V301-01 */
SELECT y FROM t WHERE 'a' != 'b' AND x = y;
-- Y: 1

-- # A comparison with NULL is UNKNOWN, the same as <>.
/* extensions V301-01 */
SELECT y FROM t WHERE x != 2;
-- Y: 1
-- Y: 2

/* extensions V301-01 */
SELECT y FROM t WHERE NOT (x != 2);

/* extensions V301-01 */
SELECT y, x != 2 AS a, x <> 2 AS b FROM t WHERE y = 2;
-- Y: 2 A: TRUE B: TRUE
-- Y: 2 A: UNKNOWN B: UNKNOWN

-- # A row value can't be compared with either of them yet (#722).
SELECT x, y FROM t WHERE (x, y) <> (1, 2);
-- error 42601: syntax error: unexpected "<>", expecting IS

SELECT x, y FROM t WHERE (x, y) != (1, 2);
-- error 42601: syntax error: unexpected "!=", expecting IS

-- # A boolean predicand.
/* extensions V301-01 */
/* flags */
SELECT y FROM t WHERE (x = 1) != FALSE;
-- flags: T031, V301-01
-- Y: 1
-- Y: 2

-- # Subqueries, including a quantified comparison.
/* extensions V301-01 */
SELECT y FROM t WHERE (SELECT MAX(y) FROM t) != y;
-- Y: 1

/* extensions V301-01 */
/* flags */
SELECT y FROM t WHERE y != ALL (SELECT x FROM t WHERE x IS NOT NULL);
-- flags: V301-01
-- Y: 2
-- Y: 2

/* extensions V301-01 */
SELECT y FROM t WHERE y != SOME (SELECT y FROM t);
-- Y: 1
-- Y: 2
-- Y: 2

-- # != in a string or a comment isn't the operator.
/* flags */
SELECT '!=' AS a, y /* != */ FROM t WHERE x = y;
-- flags: T351
-- A: != Y: 1

-- # ! isn't a token by itself.
VALUES 1 ! 2;
-- error 42601: syntax error: invalid character: !

VALUES 1 ! = 2;
-- error 42601: syntax error: invalid character: !

VALUES 1 !/* */= 2;
-- error 42601: syntax error: invalid character: !

VALUES 1 !;
-- error 42601: syntax error: invalid character: !

VALUES !1;
-- error 42601: syntax error: invalid character: !

-- # The error is about what was written.
VALUES != 1;
-- error 42601: syntax error: unexpected "!="

VALUES <> 1;
-- error 42601: syntax error: unexpected "<>"

VALUES 1 !== 2;
-- error 42601: syntax error: unexpected "="

-- # A CHECK constraint and a generated column keep the standard spelling, so
-- # that a dump doesn't depend on the extension.
/* extensions V301-01 */
CREATE TABLE c (x INT CONSTRAINT c1 CHECK (x != 1), y BOOLEAN GENERATED ALWAYS AS (x != 2));
INSERT INTO c (x) VALUES (2);
INSERT INTO c (x) VALUES (3);
SELECT * FROM c;
INSERT INTO c (x) VALUES (1);
SELECT CHECK_CLAUSE FROM INFORMATION_SCHEMA.CHECK_CONSTRAINTS WHERE CONSTRAINT_NAME = 'C1';
SELECT GENERATION_EXPRESSION FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'C' AND COLUMN_NAME = 'Y';
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- X: 2 Y: FALSE
-- X: 3 Y: TRUE
-- error 23514: violates check constraint: CHECK (X <> 1) on ":memory:".PUBLIC.C
-- CHECK_CLAUSE: X <> 1
-- GENERATION_EXPRESSION: X <> 2
