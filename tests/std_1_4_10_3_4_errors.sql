-- # A syntax error has SQLSTATE 42601 (class 42, syntax error or access rule
-- # violation). It's found before anything runs, so the SELECT before the bad
-- # DELETE doesn't return a row either.
TABLE;
-- error 42601: syntax error: unexpected $end at line 1, column 6 near "TABLE"

SELECT 1; DELETE;
-- error 42601: syntax error: unexpected ";" at line 1, column 9 near "SELECT 1; DELETE"
