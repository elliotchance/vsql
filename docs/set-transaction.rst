SET TRANSACTION
===============

.. contents::

Syntax
------

.. code-block:: text

  SET [ LOCAL ] TRANSACTION [ <transaction_mode> [ , <transaction_mode> ] ]

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

``SET TRANSACTION`` sets the characteristics of the next transaction, which is
the next :doc:`start-transaction` (without its own characteristics, that's the
default), or the next statement that isn't in a transaction. After that
transaction, the default is used again, which can be changed with
:doc:`set-session-characteristics`. If ``SET TRANSACTION`` is used more than
once, the last one wins. Each kind of mode can only be used once (``42601``).

``SET TRANSACTION`` can't be used in a transaction (``25001``), and doesn't
start one. ``SET CATALOG``, ``SET SCHEMA`` and ``EXPLAIN`` don't start a
transaction either, so they don't use it up.

``SET LOCAL TRANSACTION`` is for a transaction that's on more than one SQL-server.
vsql doesn't have those, so it always fails with ``0A001`` and changes nothing.
It also can't have a ``DIAGNOSTICS SIZE`` (``42601``).

Access Mode
-----------

A ``READ ONLY`` transaction can query the database, but any statement that
changes it fails with ``25006``. That includes ``INSERT``, ``UPDATE``,
``DELETE``, and all of the ``CREATE``, ``ALTER`` and ``DROP`` statements.
``NEXT VALUE FOR`` is allowed, because changes to sequences are not part of a
transaction anyway (they are not undone by ``ROLLBACK``).

``READ WRITE`` is the default, except for ``READ UNCOMMITTED`` which is always
``READ ONLY``.

Isolation Level
---------------

``SERIALIZABLE`` is the default, which stops other connections from committing
until the transaction ends. ``REPEATABLE READ`` sees a snapshot from when the
transaction started instead, and ``READ UNCOMMITTED`` runs the same way as
``READ COMMITTED``. See *Isolation Levels* in :doc:`transactions`.

For a statement that runs on its own, ``READ COMMITTED`` or
``REPEATABLE READ`` means it doesn't wait for other connections'
``SERIALIZABLE`` transactions to finish (but it fails if it needs to commit
changes while one is active).

If a holdable cursor is still open from the previous transaction, the isolation
level can't be changed (``25008``).

Diagnostics Size
----------------

``DIAGNOSTICS SIZE`` is the most warnings that are kept for a statement, which
is between 1 and 100 (and 100 when it's not given). Less than 1 is ``35000``,
a number that isn't an integer is ``42804``, and more than 100 is the warning
``01012`` (and 100 is used).

Examples
--------

.. code-block:: sql

  SET TRANSACTION DIAGNOSTICS SIZE 1;
  VALUES CAST('abcde' AS CHARACTER(3)) || CAST('abcde' AS CHARACTER(3));
  -- msg: SET TRANSACTION
  -- warning 01004: string data, right truncation
  -- COL1: abcabc

  SET TRANSACTION READ ONLY;
  DELETE FROM products;
  DELETE FROM products;
  -- msg: SET TRANSACTION
  -- error 25006: read-only sql transaction: cannot execute DELETE
  -- msg: DELETE 1

  SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
  DELETE FROM products;
  -- msg: SET TRANSACTION
  -- msg: DELETE 0

See Also
--------

- :doc:`start-transaction`
- :doc:`transactions`
