VALUES 'foo' || 'bar';
-- COL1: foobar

VALUES 123 || 'bar';
-- error 42883: operator does not exist: NUMERIC || CHARACTER VARYING
