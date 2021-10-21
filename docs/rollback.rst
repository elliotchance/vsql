ROLLBACK
========

The ``ROLLBACK`` statement is used to discard all transaction changes.

All statements within a transaction will not be visible to other transactions
until all changes are applied with ``COMMIT`` or all changes are discarded with
``ROLLBACK``.

Nested transactions are not supported and ``COMMIT`` or ``ROLLBACK`` cannot be
used when not in a transaction, otherwise an error is returned.

.. contents::

Syntax
------

.. code-block:: text

  ROLLBACK [ WORK ]

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
  ROLLBACK;

  -- From connection 2:
  SELECT * FROM products;
  -- empty

See Also
--------

- :doc:`start-transaction`
- :doc:`commit`
