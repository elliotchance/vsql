START TRANSACTION
=================

The ``START TRANSACTION`` statement is used to begin a transaction.

All statements within a transaction will not be visible to other transactions
until all changes are applied with ``COMMIT`` or all changes are discarded with
``ROLLBACK``.

Nested transactions are not supported. Attempting to run ``START TRANSACTION``
when already in a transaction will result in an error.

.. contents::

Syntax
------

.. code-block:: text

  START TRANSACTION

Implicit Transactions
---------------------

When a transaction is not explicitely used, each statement will be automatically
wrapped in an implicit transaction. Internally this is important becuase any
statements that may make changes (such as a ``DELETE`` that removes multiple
rows) should seem atomic to all other readers and writers.

Examples
--------

.. code-block:: sql

  -- From connection 1:
  START TRANSACTION;

  INSERT INTO products (name, price)
  VALUES ('Coffee Machine', 150);

  -- From connection 2:
  SELECT * FROM products;
  -- empty

  -- From connection 1:
  COMMIT;

  -- From connection 2:
  SELECT * FROM products;
  -- NAME: Coffee Machine PRICE: 150

See Also
--------

- :doc:`commit`
- :doc:`rollback`
