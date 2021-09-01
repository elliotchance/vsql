Prepared Statements
===================

A prepared statement is compiled and validated, but not executed. It can then be
executed with a set of host parameters (in the form of ``:name``) to be
substituted into the statement. Each invocation requires all host parameters to
be passed in.

The ``Connection`` provides a ``prepare()`` function, which can be subsequently
executed using ``query()`` with some (or none) host parameters:

.. code-block:: sh

    stmt := db.prepare('SELECT * FROM people WHERE first_name = :name') ?

    for name in ['Bob', 'Jane'] {
        result := stmt.query({
            'name': new_varchar_value(name)
        }) ?

        for row in result {
            println(row.get_string('FIRST_NAME') ?)
        }
    }
