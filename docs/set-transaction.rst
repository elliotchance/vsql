SET TRANSACTION
===============

.. contents::

Syntax
------

.. code-block:: text

  SET TRANSACTION <transaction_mode> [ , <transaction_mode> ]

  <transaction_mode> ::=
      READ ONLY
    | READ WRITE
    | ISOLATION LEVEL <level_of_isolation>

  <level_of_isolation> ::=
      READ UNCOMMITTED
    | READ COMMITTED
    | REPEATABLE READ
    | SERIALIZABLE

``SET TRANSACTION`` sets the access mode and isolation level of the next
transaction. It's an error (``25001``) to use it inside a transaction. Each of
them can only be given once, in any order, and the ones that aren't given have
their defaults.

The next transaction is either started by :doc:`start-transaction` (unless it
sets its own characteristics), or is the transaction of the next statement that
runs on its own, outside of ``START TRANSACTION``. ``SET CATALOG`` and
``SET SCHEMA`` don't start a transaction, and nor does ``EXPLAIN``. After that
transaction ends, the characteristics go back to their defaults. If
``SET TRANSACTION`` is used more than once, the last one wins.

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

``SERIALIZABLE`` is the default. ``REPEATABLE READ`` runs the same way as
``SERIALIZABLE``, which stops other connections from committing until the
transaction ends, and ``READ UNCOMMITTED`` runs the same way as
``READ COMMITTED``. See *Isolation Levels* in :doc:`transactions`.

For a statement that runs on its own, ``READ COMMITTED`` means it doesn't wait
for other connections' ``SERIALIZABLE`` transactions to finish (but it fails if
it needs to commit changes while one is active).

Examples
--------

.. code-block:: sql

  SET TRANSACTION READ ONLY;
  START TRANSACTION;
  SELECT * FROM products;
  INSERT INTO products (name, price) VALUES ('Coffee Machine', 150);
  COMMIT;
  -- msg: SET TRANSACTION
  -- msg: START TRANSACTION
  -- NAME: Espresso PRICE: 4
  -- error 25006: read-only sql transaction: cannot execute INSERT
  -- msg: COMMIT

  SET TRANSACTION READ ONLY;
  DELETE FROM products;
  DELETE FROM products;
  -- msg: SET TRANSACTION
  -- error 25006: read-only sql transaction: cannot execute DELETE
  -- msg: DELETE 1

  SET TRANSACTION ISOLATION LEVEL SERIALIZABLE, READ ONLY;
  START TRANSACTION;
  -- msg: SET TRANSACTION
  -- msg: START TRANSACTION

See Also
--------

- :doc:`start-transaction`
- :doc:`transactions`
