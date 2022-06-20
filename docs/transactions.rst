Transactions
============

vsql supports transactions through the :doc:`start-transaction`, :doc:`commit`
and :doc:`rollback` statements.

Internally, transactions use :doc:`mvcc` that allow multiple connections to both
read and write to the database at the same time. This is different from SQLite
which serializes all transactions by having a write transaction have an
exclusive write lock on the file until it is comitted or rolled back.

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
- :doc:`mvcc`
- :doc:`rollback`
- :doc:`start-transaction`
