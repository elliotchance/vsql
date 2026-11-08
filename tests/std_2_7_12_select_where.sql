/* setup */
CREATE TABLE foo (num FLOAT);
INSERT INTO foo (num) VALUES (13);
INSERT INTO foo (num) VALUES (27);
INSERT INTO foo (num) VALUES (35);

-- # WHERE keeps only the rows where the condition is TRUE (General Rules, 2).
-- # Each comparison here is between a DOUBLE PRECISION column and an exact
-- # numeric literal.
/* extensions V001-01 */
EXPLAIN SELECT * FROM foo WHERE num = 27.0;
-- EXPLAIN: TABLE ":memory:".PUBLIC.FOO (NUM DOUBLE PRECISION)
-- EXPLAIN: WHERE NUM = 27.0
-- EXPLAIN: EXPR (":memory:".PUBLIC.FOO.NUM DOUBLE PRECISION)

SELECT * FROM foo WHERE num = 27.0;
-- NUM: 27e0

SELECT * FROM foo WHERE num <> 13.0;
-- NUM: 27e0
-- NUM: 35e0

SELECT * FROM foo WHERE num > 27.0;
-- NUM: 35e0

SELECT * FROM foo WHERE num >= 27.0;
-- NUM: 27e0
-- NUM: 35e0

SELECT * FROM foo WHERE num < 27.0;
-- NUM: 13e0

/* extensions V001-01 */
EXPLAIN SELECT * FROM foo WHERE num <= 27.0;
-- EXPLAIN: TABLE ":memory:".PUBLIC.FOO (NUM DOUBLE PRECISION)
-- EXPLAIN: WHERE NUM <= 27.0
-- EXPLAIN: EXPR (":memory:".PUBLIC.FOO.NUM DOUBLE PRECISION)

SELECT * FROM foo WHERE num <= 27.0;
-- NUM: 13e0
-- NUM: 27e0

-- # The column can be qualified with the table name.
/* extensions V001-01 */
EXPLAIN SELECT * FROM foo WHERE foo.num = 27.0;
-- EXPLAIN: TABLE ":memory:".PUBLIC.FOO (NUM DOUBLE PRECISION)
-- EXPLAIN: WHERE FOO.NUM = 27.0
-- EXPLAIN: EXPR (":memory:".PUBLIC.FOO.NUM DOUBLE PRECISION)

SELECT * FROM foo WHERE foo.num = 27.0;
-- NUM: 27e0
