VALUES no_such_function();
-- error 42883: function does not exist: NO_SUCH_FUNCTION()

VALUES no_such_function(1);
-- error 42883: function does not exist: NO_SUCH_FUNCTION(SMALLINT)

VALUES no_such_function(1, 'a', 2.5);
-- error 42883: function does not exist: NO_SUCH_FUNCTION(SMALLINT, CHARACTER(1), NUMERIC(2, 1))

VALUES no_such_function(1,);
-- error 42601: syntax error: unexpected ")"
