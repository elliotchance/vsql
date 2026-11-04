SET SESSION CHARACTERISTICS
===========================

.. contents::

Syntax
------

.. code-block:: text

  SET SESSION CHARACTERISTICS AS TRANSACTION <transaction_mode> [ , <transaction_mode> ]

  <transaction_mode> ::=
      READ ONLY
    | READ WRITE
    | ISOLATION LEVEL <level_of_isolation>
    | DIAGNOSTICS SIZE <number>

``SET SESSION CHARACTERISTICS`` sets the characteristics of every transaction on
this connection that doesn't set its own with :doc:`set-transaction` or
:doc:`start-transaction`. A mode that isn't given stays as it was. They start as
``READ WRITE``, ``SERIALIZABLE`` and a ``DIAGNOSTICS SIZE`` of 100, and they only
last as long as the connection.

It can be used in a transaction, but it only applies from the next one. A
transaction started with ``COMMIT AND CHAIN`` or ``ROLLBACK AND CHAIN`` keeps the
characteristics of the last one instead. Each kind of mode can only be used once
(``42601``). ``READ UNCOMMITTED`` is always ``READ ONLY``, so ``READ WRITE`` can't
be used with it (``42601``).

Examples
--------

.. code-block:: sql

  SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;
  -- msg: SET SESSION CHARACTERISTICS
  -- msg: START TRANSACTION

See Also
--------

- :doc:`set-transaction`
- :doc:`start-transaction`
- :doc:`transactions`
