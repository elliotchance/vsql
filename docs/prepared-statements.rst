Prepared Statements
===================

A prepared statement is parsed and validated once, but not executed. It can then
be executed many times with different values for its dynamic parameters (each
``?`` in the statement).

A dynamic parameter is named by its position in the statement: the first ``?``
is ``?1``, the second is ``?2``, etc. Each execution must provide a value for
every dynamic parameter.

The ``Connection`` provides a ``prepare()`` function, and the statement it
returns is executed with ``query()``:

.. code-block:: v

   mut stmt := db.prepare('SELECT * FROM people WHERE first_name = ?')!

   for name in ['Bob', 'Jane'] {
   	result := stmt.query({
   		'?1': vsql.new_varchar_value(name)
   	})!

   	for row in result {
   		println(row.get_string('FIRST_NAME')!)
   	}
   }

A statement can have many dynamic parameters. This is also what
:doc:`language-c` uses for ``SQLPrepare`` and ``SQLBindParameter``:

.. code-block:: v

   mut stmt := db.prepare('INSERT INTO people (first_name, age) VALUES (?, ?)')!

   stmt.query({
   	'?1': vsql.new_varchar_value('Bob')
   	'?2': vsql.new_integer_value(42)
   })!

The data type of a dynamic parameter is the data type of its value. A missing
value is an error ``42P02``.

A dynamic parameter can't be used where SQL only allows a literal, such as the
row count of ``OFFSET`` and ``FETCH FIRST``.
