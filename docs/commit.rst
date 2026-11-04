COMMIT
======

The ``COMMIT`` statement is used to apply all transaction changes.

All statements within a transaction will not be visible to other transactions
until all changes are applied with ``COMMIT`` or all changes are discarded with
``ROLLBACK``.

Nested transactions are not supported. Outside of a transaction, ``COMMIT`` and
``ROLLBACK`` succeed and do nothing, since every statement is committed when it
finishes.

Each deferred constraint (see "Deferrable Constraints" in :doc:`create-table`)
is checked first. If one isn't satisfied, the whole transaction is rolled back
and the error is ``40002``.

``AND CHAIN`` starts a new transaction straight away, with the same access mode,
isolation level and ``DIAGNOSTICS SIZE``. Every constraint is immediate in it,
because of the check above, until :doc:`set-constraints` is used. A
``COMMIT`` that fails doesn't start one, and nor does ``COMMIT AND CHAIN`` outside
of a transaction. ``AND NO CHAIN`` is the same as leaving it out.

.. contents::

Syntax
------

.. code-block:: text

  COMMIT [ WORK ] [ AND [ NO ] CHAIN ]

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

- :doc:`start-transaction`
- :doc:`rollback`
- :doc:`set-constraints`
