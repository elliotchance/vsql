/* setup */
CREATE TABLE b (g INT, f BOOLEAN);
INSERT INTO b (g, f) VALUES (1, TRUE), (1, TRUE), (2, TRUE), (2, FALSE), (3, FALSE), (3, UNKNOWN), (4, UNKNOWN);

-- # NULLs are eliminated first. EVERY is False if any value is False (General
-- # Rules, 7.d.vi), and ANY and SOME are True if any value is True (General
-- # Rules, 7.d.vii). Otherwise EVERY is True and ANY is False, but with only
-- # NULLs or no rows the result is the null value, UNKNOWN (General Rules,
-- # 7.d.ii).
/* types */
SELECT g, EVERY(f), ANY(f), SOME(f) FROM b GROUP BY g;
-- warning 01003: null value eliminated in set function
-- G: 1 (INTEGER) COL2: TRUE (BOOLEAN) COL3: TRUE (BOOLEAN) COL4: TRUE (BOOLEAN)
-- G: 2 (INTEGER) COL2: FALSE (BOOLEAN) COL3: TRUE (BOOLEAN) COL4: TRUE (BOOLEAN)
-- G: 3 (INTEGER) COL2: FALSE (BOOLEAN) COL3: FALSE (BOOLEAN) COL4: FALSE (BOOLEAN)
-- G: 4 (INTEGER) COL2: UNKNOWN (BOOLEAN) COL3: UNKNOWN (BOOLEAN) COL4: UNKNOWN (BOOLEAN)

SELECT EVERY(f), ANY(f), SOME(f) FROM b;
-- warning 01003: null value eliminated in set function
-- COL1: FALSE COL2: TRUE COL3: TRUE

SELECT EVERY(f), ANY(f), SOME(f) FROM b WHERE g = 1;
-- COL1: TRUE COL2: TRUE COL3: TRUE

SELECT EVERY(f), ANY(f) FROM b WHERE 1 = 0;
-- COL1: UNKNOWN COL2: UNKNOWN

-- # DISTINCT and ALL don't change the result.
SELECT EVERY(DISTINCT f), ANY(ALL f), SOME(DISTINCT f) FROM b;
-- warning 01003: null value eliminated in set function
-- COL1: FALSE COL2: TRUE COL3: TRUE

-- # The argument can be any boolean expression.
SELECT EVERY(g > 0), ANY(g > 3), SOME(g = 1 AND f) FROM b;
-- COL1: TRUE COL2: TRUE COL3: TRUE

-- # HAVING only keeps the groups where the result is True, not UNKNOWN.
SELECT g FROM b GROUP BY g HAVING EVERY(f);
-- warning 01003: null value eliminated in set function
-- G: 1

SELECT g, ANY(f) = TRUE FROM b GROUP BY g HAVING SOME(f);
-- warning 01003: null value eliminated in set function
-- G: 1 COL2: TRUE
-- G: 2 COL2: TRUE

-- # In a correlated subquery, each group gets its own result.
SELECT g, (SELECT EVERY(c.f) FROM b AS c WHERE c.g = b.g) FROM b GROUP BY g;
-- warning 01003: null value eliminated in set function
-- warning 01003: null value eliminated in set function
-- G: 1 COL2: TRUE
-- G: 2 COL2: FALSE
-- G: 3 COL2: FALSE
-- G: 4 COL2: UNKNOWN

-- # The functions are kept as they're written when the plan is shown.
/* extensions V001-01 */
EXPLAIN SELECT EVERY(f), ANY(DISTINCT f), SOME(f) FROM b;
-- EXPLAIN: TABLE ":memory:".PUBLIC.B (G INTEGER, F BOOLEAN)
-- EXPLAIN: GROUP BY (EVERY(F) BOOLEAN, ANY(DISTINCT F) BOOLEAN, SOME(F) BOOLEAN)
-- EXPLAIN: EXPR (COL1 BOOLEAN, COL2 BOOLEAN, COL3 BOOLEAN)

-- # The argument must be a boolean (Syntax Rules, 7.e).
SELECT EVERY(g) FROM b;
-- error 42883: function does not exist: EVERY(INTEGER)

SELECT ANY(g) FROM b;
-- error 42883: function does not exist: ANY(INTEGER)

SELECT SOME(DISTINCT g) FROM b;
-- error 42883: function does not exist: SOME(INTEGER)

-- # Like any aggregate function, they can't be nested or used in WHERE.
SELECT EVERY(EVERY(f)) FROM b;
-- error 42601: syntax error: nested set function: EVERY(EVERY(F))

SELECT g FROM b WHERE ANY(f);
-- error 42601: syntax error: an aggregate function cannot be used in WHERE

-- # ANY or SOME followed by a subquery is a quantified comparison (see 8.9),
-- # not an aggregate function. Without a subquery, f = ANY(f) compares f to the
-- # aggregate function of its group.
SELECT f = ANY(f) FROM b GROUP BY f;
-- warning 01003: null value eliminated in set function
-- COL1: UNKNOWN
-- COL1: TRUE
-- COL1: TRUE

SELECT DISTINCT g FROM b WHERE g = ANY (SELECT 1 FROM b);
-- G: 1

SELECT DISTINCT g FROM b WHERE g < SOME (SELECT 2 FROM b);
-- G: 1

SELECT DISTINCT g FROM b WHERE g = ALL (SELECT 1 FROM b);
-- G: 1

SELECT DISTINCT g FROM b WHERE g = ANY ((SELECT 1 FROM b));
-- G: 1

SELECT DISTINCT g FROM b WHERE g = SOME (VALUES 2);
-- G: 2

/* extensions V201-01 */
SELECT TRUE = ANY (SELECT f FROM b);
-- COL1: TRUE

-- # EVERY, ANY and SOME are part of the BOOLEAN data type (Conformance Rules,
-- # 2), so they are flagged as T031.
/* flags */
SELECT EVERY(f), ANY(f), SOME(f) FROM b;
-- flags: T031
-- warning 01003: null value eliminated in set function
-- COL1: FALSE COL2: TRUE COL3: TRUE

/* flags */
SELECT ANY(DISTINCT f) FROM b;
-- flags: T031
-- warning 01003: null value eliminated in set function
-- COL1: TRUE

-- # The filter is applied before the NULLs are eliminated, and a group with no
-- # rows left is UNKNOWN.
SELECT g, EVERY(f) FILTER (WHERE f), ANY(f) FILTER (WHERE NOT f), SOME(f) FILTER (WHERE g > 2) FROM b GROUP BY g;
-- warning 01003: null value eliminated in set function
-- G: 1 COL2: TRUE COL3: UNKNOWN COL4: UNKNOWN
-- G: 2 COL2: TRUE COL3: FALSE COL4: UNKNOWN
-- G: 3 COL2: UNKNOWN COL3: FALSE COL4: FALSE
-- G: 4 COL2: UNKNOWN COL3: UNKNOWN COL4: UNKNOWN
