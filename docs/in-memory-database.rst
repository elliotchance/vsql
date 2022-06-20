In Memory Database
==================

Opening a database with the special file name ":memory:" will use an entirely
in-memory database:

.. code-block:: text

   mut db := vsql.open(':memory:') ?
