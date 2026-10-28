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

Two transactions can't change the same row at the same time. The second one
gets a ``40001`` serialization failure, and its transaction is rolled back so
that it can be retried. That can only happen with ``READ COMMITTED``
transactions, since only one ``SERIALIZABLE`` transaction (the default) can
change the database at a time, see *Isolation Levels*.

The same applies to a table definition that's changed by a transaction that
isn't committed yet (such as with ``CREATE TABLE`` or ``ALTER TABLE``). Another
transaction can't write to that table, or delete or update rows of a table that
a new ``FOREIGN KEY`` references, until it's committed or rolled back. Either
transaction (whichever is second) gets a ``40001``.

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

Isolation Levels
----------------

The isolation level of a transaction is set the same way, such as
``START TRANSACTION ISOLATION LEVEL SERIALIZABLE``. The SQL standard defines
four levels by which of these can happen when transactions run at the same
time:

.. list-table::
  :header-rows: 1

  * - Level
    - Dirty read
    - Non-repeatable read
    - Phantom

  * - ``READ UNCOMMITTED``
    - Possible
    - Possible
    - Possible

  * - ``READ COMMITTED``
    - Not possible
    - Possible
    - Possible

  * - ``REPEATABLE READ``
    - Not possible
    - Not possible
    - Possible

  * - ``SERIALIZABLE``
    - Not possible
    - Not possible
    - Not possible

A *dirty read* is reading a change that another transaction hasn't committed
(and may roll back). A *non-repeatable read* is reading the same row twice and
getting a different value, because another transaction changed it and committed
in between. A *phantom* is a row that appears or disappears when a query is
repeated, because another transaction inserted or deleted it.

A database may always run a transaction at a stricter level than the one it
asks for. vsql only has two ways of running a transaction:

- ``REPEATABLE READ`` and ``SERIALIZABLE`` run as ``SERIALIZABLE``, which is
  the default. No other connection can commit changes until the transaction
  ends, so nothing it reads can change (other than by itself). See below.

- ``READ UNCOMMITTED`` and ``READ COMMITTED`` run as ``READ COMMITTED``: each
  statement sees the changes that other transactions committed before it
  started. Changes that haven't been committed are never visible.

``READ UNCOMMITTED`` is always ``READ ONLY`` (it's a syntax error to give it as
``READ WRITE``). The other levels are ``READ WRITE`` by default.

SERIALIZABLE
^^^^^^^^^^^^

Only one ``READ WRITE`` transaction can be active at a time. A statement that
changes the database outside of a transaction is a transaction of its own, so
it counts as one too. Several ``READ ONLY`` transactions can be active at the
same time, but not at the same time as a ``READ WRITE`` one.

A transaction that can't start yet waits for the other one to finish. It waits
for up to the ``lock_timeout`` of the connection (5 seconds by default, see
:doc:`v-client-library-docs`), and then fails with a ``40001`` serialization
failure. It waits before it reads anything, so it sees all of the changes that
the other transaction committed.

That means a program that uses two connections to the same file in one thread
can't start a transaction on one while the other has one, since the other
can't finish while it's waiting. It will fail with ``40001`` after the timeout.

Other connections can always read (outside of a transaction, or in a
``READ COMMITTED`` one). ``NEXT VALUE FOR`` is not part of a transaction, so
it doesn't wait either.

A ``READ COMMITTED`` transaction doesn't wait, and it can change the database
while a ``SERIALIZABLE`` transaction is active, but it can't commit those
changes until the ``SERIALIZABLE`` transaction ends. Committing fails with a
``40001`` serialization failure straight away, and the transaction is rolled
back.

This makes ``REPEATABLE READ`` stricter (and slower when there are other
connections changing the database) than it needs to be, so it may not always
work the same way.

.. code-block:: sql

  -- From connection 1:
  START TRANSACTION;
  SELECT * FROM products;
  -- NAME: Espresso PRICE: 4

  -- From connection 2 (this waits until connection 1 commits):
  UPDATE products SET price = 5;

  -- From connection 1:
  SELECT * FROM products;
  -- NAME: Espresso PRICE: 4
  COMMIT;

  -- From connection 2:
  -- msg: UPDATE 1

See Also
--------

- :doc:`commit`
- :doc:`mvcc`
- :doc:`rollback`
- :doc:`set-transaction`
- :doc:`start-transaction`
