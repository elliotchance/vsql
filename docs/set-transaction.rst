SET TRANSACTION
===============

.. contents::

Syntax
------

.. code-block:: text

  SET TRANSACTION { READ ONLY | READ WRITE }

``SET TRANSACTION`` sets the access mode of the next transaction. It's an error
(``25001``) to use it inside a transaction.

The next transaction is either started by :doc:`start-transaction` (unless it
sets its own access mode), or is the transaction of the next statement that
runs on its own, outside of ``START TRANSACTION``. ``SET CATALOG`` and
``SET SCHEMA`` don't start a transaction, and nor does ``EXPLAIN``. After that
transaction ends, the access mode goes back to ``READ WRITE``. If
``SET TRANSACTION`` is used more than once, the last one wins.

A ``READ ONLY`` transaction can query the database, but any statement that
changes it fails with ``25006``. That includes ``INSERT``, ``UPDATE``,
``DELETE``, and all of the ``CREATE``, ``ALTER`` and ``DROP`` statements.
``NEXT VALUE FOR`` is allowed, because changes to sequences are not part of a
transaction anyway (they are not undone by ``ROLLBACK``).

``READ WRITE`` is the default.

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

See Also
--------

- :doc:`start-transaction`
- :doc:`transactions`
