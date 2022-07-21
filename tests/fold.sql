VALUES UPPER('Hello');
-- COL1: HELLO

VALUES LOWER('Hello');
-- COL1: hello

VALUES UPPER(123);
-- error 42883: function does not exist: UPPER(BIGINT)

VALUES LOWER(TRUE);
-- error 42883: function does not exist: LOWER(BOOLEAN)

VALUES UPPER();
-- error 42601: syntax error: near ")"

VALUES LOWER('abc', 123);
-- error 42601: syntax error: near ","
