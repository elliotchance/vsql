-- # T625 LISTAGG: the values of a group joined with a separator, in the order of
-- # the WITHIN GROUP.
/* setup */
CREATE TABLE t (g INT, x VARCHAR(10), y INT);
INSERT INTO t (g, x, y) VALUES (1, 'b', 2), (1, 'a', 3), (1, NULL, 1), (2, 'c', NULL), (1, 'a', 1), (2, 'd', 5);
CREATE TABLE products (city VARCHAR(20), name VARCHAR(20));
CREATE TABLE padded (x VARCHAR(5));
INSERT INTO padded (x) VALUES ('a'), ('a  '), ('b');
INSERT INTO products (city, name) VALUES ('New York', 'pen'), ('New York', 'cup'), ('San Francisco', 'hat'), ('San Francisco', 'pen'), ('San Francisco', NULL);

/* types */
SELECT LISTAGG(x, ', ') WITHIN GROUP (ORDER BY x) FROM t;
-- warning 01003: null value eliminated in set function
-- COL1: a, a, b, c, d (CHARACTER VARYING(10485760))

SELECT g, LISTAGG(x, '-') WITHIN GROUP (ORDER BY x DESC) FROM t GROUP BY g;
-- warning 01003: null value eliminated in set function
-- G: 1 COL2: b-a-a
-- G: 2 COL2: d-c

SELECT LISTAGG(x, '') WITHIN GROUP (ORDER BY y, x DESC) FROM t;
-- warning 01003: null value eliminated in set function
-- COL1: cabad

SELECT LISTAGG(x, ',') WITHIN GROUP (ORDER BY y DESC) FROM t;
-- warning 01003: null value eliminated in set function
-- COL1: d,a,b,a,c

SELECT LISTAGG(x, ',') WITHIN GROUP (ORDER BY 1) FROM t WHERE g = 2;
-- COL1: c,d

SELECT LISTAGG(x, ',') WITHIN GROUP (ORDER BY UPPER(x) || 'z' DESC) FROM t WHERE g = 2;
-- COL1: d,c

SELECT LISTAGG(DISTINCT x, ',') WITHIN GROUP (ORDER BY x) FROM t;
-- warning 01003: null value eliminated in set function
-- COL1: a,b,c,d

SELECT LISTAGG(ALL x, ',') WITHIN GROUP (ORDER BY x) FROM t WHERE g = 1;
-- warning 01003: null value eliminated in set function
-- COL1: a,a,b

SELECT LISTAGG(DISTINCT x, ',') WITHIN GROUP (ORDER BY y DESC) FROM t;
-- warning 01003: null value eliminated in set function
-- COL1: d,a,b,c

SELECT LISTAGG(x, ',') WITHIN GROUP (ORDER BY x) FROM t WHERE g = 3;
-- COL1: NULL

SELECT LISTAGG(x, ',') WITHIN GROUP (ORDER BY x) FROM t WHERE x IS NULL;
-- warning 01003: null value eliminated in set function
-- COL1: NULL

SELECT g, LISTAGG(x, ',') WITHIN GROUP (ORDER BY x) FROM t WHERE x IS NULL OR g = 2 GROUP BY g;
-- warning 01003: null value eliminated in set function
-- G: 1 COL2: NULL
-- G: 2 COL2: c,d

SELECT LISTAGG(x, ',') WITHIN GROUP (ORDER BY x) FILTER (WHERE y > 1) FROM t;
-- COL1: a,b,d

SELECT LISTAGG(x || '!', ' ') WITHIN GROUP (ORDER BY x) FROM t WHERE g = 2;
-- COL1: c! d!

SELECT LISTAGG(CAST(x AS CHAR(3)), ',') WITHIN GROUP (ORDER BY x) FROM t WHERE g = 2;
-- COL1: c  ,d

SELECT '[' || LISTAGG(DISTINCT x, ',') WITHIN GROUP (ORDER BY x) || ']' FROM padded;
-- COL1: [a,b]

SELECT LISTAGG(x, ' ☃ ') WITHIN GROUP (ORDER BY x) FROM (VALUES 'ü', 'ß') AS v (x);
-- COL1: ß ☃ ü

SELECT LISTAGG(x, 'it''s') WITHIN GROUP (ORDER BY x) FROM t WHERE g = 2;
-- COL1: cit'sd

SELECT LISTAGG(x, ',' ON OVERFLOW ERROR) WITHIN GROUP (ORDER BY x) FROM t WHERE g = 2;
-- COL1: c,d

SELECT LISTAGG(x, ',' ON OVERFLOW TRUNCATE WITH COUNT) WITHIN GROUP (ORDER BY x) FROM t WHERE g = 2;
-- COL1: c,d

SELECT LISTAGG(x, ',' ON OVERFLOW TRUNCATE '~' WITHOUT COUNT) WITHIN GROUP (ORDER BY x) FROM t WHERE g = 2;
-- COL1: c,d

SELECT city, LISTAGG(name, ', ') WITHIN GROUP (ORDER BY name) FROM products GROUP BY city;
-- warning 01003: null value eliminated in set function
-- CITY: New York COL2: cup, pen
-- CITY: San Francisco COL2: hat, pen

