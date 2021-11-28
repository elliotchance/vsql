VALUES UPPER('Hello');
-- COL1: HELLO

VALUES LOWER('Hello');
-- COL1: hello

VALUES UPPER(123);
-- error 42804: data type mismatch argument 1 in UPPER: expected CHARACTER VARYING but got INTEGER

VALUES LOWER(TRUE);
-- error 42804: data type mismatch argument 1 in LOWER: expected CHARACTER VARYING but got BOOLEAN

VALUES UPPER();
-- error 42601: syntax error: near ")"

VALUES LOWER('abc', 123);
-- error 42601: syntax error: near ","
