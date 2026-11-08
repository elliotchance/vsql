-- # A function that doesn't exist is an error that shows the types of the
-- # arguments, which is how a function is chosen. A literal like 1 is a
-- # SMALLINT.
VALUES no_such_function();
-- error 42883: function does not exist: NO_SUCH_FUNCTION()

VALUES no_such_function(1);
-- error 42883: function does not exist: NO_SUCH_FUNCTION(SMALLINT)

VALUES no_such_function(1, 'a', 2.5);
-- error 42883: function does not exist: NO_SUCH_FUNCTION(SMALLINT, CHARACTER(1), NUMERIC(2, 1))

-- # An argument can't be left out.
VALUES no_such_function(1,);
-- error 42601: syntax error: unexpected ")"
