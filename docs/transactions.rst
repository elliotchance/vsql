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

The same applies to a table definition that's changed by a transaction that
isn't committed yet (such as with ``CREATE TABLE`` or ``ALTER TABLE``). Another
transaction can't write to that table, or delete or update rows of a table that
a new ``FOREIGN KEY`` references, until it's committed or rolled back. Either
transaction (whichever is second) gets a ``40001``.

A statement that isn't inside a ``START TRANSACTION`` runs in a transaction of
its own, which is committed when the statement finishes. With
``vsql cli -autocommit=false`` (which follows the SQL standard), a statement
starts a transaction that stays active until it's committed or rolled back
instead (see :doc:`cli`).

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
