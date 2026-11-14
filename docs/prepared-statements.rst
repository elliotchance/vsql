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

A connection also keeps up to 256 of the statements that it has parsed (each up
to 4096 bytes, and preferring the ones that run again), so ``prepare()`` and
``query()`` don't parse the same text again. Only the parsing is kept: a statement is still planned each time it's
executed, so it always uses the current tables and indexes. That's why a
statement that runs many times is faster with dynamic parameters than with
literal values, which make each text different.

A prepared statement can also say which features outside of Core SQL it uses,
see :doc:`sql-flagging`.

The tables and columns that a query, ``INSERT``, ``UPDATE``, ``DELETE`` or
``DECLARE CURSOR`` uses must exist when it's prepared. Otherwise ``prepare()``
returns the error (such as ``42P01`` for a table that doesn't exist), even if
the statement wouldn't touch any rows. A schema statement (such as ``CREATE
TABLE``) is only checked when it's executed, so a statement that uses the table
it creates can only be prepared after it's been executed. The names are found
again each time the statement is executed, so if a table is dropped, the
prepared statement returns an error until the table is created again. Other
errors (such as data types that don't match) are only returned when the
statement is executed, since they can depend on the values of its dynamic
parameters.

``parse()`` returns a statement that's only been parsed, so its names are only
resolved when it's executed (which is what ``query()`` on the ``Connection``
does).

A statement can have many dynamic parameters. This is also what
:doc:`language-c` uses for ``SQLPrepare`` and ``SQLBindParameter``:

.. code-block:: v

   mut stmt := db.prepare('INSERT INTO people (first_name, age) VALUES (?, ?)')!

   stmt.query({
   	'?1': vsql.new_varchar_value('Bob')
   	'?2': vsql.new_integer_value(42)
   })!

A missing value is an error ``42P02``.

A dynamic parameter can't be used where SQL only allows a literal, such as the
row count of ``OFFSET`` and ``FETCH FIRST``.

Data Types
----------

The data type of each dynamic parameter is determined from where it's used
when the statement is prepared, and the value it's given is cast to that type
(like a ``CAST``). For example:

- ``x = ?``, ``x IN (?, ?)`` and ``x BETWEEN ? AND ?`` have the type of ``x``.
- ``INSERT INTO t (x) VALUES (?)`` and ``UPDATE t SET x = ?`` have the type of
  the column ``x``.
- ``CAST(? AS INTEGER)`` is an ``INTEGER``.
- ``x + ?`` (or ``-``, ``*``, ``/``) has the type of ``x``.
- ``x || ?``, ``x LIKE ?`` and the argument of ``CHAR_LENGTH`` are a
  ``CHARACTER VARYING``.
- An operand of ``AND``, ``OR`` and ``NOT``, and a ``WHERE`` or ``HAVING``, is
  a ``BOOLEAN``.
- A value in a ``VALUES``, ``CASE``, ``COALESCE`` or ``NULLIF`` has the type of
  the other values.
- The argument of a function has the type of its parameter, if it's the only
  function with that name and number of arguments.

So ``'42'`` can be the value for ``x = ?`` when ``x`` is an ``INTEGER``, and a
value that can't be cast (such as ``'abc'``) is an error. The type of a
dynamic parameter is returned by ``dynamic_parameter_type()``:

.. code-block:: v

   mut stmt := db.prepare('SELECT * FROM people WHERE age > ?')!
   println(stmt.dynamic_parameter_type(1)?) // INTEGER

A dynamic parameter whose type can't be determined is a syntax error (``42601``)
when the statement is prepared, such as ``VALUES ?``, ``SELECT ?``, ``ABS(?)``
or both of the dynamic parameters in ``? + ?``. Use a ``CAST`` to give it a
type, such as ``SELECT CAST(? AS INTEGER)``.

Only a query, ``INSERT``, ``UPDATE`` and ``DELETE`` are checked like this when
they're prepared. A dynamic parameter in any other statement, or in a
statement that can't be checked yet (such as one from ``parse()`` that uses a
table that doesn't exist yet), has the data type of its value.
