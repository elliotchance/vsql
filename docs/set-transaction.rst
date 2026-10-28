SET TRANSACTION
===============

.. contents::

Syntax
------

.. code-block:: text

  SET TRANSACTION [ DIAGNOSTICS SIZE <number> ]

``SET TRANSACTION`` sets the characteristics of the next transaction, which is
the next :doc:`start-transaction` (without its own characteristics, that's
the default), or the next statement that isn't in a transaction. After that
transaction, the default is used again.

``DIAGNOSTICS SIZE`` is the most warnings that are kept for a statement, which
is between 1 and 100 (and 100 when it's not given). Less than 1 is ``35000``,
a number that isn't an integer is ``42804``, and more than 100 is the warning
``01012`` (and 100 is used).

``SET TRANSACTION`` can't be used in a transaction (``25001``), and doesn't
start one. ``ISOLATION LEVEL``, ``READ ONLY``, ``READ WRITE`` and ``LOCAL``
aren't supported yet.

Examples
--------

.. code-block:: sql

  SET TRANSACTION DIAGNOSTICS SIZE 1;
  VALUES CAST('abcde' AS CHARACTER(3)) || CAST('abcde' AS CHARACTER(3));
  -- msg: SET TRANSACTION
  -- warning 01004: string data, right truncation
  -- COL1: abcabc

See Also
--------

- :doc:`start-transaction`
