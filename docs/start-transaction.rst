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

  START TRANSACTION [ <transaction_mode> [ , <transaction_mode> ] ]

  <transaction_mode> ::=
      READ ONLY
    | READ WRITE
    | ISOLATION LEVEL <level_of_isolation>
    | DIAGNOSTICS SIZE <number>

  <level_of_isolation> ::=
      READ UNCOMMITTED
    | READ COMMITTED
    | REPEATABLE READ
    | SERIALIZABLE

Characteristics
---------------

A ``READ ONLY`` transaction can query the database, but any statement that
changes it fails with ``25006``. Without an access mode, it's ``READ WRITE``
(except for ``READ UNCOMMITTED``, which is always ``READ ONLY``), even after a
:doc:`set-transaction`.

The isolation level decides which changes from other transactions it can see
(see *Isolation Levels* in :doc:`transactions`). Without one, it's
``SERIALIZABLE``, even after a :doc:`set-transaction`.

``DIAGNOSTICS SIZE`` is the most warnings that are kept for each statement in
the transaction (see :doc:`set-transaction`). Without it, it's 100, even after
a ``SET TRANSACTION``.

Without any of them, the transaction has the characteristics of the connection
(see :doc:`set-session-characteristics`).

``BEGIN`` can be used instead of ``START TRANSACTION``:

.. code-block:: text

  BEGIN [ TRANSACTION | WORK ] [ DIAGNOSTICS SIZE <number> ]

This is a vsql extension, not standard SQL, and it's flagged by ``V114-01`` (see
:doc:`sql-flagging`). ``START TRANSACTION`` should be used if the SQL needs to be
portable.

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
- :doc:`set-transaction`
