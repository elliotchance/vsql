In Memory Database
==================

Opening a database with the special file name ``:memory:`` will use an entirely
in-memory database. Nothing is written to disk, and the database is gone when
the connection is closed:

.. code-block:: v

   mut db := vsql.open(':memory:')!

The CLI accepts it as well:

.. code-block:: sh

   vsql cli :memory:

The name of the catalog (see :doc:`set-catalog`) is ``:memory:``.
