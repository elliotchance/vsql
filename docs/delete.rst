DELETE
======

.. contents::

Syntax
------

.. code-block:: text

  DELETE FROM <table_name> [ [ AS ] <correlation_name> ]
  [ WHERE <condition> ]

  DELETE FROM <table_name> WHERE CURRENT OF <cursor_name>

Deletes the rows of a table that match the ``WHERE`` condition. If ``WHERE`` is
not provided, all rows will be deleted.

``AS <correlation_name>`` gives the table a *correlation name*. The table must
then be referred to by that name instead (such as ``p.price``), which is useful
when a subquery reads the same table.

The result (such as ``DELETE 3``) contains the number of rows deleted. If no
rows are deleted, the result is ``DELETE 0`` with the completion condition
``02000`` (no data), see :doc:`sqlstate`.

Examples
--------

.. code-block:: sql

  CREATE TABLE products (name VARCHAR(50), price FLOAT);
  INSERT INTO products (name, price) VALUES ('Coffee', 4.5e0), ('Bagel', 2.25e0);
  DELETE FROM products WHERE price < 3e0;
  SELECT * FROM products;
  -- msg: CREATE TABLE 1
  -- msg: INSERT 2
  -- msg: DELETE 1
  -- NAME: Coffee PRICE: 4.5e0

Positioned DELETE
-----------------

``DELETE ... WHERE CURRENT OF`` deletes the row that a cursor is on (see
:doc:`cursors`). The cursor is then before the next row, so it has to be
fetched again (see :doc:`fetch`) before another positioned ``DELETE`` or
``UPDATE``.

The SQL standard only allows a positioned ``DELETE`` in an SQL-client module
(see :doc:`sql-client-modules`). Running it directly is a vsql
extension, flagged by ``V112-01`` (see :doc:`sql-flagging`).

The cursor must be updatable (see :ref:`declare-cursor:Updatable Cursors`).
The rows of a cursor are found when it's opened, so a ``FETCH`` returns the row
as it was then, even if it has been changed since. A ``WITH HOLD`` cursor must
be fetched in the current transaction before its row can be deleted.

A positioned ``DELETE`` raises the warning ``01001`` (see :doc:`sqlstate`) if the
current row has been changed by another statement since the cursor was opened.
A row that has been updated is still changed. A row that has been deleted can't
be, so the statement changes no rows. The warning is also raised by a searched
``DELETE`` or ``UPDATE`` (or a referential action) that changes a row that a
positioned ``UPDATE`` of a cursor that's still open has already changed. That's
only for the cursors of the same connection.

.. code-block:: sql

  CREATE TABLE products (name VARCHAR(50), price NUMERIC(10, 2));
  INSERT INTO products (name, price) VALUES ('Coffee', 4.50), ('Bagel', 2.25);

  START TRANSACTION;
  DECLARE c CURSOR FOR SELECT * FROM products;
  OPEN c;
  FETCH c;
  DELETE FROM products WHERE CURRENT OF c;
  CLOSE c;
  COMMIT;

  SELECT * FROM products;
  -- msg: CREATE TABLE 1
  -- msg: INSERT 2
  -- msg: START TRANSACTION
  -- msg: DECLARE CURSOR
  -- msg: OPEN
  -- NAME: Coffee PRICE: 4.50
  -- msg: DELETE 1
  -- msg: CLOSE
  -- msg: COMMIT
  -- NAME: Bagel PRICE: 2.25

EXPLAIN
-------

The query planner will decide the best strategy to execute the ``DELETE``. You
can see this plan by using the ``EXPLAIN`` prefix. See :doc:`explain`.

Errors
------

A row that has been changed or deleted by another transaction that hasn't been
committed yet can't be deleted. This returns a ``40001`` serialization failure,
and the transaction is rolled back so that it can be retried, see
:doc:`transactions`.

See Also
--------

- :doc:`cursors`
- :doc:`declare-cursor`
- :doc:`insert`
- :doc:`update`
