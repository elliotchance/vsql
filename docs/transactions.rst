Transactions
============

vsql supports transactions through the :doc:`start-transaction`, :doc:`commit`
and :doc:`rollback` statements.

Internally, transactions use :doc:`mvcc`, so many connections (including ones
in different processes) can each have a transaction open on the same database
file at the same time. A statement only locks the file while it runs, rather
than for the whole transaction. This is different from SQLite, where a write
transaction holds an exclusive lock on the file until it is committed or rolled
back.

Transactions use the ``READ COMMITTED`` isolation level: a statement sees the
changes that other transactions have committed before it started. Two
transactions can't change the same row at the same time. The second one gets a
``40001`` serialization failure, and its transaction is rolled back so that it
can be retried.

A statement that isn't inside a ``START TRANSACTION`` runs in a transaction of
its own, which is committed when the statement finishes.

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

Transactions are ``READ WRITE`` by default. A ``READ ONLY`` transaction can be
started with ``START TRANSACTION READ ONLY``, or with :doc:`set-transaction`
before the next transaction (including the transaction of a single statement).

See Also
--------

- :doc:`commit`
- :doc:`mvcc`
- :doc:`rollback`
- :doc:`set-transaction`
- :doc:`start-transaction`
