V Client Library
================

.. contents::

Install/Update
--------------

Install or update to the latest with:

.. code-block:: sh

   v install elliotchance.vsql

Example
-------

.. code-block:: v

   import elliotchance.vsql.vsql

   fn example() ! {
   	mut db := vsql.open(':memory:')!

   	// All SQL commands use query():
   	db.query('CREATE TABLE foo (x DOUBLE PRECISION)')!
   	db.query('INSERT INTO foo (x) VALUES (1.23)')!
   	db.query('INSERT INTO foo (x) VALUES (4.56)')!

   	// Iterate through a result:
   	result := db.query('SELECT * FROM foo')!
   	println(result.columns)

   	for row in result {
   		println(row.get_f64('X')!)
   	}
   }

Outputs:

.. code-block:: text

   [":memory:".PUBLIC.FOO.X DOUBLE PRECISION]
   1.23
   4.56

Errors are returned as ``SQLState`` values, see :doc:`sqlstate`. More examples
are in the
`examples directory <https://github.com/elliotchance/vsql/tree/main/examples>`_.

.. include:: v-client-library-docs.rst
