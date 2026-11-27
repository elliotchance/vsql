SQL Statements
==============

Each statement has its own page, in alphabetical order. Some statements are
described on the page of a related statement:

- ``BEGIN`` is on :doc:`start-transaction`.
- ``END`` is on :doc:`commit`, and ``ABORT`` is on :doc:`rollback`.
- ``RELEASE SAVEPOINT`` and ``ROLLBACK TO SAVEPOINT`` are on :doc:`savepoint`.
- ``TABLE`` and the ``UNION``, ``EXCEPT`` and ``INTERSECT`` of queries are on
  :doc:`select`.

The statements that are only used in an SQL-client module, such as
``PREPARE`` and ``EXECUTE``, are described in :doc:`sql-client-modules`.

.. toctree::
   :maxdepth: 1

   alter-sequence.rst
   alter-table.rst
   close.rst
   commit.rst
   connect.rst
   create-index.rst
   create-schema.rst
   create-sequence.rst
   create-table.rst
   create-view.rst
   declare-cursor.rst
   delete.rst
   disconnect.rst
   drop-index.rst
   drop-schema.rst
   drop-sequence.rst
   drop-table.rst
   drop-view.rst
   explain.rst
   fetch.rst
   insert.rst
   open.rst
   rollback.rst
   savepoint.rst
   select.rst
   set-catalog.rst
   set-connection.rst
   set-constraints.rst
   set-names.rst
   set-schema.rst
   set-session-characteristics.rst
   set-time-zone.rst
   set-transaction.rst
   start-transaction.rst
   update.rst
   vacuum.rst
   values.rst
