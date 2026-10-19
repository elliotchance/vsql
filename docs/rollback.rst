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

Errors
------

If a statement in a transaction fails, only the changes made by that statement
are discarded. The transaction stays active, so the statements before it are
kept, and the transaction can continue or end with ``COMMIT`` or ``ROLLBACK``.

The exception is an error in class ``40`` (transaction rollback), such as
``40001`` (serialization failure). The whole transaction is rolled back and is
no longer active.

.. code-block:: sql

  START TRANSACTION;
  INSERT INTO products (name, price) VALUES ('Kettle', 30);
  INSERT INTO products (name, price) VALUES ('Toaster', 30 / 0);
  -- error 22012: division by zero
  COMMIT;

  SELECT name FROM products;
  -- NAME: Kettle

See Also
--------

- :doc:`start-transaction`
- :doc:`commit`
