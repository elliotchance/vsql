-- # A host parameter name (such as :x) can only be used in an SQL-client
-- # module (Part 2, 6.4, Syntax Rules, 2), and an embedded variable name (such
-- # as :x INDICATOR :y) only in an embedded SQL program (Syntax Rules, 10). A
-- # statement that's run on its own can't use either.
VALUES :x;
VALUES :x INDICATOR :y;
-- error 42601: syntax error: unexpected ":" at line 1, column 8 near "VALUES :x"
-- error 42601: syntax error: unexpected ":" at line 1, column 8 near "VALUES :x"
