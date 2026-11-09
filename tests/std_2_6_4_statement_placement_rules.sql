/* setup */
CREATE TABLE t (x INT, b BOOLEAN);
INSERT INTO t (x, b) VALUES (1, TRUE);

-- # A host parameter (or embedded variable) is only allowed in an SQL-client
-- # module or an embedded SQL program.
VALUES :x;
-- error 42601: syntax error: unexpected ":" at line 1, column 8 near "VALUES :x"

SELECT x FROM t WHERE x = :x;
-- error 42601: syntax error: unexpected ":" at line 1, column 27 near "WHERE x = :x"

-- # An aggregate function can't be used in a SET clause.
UPDATE t SET x = COUNT(*);
-- error 42601: syntax error: an aggregate function cannot be used in SET

UPDATE t SET x = SUM(x) + 1;
-- error 42601: syntax error: an aggregate function cannot be used in SET

-- # A unique constraint needs at least one column.
CREATE TABLE u (x INT, UNIQUE ());
-- error 42601: syntax error: unexpected ")" at line 1, column 32 near ", UNIQUE ())"
