START TRANSACTION
=================

The ``START TRANSACTION`` statement is used to begin a transaction.

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

``BEGIN`` can be used instead of ``START TRANSACTION``:

.. code-block:: text

  BEGIN [ TRANSACTION | WORK ] [ DIAGNOSTICS SIZE <number> ]

This is a vsql extension, not standard SQL, and it's flagged by ``V114-01`` (see
:doc:`sql-flagging`). ``START TRANSACTION`` should be used if the SQL needs to be
portable.

The changes made in a transaction aren't visible to other transactions until
they're applied with ``COMMIT``, and ``ROLLBACK`` discards them instead (see
:doc:`transactions`).

Nested transactions are not supported. ``START TRANSACTION`` when a
transaction is already active is an error ``25001``.

Characteristics
---------------

A ``READ ONLY`` transaction can query the database, but any statement that
changes it fails with ``25006``. Without an access mode, it's ``READ WRITE``
(except for ``READ UNCOMMITTED``, which is always ``READ ONLY``), even after a
:doc:`set-transaction`.

The isolation level decides which changes from other transactions it can see
(see :ref:`transactions:Isolation Levels`). Without one, it's
``SERIALIZABLE``, even after a :doc:`set-transaction`.

``DIAGNOSTICS SIZE`` is the most warnings that are kept for each statement in
the transaction (see :doc:`set-transaction`). Without it, it's 100, even after
a ``SET TRANSACTION``.

Without any of them, the transaction has the characteristics of the connection
(see :doc:`set-session-characteristics`).

Implicit Transactions
---------------------

A statement that isn't in a transaction runs in a transaction of its own, which
is committed when the statement finishes, so its changes are atomic (see
:doc:`transactions`).

Catalogs
--------

A transaction includes every catalog of the connection, including one that is
attached during the transaction. ``COMMIT`` and ``ROLLBACK`` are applied to each
catalog in turn (see :ref:`catalogs-and-schemas:Transactions Across Catalogs`).
A transaction can also be across more than one connection (see
:doc:`connect`).

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
- :doc:`transactions`
