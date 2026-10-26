Custom Functions
================

You can create custom functions to use in expressions:

.. code-block:: text

   // no_pennies will round to 0.05 denominations.
   db.register_function('no_pennies(float) float', fn (a []vsql.Value) !vsql.Value {
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

A function must return a value to match the return type. See the full list of
``Value`` constructors in :doc:`language-v`.

See also
`examples/custom-functions.v <https://github.com/elliotchance/vsql/blob/main/examples/custom-functions.v>`_.
