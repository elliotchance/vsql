/* types */
VALUES 'foo' || 'bar';
-- COL1: foobar (CHARACTER VARYING(6))

VALUES 123 || 'bar';
-- error 42883: operator does not exist: NUMERIC || CHARACTER
