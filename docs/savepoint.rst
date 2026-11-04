SAVEPOINT
=========

A savepoint marks a point in a transaction that it can be rolled back to, without
ending the transaction.

.. contents::

Syntax
------

.. code-block:: text

  SAVEPOINT <name>

  RELEASE SAVEPOINT <name>

  ROLLBACK [ WORK ] [ AND NO CHAIN ] TO SAVEPOINT <name>

``ROLLBACK TO SAVEPOINT`` cancels every change made since the savepoint, and
destroys the savepoints after it. The savepoint itself stays, so it can be rolled
back to again. It's still the same transaction, which must end with a
:doc:`commit` or :doc:`rollback`. Values from sequences aren't given back, because
sequences aren't part of a transaction. Other connections can't see any of this,
since the changes weren't committed.

A cursor that isn't holdable is closed by ``ROLLBACK TO SAVEPOINT``. A holdable
cursor stays open, with the rows it already has.

``RELEASE SAVEPOINT`` destroys the savepoint and the ones after it, and keeps the
changes. Using the name of a savepoint that already exists destroys the old one,
but not the ones after it. A name that doesn't exist is ``3B001``. There's no limit
to the number of savepoints.

``COMMIT``, ``ROLLBACK`` and a serialization failure destroy every savepoint. A
statement outside of a transaction is its own transaction, so ``SAVEPOINT`` isn't
useful there: the savepoint ends with it, and a ``RELEASE SAVEPOINT`` afterwards is
``3B001``. With ``vsql cli -autocommit=false``, it starts a transaction.

The changes are kept in memory until the transaction ends, so a large transaction
with a savepoint uses more memory.

Examples
--------

.. code-block:: sql

  CREATE TABLE products (name VARCHAR(50));
  START TRANSACTION;
  INSERT INTO products (name) VALUES ('Espresso');
  SAVEPOINT before_coffee;
  INSERT INTO products (name) VALUES ('Coffee Machine');
  ROLLBACK TO SAVEPOINT before_coffee;
  COMMIT;
  SELECT * FROM products;
  -- msg: CREATE TABLE 1
  -- msg: START TRANSACTION
  -- msg: INSERT 1
  -- msg: SAVEPOINT
  -- msg: INSERT 1
  -- msg: ROLLBACK
  -- msg: COMMIT
  -- NAME: Espresso

See Also
--------

- :doc:`commit`
- :doc:`rollback`
- :doc:`transactions`
