SELECT 1 AS operator_plus FROM (VALUES 1) AS t;
-- OPERATOR_PLUS: 1

SELECT 1 AS literal_string FROM (VALUES 1) AS t;
-- LITERAL_STRING: 1

CREATE TABLE literal_number (operator_bang_equals INT);
INSERT INTO literal_number (operator_bang_equals) VALUES (1);
SELECT * FROM literal_number WHERE operator_bang_equals = 1;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- OPERATOR_BANG_EQUALS: 1
