Custom Functions
================

You can create custom functions to use in expressions:

.. code-block:: v

   // no_pennies will round to 0.05 denominations.
   db.register_function('no_pennies(float) float', fn (_ vsql.FunctionContext, a []vsql.Value) !vsql.Value {
   	amount := math.round(a[0].f64_value() / 0.05) * 0.05
   	return vsql.new_double_precision_value(amount)
   })!

   db.query('CREATE TABLE products (product_name VARCHAR(100), price FLOAT)')!
   db.query("INSERT INTO products (product_name, price) VALUES ('Ice Cream', 5.99)")!
   db.query("INSERT INTO products (product_name, price) VALUES ('Ham Sandwich', 3.47)")!
   db.query("INSERT INTO products (product_name, price) VALUES ('Bagel', 1.25)")!

   result := db.query('SELECT product_name, no_pennies(price) as total FROM products')!
   for row in result {
   	total := row.get_f64('TOTAL')!
   	println('${row.get_string('PRODUCT_NAME')!} $${total:.2f}')
   }

Outputs:

.. code-block:: text

   Ice Cream $6.00
   Ham Sandwich $3.45
   Bagel $1.25

Unlike the builtin functions (which return ``NULL`` if any argument is
``NULL``), a custom function is always called. Use ``is_null`` on the argument
values to handle ``NULL`` yourself.

A function is identified by its name and argument types, so a function with the
same name can be registered more than once with different argument types. A
function with the same name and argument types as one that already exists (a
custom or builtin function) is an error ``42723``, even if the return type is
different, because only the arguments choose which function is called.
A prototype that isn't ``name(type, ...) type``, or has a type that doesn't
exist, is an error ``42601``.

An argument doesn't have to have exactly the type of the parameter. A number
can be passed to a wider numeric parameter (such as an ``INTEGER`` to a
``FLOAT``), and a ``DATE`` can be passed to a ``TIMESTAMP`` (or
``TIMESTAMP WITH TIME ZONE``) parameter, where it's midnight at the start of
that day (this is feature F054, "TIMESTAMP in DATE type precedence list"). If
there's more than one function that the arguments can be passed to, the one
with the closest parameter types is called, so a function with a ``DATE``
parameter is chosen over one with a ``TIMESTAMP`` parameter for a ``DATE``.

A parameter can have a name before its type, such as
``'no_pennies(amount float) float'``. The name is only shown by the
``PARAMETERS`` view (see :doc:`information-schema`), where it's in upper case
unless it's quoted (``"amount" float``). A parameter without a name is ``NULL``
there.

A function is called with a ``FunctionContext`` before its arguments. It has
the values that a function can know besides its arguments:

- ``current_timestamp()`` is the same value as ``CURRENT_TIMESTAMP``: when the
  statement started, which is the same for every call in the statement.
- ``clock_timestamp()`` is the time now, read from the wall clock each time
  it's called (this is what ``NOW()`` returns).
- ``statement_timestamp()`` is the same time as ``current_timestamp()`` (in
  UTC) and the time zone of the session (in minutes from UTC).
- ``current_catalog()`` and ``current_schema()`` are the same as
  ``CURRENT_CATALOG`` and ``CURRENT_SCHEMA``.
- ``in_transaction()`` is true if the statement is in a transaction started with
  ``START TRANSACTION``.
- ``version()`` is the version of vsql.

For example:

.. code-block:: v

   db.register_function('started() varchar', fn (ctx vsql.FunctionContext, _ []vsql.Value) !vsql.Value {
   	return vsql.new_varchar_value(ctx.current_timestamp()!.str())
   })!

A function must return a value to match the return type. See the full list of
``Value`` constructors in :doc:`language-v`.

See also
`examples/custom-functions.v <https://github.com/elliotchance/vsql/blob/main/examples/custom-functions.v>`_.