SELECT name, LISTAGG(city, '; ') WITHIN GROUP (ORDER BY city DESC) FROM products WHERE name IS NOT NULL GROUP BY name HAVING COUNT(*) > 1;
-- NAME: pen COL2: San Francisco; New York

/* extensions V202-03 */
SELECT g FROM t GROUP BY g ORDER BY LISTAGG(x, ',') WITHIN GROUP (ORDER BY x) DESC;
-- warning 01003: null value eliminated in set function
-- G: 2
-- G: 1

SELECT g, (SELECT LISTAGG(t.x, ',') WITHIN GROUP (ORDER BY t.x) FROM (VALUES 1) AS u (z)) FROM t GROUP BY g;
-- warning 01003: null value eliminated in set function
-- G: 1 COL2: a,a,b
-- G: 2 COL2: c,d

SELECT (SELECT LISTAGG(u.z || t.x, ',') WITHIN GROUP (ORDER BY u.z) FROM (VALUES 'p', 'q') AS u (z)) FROM t WHERE g = 2;
-- COL1: pc,qc
-- COL1: pd,qd

SELECT CHAR_LENGTH(LISTAGG(x, ',') WITHIN GROUP (ORDER BY x)) FROM t;
-- warning 01003: null value eliminated in set function
-- COL1: 9

/* extensions V001-01 */
EXPLAIN SELECT LISTAGG(DISTINCT x, ', ' ON OVERFLOW TRUNCATE '~' WITH COUNT) WITHIN GROUP (ORDER BY y DESC, x) FILTER (WHERE g = 1) FROM t;
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (G INTEGER, X CHARACTER VARYING(10), Y INTEGER)
-- EXPLAIN: GROUP BY (LISTAGG(DISTINCT X, ', ' ON OVERFLOW TRUNCATE '~' WITH COUNT) WITHIN GROUP (ORDER BY Y DESC, X ASC) FILTER (WHERE G = 1) CHARACTER VARYING(10485760))
-- EXPLAIN: EXPR (COL1 CHARACTER VARYING(10485760))

/* extensions V001-01 */
EXPLAIN SELECT LISTAGG(x, ',' ON OVERFLOW TRUNCATE WITHOUT COUNT) WITHIN GROUP (ORDER BY x) FROM t;
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (G INTEGER, X CHARACTER VARYING(10), Y INTEGER)
-- EXPLAIN: GROUP BY (LISTAGG(X, ',' ON OVERFLOW TRUNCATE '...' WITHOUT COUNT) WITHIN GROUP (ORDER BY X ASC) CHARACTER VARYING(10485760))
-- EXPLAIN: EXPR (COL1 CHARACTER VARYING(10485760))

SELECT LISTAGG(y, ',') WITHIN GROUP (ORDER BY y) FROM t;
-- error 42883: function does not exist: LISTAGG(INTEGER)

SELECT LISTAGG(x, ',') WITHIN GROUP (ORDER BY COUNT(*)) FROM t;
-- error 42601: syntax error: nested set function: LISTAGG(X, ',') WITHIN GROUP (ORDER BY COUNT(*) ASC)

SELECT LISTAGG(MAX(x), ',') WITHIN GROUP (ORDER BY 1) FROM t;
-- error 42601: syntax error: nested set function: LISTAGG(MAX(X), ',') WITHIN GROUP (ORDER BY 1 ASC)

SELECT MAX(LISTAGG(x, ',') WITHIN GROUP (ORDER BY x)) FROM t;
-- error 42601: syntax error: nested set function: MAX(LISTAGG(X, ',') WITHIN GROUP (ORDER BY X ASC))

/* extensions V201-01 */
SELECT LISTAGG(x, ',') WITHIN GROUP (ORDER BY (SELECT 1)) FROM t;
-- error 42601: syntax error: a subquery cannot be used in an aggregate function

/* extensions V201-01 */
SELECT LISTAGG((SELECT 'a'), ',') WITHIN GROUP (ORDER BY x) FROM t;
-- error 42601: syntax error: a subquery cannot be used in an aggregate function

SELECT x FROM t WHERE LISTAGG(x, ',') WITHIN GROUP (ORDER BY x) = 'a';
-- error 42601: syntax error: an aggregate function cannot be used in WHERE

SELECT LISTAGG(x, ',') WITHIN GROUP (ORDER BY x) FILTER (WHERE COUNT(*) > 1) FROM t;
-- error 42601: syntax error: nested set function: LISTAGG(X, ',') WITHIN GROUP (ORDER BY X ASC) FILTER (WHERE COUNT(*) > 1)

SELECT LISTAGG(x, ',') FROM t;
-- error 42601: syntax error: unexpected FROM at line 1, column 24 near ", ',') FROM t", expecting WITHIN

SELECT LISTAGG(x) WITHIN GROUP (ORDER BY x) FROM t;
-- error 42601: syntax error: unexpected ")" at line 1, column 17 near "LISTAGG(x) WITHIN", expecting "," or "||"

SELECT LISTAGG(x, x) WITHIN GROUP (ORDER BY x) FROM t;
-- error 42601: syntax error: unexpected identifier at line 1, column 19 near "(x, x)", expecting string

CREATE TABLE c (x VARCHAR(10) CHECK (LISTAGG(x, ',') WITHIN GROUP (ORDER BY x) <> ''));
-- error 42601: syntax error: an aggregate function cannot be used in a CHECK constraint
