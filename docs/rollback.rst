ROLLBACK
========

The ``ROLLBACK`` statement is used to discard all transaction changes.

.. contents::

Syntax
------

.. code-block:: text

  ROLLBACK [ WORK ] [ AND [ NO ] CHAIN ]

  ROLLBACK [ WORK ] [ AND NO CHAIN ] TO SAVEPOINT <name>

These can be used instead. They are vsql extensions, not standard SQL, and they
are flagged by ``V116-01`` and ``V116-02`` (see :doc:`sql-flagging`):

.. code-block:: text

  ROLLBACK TRANSACTION

  ABORT [ TRANSACTION | WORK ]

The changes made in a transaction aren't visible to other transactions until
they're applied with ``COMMIT``, and ``ROLLBACK`` discards them instead (see
:doc:`transactions`).

Nested transactions are not supported. Outside of a transaction, ``COMMIT`` and
``ROLLBACK`` succeed and do nothing, since every statement is committed when it
finishes.

``AND CHAIN`` starts a new transaction straight away, with the same access mode,
isolation level, ``DIAGNOSTICS SIZE`` and constraint modes. ``ROLLBACK AND CHAIN``
outside of a transaction doesn't start one. ``AND NO CHAIN`` is the same as
leaving it out.

``TO SAVEPOINT`` only rolls back part of the transaction, see :doc:`savepoint`. It
can't be used with ``AND CHAIN`` (``42601``).

A statement that fails doesn't end the transaction, only its own changes are
discarded. An error of class ``40`` (such as ``40001``) rolls back the whole
transaction. See :ref:`errors-and-warnings:Errors in a Transaction`.

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
- :doc:`savepoint`
- :doc:`transactions`
