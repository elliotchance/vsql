UPDATE
======

.. contents::

Syntax
------

.. code-block:: text

  UPDATE <table_name> [ [ AS ] <correlation_name> ]
  SET <column_name> = <value> , ...
  [ WHERE <condition> ]

  UPDATE <table_name>
  SET <column_name> = <value> , ...
  WHERE CURRENT OF <cursor_name>

Changes the rows of a table that match the ``WHERE`` condition. If ``WHERE`` is
not provided, all rows will be updated.

``AS <correlation_name>`` gives the table a *correlation name*. The table must
then be referred to by that name instead (such as ``p.price``), which is useful
when a subquery reads the same table.

A value can be ``DEFAULT``, which is the default value of the column (see
:doc:`create-table`).

A changed row that violates a ``CHECK`` constraint is an error ``23514``, and
none of the rows are updated.

The result (such as ``UPDATE 8``) contains the number of rows matched,
including rows that already had the new values. If no rows are matched,
the result is ``UPDATE 0`` with the completion condition ``02000`` (no data),
see :doc:`sqlstate`.

Examples
--------

.. code-block:: sql

  CREATE TABLE products (name VARCHAR(50), price NUMERIC(10, 2));
  INSERT INTO products (name, price) VALUES ('Coffee', 4.50), ('Bagel', 2.25);
  UPDATE products SET price = price * 2 WHERE name = 'Bagel';
  SELECT * FROM products;
  -- msg: CREATE TABLE 1
  -- msg: INSERT 2
  -- msg: UPDATE 1
  -- NAME: Coffee PRICE: 4.50
  -- NAME: Bagel PRICE: 4.50

Positioned UPDATE
-----------------

``UPDATE ... WHERE CURRENT OF`` updates the row that a cursor is on (see
:doc:`cursors`), and the cursor stays on it.

The SQL standard only allows a positioned ``UPDATE`` in an SQL-client module
(see :doc:`sql-client-modules`). Running it directly is a vsql
extension, flagged by ``V113-01`` (see :doc:`sql-flagging`).

The cursor must be updatable (see :ref:`declare-cursor:Updatable Cursors`).
``FOR UPDATE OF`` limits the columns that a positioned ``UPDATE`` can change. A
positioned ``UPDATE`` also can't change a column that's used by a sort key of
the ``ORDER BY`` (``42601``).

The rows of a cursor are found when it's opened, so a ``FETCH`` returns the row
as it was then, even if it has been changed since. A ``WITH HOLD`` cursor must
be fetched in the current transaction before its row can be changed.

A positioned ``UPDATE`` raises the warning ``01001`` (see :doc:`sqlstate`) if the
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
  UPDATE products SET price = 5.00 WHERE CURRENT OF c;
  CLOSE c;
  COMMIT;

  SELECT * FROM products;
  -- msg: CREATE TABLE 1
  -- msg: INSERT 2
  -- msg: START TRANSACTION
  -- msg: DECLARE CURSOR
  -- msg: OPEN
  -- NAME: Coffee PRICE: 4.50
  -- msg: UPDATE 1
  -- msg: CLOSE
  -- msg: COMMIT
  -- NAME: Coffee PRICE: 5.00
  -- NAME: Bagel PRICE: 2.25

EXPLAIN
-------

The query planner will decide the best strategy to execute the ``UPDATE``. You
can see this plan by using the ``EXPLAIN`` prefix. See :doc:`explain`.

Errors
------

A row that has been changed or deleted by another transaction that hasn't been
committed yet can't be updated. This returns a ``40001`` serialization failure,
and the transaction is rolled back so that it can be retried, see
:doc:`transactions`.

See Also
--------

- :doc:`cursors`
- :doc:`declare-cursor`
- :doc:`delete`
- :doc:`insert`
