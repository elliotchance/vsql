/* types */
VALUES UPPER('Hello');
-- COL1: HELLO (CHARACTER VARYING(5))

/* types */
VALUES LOWER('Hello');
-- COL1: hello (CHARACTER VARYING(5))

VALUES UPPER(123);
-- error 42883: function does not exist: UPPER(SMALLINT)

VALUES LOWER(TRUE);
-- error 42883: function does not exist: LOWER(BOOLEAN)

VALUES UPPER();
-- error 42601: syntax error: unexpected ")"

VALUES LOWER('abc', 123);
-- error 42601: syntax error: unexpected ",", expecting ")" or "||"
