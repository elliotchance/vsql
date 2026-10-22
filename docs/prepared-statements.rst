Prepared Statements
===================

A prepared statement is parsed and validated once, but not executed. It can then
be executed many times with different values for its host parameters (in the
form of ``:name``). Each execution must provide a value for every host
parameter.

The ``Connection`` provides a ``prepare()`` function, and the statement it
returns is executed with ``query()``:

.. code-block:: v

   mut stmt := db.prepare('SELECT * FROM people WHERE first_name = :name')!

   for name in ['Bob', 'Jane'] {
   	result := stmt.query({
   		'name': vsql.new_varchar_value(name)
   	})!

   	for row in result {
   		println(row.get_string('FIRST_NAME')!)
   	}
   }

A host parameter name can't be a reserved word (see :doc:`keywords`), so use
``:max_price`` rather than ``:max``.

A missing host parameter is an error ``42P02``.
