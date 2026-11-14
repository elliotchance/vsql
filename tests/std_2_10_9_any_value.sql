/* setup */
CREATE TABLE t (g INT, x INT, s VARCHAR(10));
INSERT INTO t (g, x, s) VALUES (1, 5, 'a'), (1, 5, 'a'), (2, NULL, NULL), (2, 7, 'b'), (3, NULL, NULL);

-- # ANY_VALUE is a value of the group, with the type of its argument (T626,
-- # Conformance Rules, 2, Syntax Rules, 7.f and General Rules, 7.d.v). Which
-- # one is implementation-dependent, but it's never NULL unless every value is.
/* types */
/* flags */
SELECT g, ANY_VALUE(x), ANY_VALUE(s) FROM t GROUP BY g ORDER BY g;
-- flags: T626
-- warning 01003: null value eliminated in set function
-- G: 1 (INTEGER) COL2: 5 (INTEGER) COL3: a (CHARACTER VARYING(10))
-- G: 2 (INTEGER) COL2: 7 (INTEGER) COL3: b (CHARACTER VARYING(10))
-- G: 3 (INTEGER) COL2: NULL (INTEGER) COL3: NULL (CHARACTER VARYING(10))

-- # Without a GROUP BY, it's one of all the values, or NULL when there are no
-- # rows.
SELECT ANY_VALUE(x) BETWEEN 5 AND 7 FROM t;
-- warning 01003: null value eliminated in set function
-- COL1: TRUE

SELECT ANY_VALUE(x) FROM t WHERE g = 4;
-- COL1: NULL

-- # It can be used with DISTINCT, and on any type.
SELECT ANY_VALUE(DISTINCT s), ANY_VALUE(CAST('a' AS CHAR(3))) || '|', ANY_VALUE(TRUE), ANY_VALUE(DATE '2023-01-01') FROM t WHERE g = 1;
-- COL1: a COL2: a  | COL3: TRUE COL4: 2023-01-01

-- # It's an aggregate, so it can't be used in a WHERE.
SELECT * FROM t WHERE ANY_VALUE(x) = 5;
-- error 42601: syntax error: an aggregate function cannot be used in WHERE
