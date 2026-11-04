-- # LIMIT (V203-01) isn't a reserved word: it's only the clause when a row count
-- # follows it, otherwise it's a regular identifier.

/* setup */
CREATE TABLE limit (limit INT);
INSERT INTO limit (limit) VALUES (1);
INSERT INTO limit (limit) VALUES (2);
INSERT INTO limit (limit) VALUES (3);

SELECT limit FROM limit;
-- LIMIT: 1
-- LIMIT: 2
-- LIMIT: 3

SELECT LIMIT FROM LIMIT;
-- LIMIT: 1
-- LIMIT: 2
-- LIMIT: 3

SELECT "LIMIT" FROM "LIMIT";
-- LIMIT: 1
-- LIMIT: 2
-- LIMIT: 3

SELECT limit.limit FROM limit;
-- LIMIT: 1
-- LIMIT: 2
-- LIMIT: 3

-- # An implicit alias, with or without AS.
SELECT limit FROM limit limit;
-- LIMIT: 1
-- LIMIT: 2
-- LIMIT: 3

SELECT l.limit FROM limit AS l;
-- LIMIT: 1
-- LIMIT: 2
-- LIMIT: 3

SELECT limit.limit FROM limit AS limit;
-- LIMIT: 1
-- LIMIT: 2
-- LIMIT: 3

SELECT limit AS limit FROM limit;
-- LIMIT: 1
-- LIMIT: 2
-- LIMIT: 3

SELECT limit limit FROM limit;
-- LIMIT: 1
-- LIMIT: 2
-- LIMIT: 3

SELECT limit + 1 limit FROM limit WHERE limit = 1;
-- LIMIT: 2

SELECT limit.a FROM (SELECT limit AS a FROM limit) limit WHERE a = 1;
-- A: 1

SELECT limit.a FROM (SELECT limit AS a FROM limit) limit (a) WHERE a = 1;
-- A: 1

SELECT limit.a FROM limit limit (a) WHERE a = 1;
-- A: 1

-- # Next to the clause.
/* extensions V203-01 */
SELECT limit FROM limit LIMIT 1;
-- LIMIT: 1

/* extensions V203-01 */
SELECT limit FROM limit limit LIMIT 1;
-- LIMIT: 1

/* extensions V203-01 V203-02 */
SELECT limit limit FROM limit AS limit ORDER BY limit DESC LIMIT 1 OFFSET 1;
-- LIMIT: 2

/* extensions V203-01 */
SELECT limit FROM limit ORDER BY limit LIMIT 1;
-- LIMIT: 1

/* extensions V203-01 */
SELECT limit FROM limit WHERE limit = limit LIMIT 1;
-- LIMIT: 1

/* extensions V203-01 */
SELECT limit FROM limit LIMIT -1;
-- error 2201W: invalid row count in fetch first clause

/* extensions V203-01 */
SELECT limit FROM limit limit LIMIT -1;
-- error 2201W: invalid row count in fetch first clause

/* extensions V203-01 */
SELECT limit FROM limit AS "L" LIMIT -1;
-- error 2201W: invalid row count in fetch first clause

/* extensions V203-01 */
SELECT limit FROM limit WHERE (limit = 1) LIMIT -1;
-- error 2201W: invalid row count in fetch first clause

/* extensions V203-01 */
SELECT limit FROM limit ORDER BY limit DESC LIMIT -1;
-- error 2201W: invalid row count in fetch first clause

-- # A sign after LIMIT is an expression anywhere that an operand is expected.
SELECT limit - 1 FROM limit;
-- COL1: 0
-- COL1: 1
-- COL1: 2

SELECT limit -1 AS a FROM limit;
-- A: 0
-- A: 1
-- A: 2

SELECT limit + 1, limit - 1 FROM limit WHERE limit = 1;
-- COL1: 2 COL2: 0

SELECT ALL limit - 1 FROM limit WHERE limit = 1;
-- COL1: 0

SELECT DISTINCT limit - 1 FROM limit WHERE limit = 1;
-- COL1: 0

SELECT limit.limit - 1 FROM limit WHERE limit = 1;
-- COL1: 0

