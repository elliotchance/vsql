TABLE;
-- error 42601: syntax error: unexpected TABLE

SELECT 1; DELETE;
-- error 42601: syntax error: unexpected ";", expecting FROM or ","
