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
that it can be retried. That can only happen with ``READ COMMITTED`` and
``REPEATABLE READ`` transactions, since only one ``SERIALIZABLE`` transaction
(the default) can change the database at a time, see *Isolation Levels*.

The same applies to a table definition that's changed by a transaction that
isn't committed yet (such as with ``CREATE TABLE`` or ``ALTER TABLE``). Another
transaction can't write to that table, or delete or update rows of a table that
a new ``FOREIGN KEY`` references, until it's committed or rolled back. Either
transaction (whichever is second) gets a ``40001``.

A table, index, schema or sequence that another transaction has created isn't
visible until it's committed, but whether it will exist depends on how that
transaction ends. So creating another one with the same name (including with
``IF NOT EXISTS``) also gets a ``40001``, rather than a duplicate name error,
until it's committed or rolled back.

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

Transactions are ``READ WRITE`` by default. A ``READ ONLY`` transaction can be
started with ``START TRANSACTION READ ONLY``, or with :doc:`set-transaction`
before a statement that isn't in a transaction.

Part of a transaction can be rolled back with a :doc:`savepoint`.

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
asks for. vsql has three ways of running a transaction:

- ``SERIALIZABLE`` is the default (it can be changed with the
  ``isolation_level`` of the connection's options, see
  :doc:`v-client-library-docs`). No other connection can commit changes until
  the transaction ends, so nothing it reads can change (other than by itself).
  See below.

- ``REPEATABLE READ`` sees a snapshot of the database from when the
  transaction started. Other connections can still commit changes, but the
  transaction doesn't see them. See below.

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
the other transaction committed. Connections that are waiting take turns, in no
particular order, and a connection that has just finished a transaction has to
wait with them.

That means a program that uses two connections to the same file in one thread
can't start a transaction on one while the other has one, since the other
can't finish while it's waiting. It will fail with ``40001`` after the timeout.

A query through ``Connection.direct`` (or ``vsql cli -autocommit=false``) that
starts a transaction doesn't wait or stop other connections, because the database
may only be readable. If another transaction has ended since the first query of
that transaction, the next statement fails with a ``40001`` serialization failure
and the transaction is rolled back, even if the other transaction was rolled back
too. That lasts until a statement changes something, which waits like any other
transaction and then holds up the others.

Other connections can always read (outside of a transaction, or in a
``READ COMMITTED`` one). ``NEXT VALUE FOR`` is not part of a transaction, so
it doesn't wait either, unless the ``SERIALIZABLE`` transaction has changed the
database (see below).

A ``READ COMMITTED`` or ``REPEATABLE READ`` transaction doesn't wait, and it
can change the database while a ``SERIALIZABLE`` transaction is active, but it
can't commit those changes until the ``SERIALIZABLE`` transaction ends.
Committing fails with a ``40001`` serialization failure straight away, and the
transaction is rolled back.

Once a ``SERIALIZABLE`` transaction has changed the database while no other
transaction was active, it keeps its changes in memory (up to 64 MiB, after
which they're written and it starts again) and writes them to the file when it
ends, which is a lot faster than writing each statement. A ``ROLLBACK`` just
forgets them, unless some were already written (or it used ``NEXT VALUE FOR``,
which a rollback doesn't undo). Until then, any statement on another connection that
changes the database (including ``NEXT VALUE FOR``) waits for it to end, up to
the ``lock_timeout``, the same as another ``SERIALIZABLE`` transaction.

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

REPEATABLE READ
^^^^^^^^^^^^^^^

A ``REPEATABLE READ`` transaction uses snapshot isolation. It takes a snapshot
when it starts, and every statement sees the rows (and tables) that had been
committed by then, as well as its own changes. Rows that other transactions
change, insert or delete after that aren't seen, even once they're committed.
Unlike ``SERIALIZABLE``, it doesn't wait for other transactions, and other
connections can still commit while it's active.

The snapshot is kept in the database file, so on a database that can only be
read (such as one that needs a newer version of vsql to be changed) it can't
take one. Its statements fail with a ``40001`` instead if another transaction
has ended since it started (see :doc:`mvcc`).

.. code-block:: sql

  -- From connection 1:
  START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
  SELECT * FROM products;
  -- NAME: Espresso PRICE: 4

  -- From connection 2 (this doesn't wait):
  UPDATE products SET price = 5;
  -- msg: UPDATE 1

  -- From connection 1:
  SELECT * FROM products;
  -- NAME: Espresso PRICE: 4
  COMMIT;

  SELECT * FROM products;
  -- NAME: Espresso PRICE: 5

The first transaction to commit a change to a row wins. Updating or deleting a
row that another transaction has changed since the snapshot was taken (or is
changing) fails with a ``40001`` serialization failure, and the transaction is
rolled back so that it can be retried. The same goes for:

- Inserting a row with a ``PRIMARY KEY`` (or ``UNIQUE`` value) that another
  transaction has inserted since then.
- A ``FOREIGN KEY`` that refers to a row that has been inserted or deleted
  since then. Constraints are always checked against the latest rows.
- Writing to a table whose definition (or indexes) has changed since then.
- Changing the schema (such as ``CREATE TABLE``) after another transaction has
  changed it.
- A sequence that has been dropped or created since then. ``NEXT VALUE FOR``
  isn't part of any transaction, so it always uses the latest value.

Snapshot isolation prevents all three phenomena of the standard, but it still
isn't serializable. Two transactions can each read rows that the other one
changes, and both commit (a *write skew*), which can't happen if they run one
after the other. For example, if two transactions check that at least one
doctor is on call, and each takes a different doctor off call, then nobody is
on call. That isn't one of the phenomena that ``REPEATABLE READ`` has to
prevent, which is why it isn't used for ``SERIALIZABLE``.

When a transaction commits, it removes the versions of rows that it replaced or
deleted, unless a ``REPEATABLE READ`` transaction can still see them. Those are
kept until it ends (see :doc:`mvcc`). Only two versions of a row can exist at a
time, so until then, another transaction that tries to change the row again
gets a ``40001``.

A query through ``Connection.direct`` that starts a ``REPEATABLE READ``
transaction doesn't take a snapshot yet, the same as for ``SERIALIZABLE`` (see
above): the next statement fails with a ``40001`` if another transaction has
ended since the first query. The snapshot is taken when a statement changes
something.

See Also
--------

- :doc:`commit`
- :doc:`mvcc`
- :doc:`rollback`
- :doc:`set-transaction`
- :doc:`start-transaction`