SELECT - limit - 1, + limit - 1 FROM limit WHERE limit = 1;
-- COL1: -2 COL2: 0

SELECT 2 * limit - 1, 2 / limit - 1 FROM limit WHERE limit = 1;
-- COL1: 1 COL2: 1

SELECT (limit - 1) FROM limit WHERE limit = 1;
-- COL1: 0

SELECT limit FROM limit WHERE limit - 1 = 0;
-- LIMIT: 1

SELECT limit FROM limit WHERE NOT limit - 1 > 0;
-- LIMIT: 1

SELECT limit FROM limit WHERE TRUE AND limit - 1 = 0;
-- LIMIT: 1

SELECT limit FROM limit WHERE FALSE OR limit - 1 = 0;
-- LIMIT: 1

SELECT limit FROM limit WHERE 0 = limit - 1;
-- LIMIT: 1

SELECT limit FROM limit WHERE 0 <> limit - 1 AND 2 > limit - 1;
-- LIMIT: 2

SELECT limit FROM limit WHERE 0 >= limit - 1;
-- LIMIT: 1

SELECT limit FROM limit WHERE 0 < limit - 1 AND 1 <= limit - 1;
-- LIMIT: 2
-- LIMIT: 3

SELECT limit FROM limit WHERE limit BETWEEN limit - 1 AND limit + 1 AND limit = 1;
-- LIMIT: 1

SELECT limit FROM limit WHERE 0 BETWEEN SYMMETRIC limit - 1 AND 0;
-- LIMIT: 1
-- LIMIT: 2
-- LIMIT: 3

SELECT limit FROM limit WHERE 0 BETWEEN ASYMMETRIC limit - 1 AND 0;
-- LIMIT: 1

SELECT limit FROM limit ORDER BY limit - 1 DESC;
-- LIMIT: 3
-- LIMIT: 2
-- LIMIT: 1

SELECT l1.limit FROM limit l1 JOIN limit l2 ON l1.limit - 1 = l2.limit AND l2.limit = 1;
-- LIMIT: 2

SELECT limit FROM limit GROUP BY limit HAVING limit - 1 = 0;
-- LIMIT: 1

SELECT CASE limit - 1 WHEN limit - 1 THEN limit - 1 END FROM limit WHERE limit = 1;
-- COL1: 0

SELECT CASE WHEN limit - 1 = 0 THEN 1 ELSE limit - 1 END FROM limit WHERE limit = 2;
-- COL1: 1

SELECT SUBSTRING('abc' FROM limit - 1 + 1 FOR limit - 1 + 1) FROM limit WHERE limit = 2;
-- COL1: bc

UPDATE limit SET limit = limit - 1 WHERE limit = 3;
SELECT limit FROM limit ORDER BY limit;
-- msg: UPDATE 1
-- LIMIT: 1
-- LIMIT: 2
-- LIMIT: 2

-- # Another column that's named after a type that can start a literal.
CREATE TABLE t2 (limit DATE);
INSERT INTO t2 (limit) VALUES (DATE '2026-11-03');
SELECT limit FROM t2;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- LIMIT: 2026-11-03

CREATE TABLE t3 (limit TIME(0));
CREATE TABLE t4 (limit TIMESTAMP(0));
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1

-- # A name after LIMIT is an alias and then a syntax error, as before.
SELECT * FROM limit LIMIT x;
-- error 42601: syntax error: unexpected identifier

-- # This was always a syntax error, so a sign after a name is the clause.
/* extensions V203-01 */
SELECT * FROM limit limit - 1;
-- error 2201W: invalid row count in fetch first clause

-- # A delimited identifier isn't the clause.
SELECT * FROM limit "limit" 1;
-- error 42601: syntax error: unexpected number

SELECT * FROM limit "LIMIT" 1;
-- error 42601: syntax error: unexpected number

-- # At the start of the statement, it can't be either of them.
limit - 1;
-- error 42601: syntax error: unexpected identifier

/* extensions V301-01 */
SELECT limit FROM limit WHERE 1 != limit - 1;
-- LIMIT: 1
-- LIMIT: 3
