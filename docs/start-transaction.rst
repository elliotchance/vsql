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

  START TRANSACTION [ DIAGNOSTICS SIZE <number> ]

``DIAGNOSTICS SIZE`` is the most warnings that are kept for each statement in
the transaction (see :doc:`set-transaction`). Without it, it's 100, even after
a ``SET TRANSACTION``.

Implicit Transactions
---------------------

When a transaction is not explicitly used, each statement will be automatically
wrapped in an implicit transaction. Internally this is important because any
statements that may make changes (such as a ``DELETE`` that removes multiple
rows) should seem atomic to all other readers and writers.

Catalogs
--------

A transaction includes every catalog, including one that is attached during the
transaction. However, transaction isolation is not guaranteed across catalogs
for all operations. And ``COMMIT`` and ``ROLLBACK`` are applied to each catalog
in turn, so they may independently succeed or fail.

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
