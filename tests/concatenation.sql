/* setup */
CREATE TABLE t1 (x INT);
INSERT INTO t1 (x) VALUES (0);

SELECT 'foo' || 'bar' FROM t1;
-- COL1: foobar

SELECT 123 || 'bar' FROM t1;
-- error 42804: data type mismatch cannot INTEGER || CHARACTER VARYING: expected another type but got INTEGER and CHARACTER VARYING
