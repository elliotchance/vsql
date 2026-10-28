SET TRANSACTION
===============

.. contents::

Syntax
------

.. code-block:: text

  SET TRANSACTION ISOLATION LEVEL <level_of_isolation>

  <level_of_isolation> ::=
      READ UNCOMMITTED
    | READ COMMITTED
    | REPEATABLE READ
    | SERIALIZABLE

``SET TRANSACTION`` sets the isolation level of the next transaction. It's an
error (``25001``) to use it inside a transaction.

The next transaction is either started by :doc:`start-transaction` (unless it
sets its own characteristics), or is the transaction of the next statement that
runs on its own, outside of ``START TRANSACTION``. ``SET CATALOG`` and
``SET SCHEMA`` don't start a transaction, and nor does ``EXPLAIN``. After that
transaction ends, the isolation level goes back to the default. If
``SET TRANSACTION`` is used more than once, the last one wins.

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

  SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;
  SELECT * FROM products;
  COMMIT;
  -- msg: SET TRANSACTION
  -- msg: START TRANSACTION
  -- NAME: Espresso PRICE: 4
  -- msg: COMMIT

  SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
  DELETE FROM products;
  -- msg: SET TRANSACTION
  -- msg: DELETE 1

See Also
--------

- :doc:`start-transaction`
- :doc:`transactions`
