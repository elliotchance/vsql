Errors and Warnings
===================

.. contents::

Every statement ends with a condition, which has a five character SQLSTATE
(listed in :doc:`sqlstate`). An *exception* (any class other than ``00``,
``01`` and ``02``) is an error: the statement failed. A *completion condition*
is a warning (class ``01``) or no data (class ``02``): the statement succeeded,
but something happened that you may want to know about.

Errors in a Transaction
-----------------------

A statement that fails has no effect, even if it had already changed some of
the rows. The transaction that it's in (see :doc:`transactions`) stays active,
with everything that the statements before it did, so it can still be
committed or rolled back:

.. code-block:: sql

  CREATE TABLE t (x INT, y INT);
  INSERT INTO t (x, y) VALUES (10, 2), (20, 0);
  -- msg: CREATE TABLE 1
  -- msg: INSERT 2

  START TRANSACTION;
  INSERT INTO t (x, y) VALUES (30, 3);
  UPDATE t SET x = x / y;
  SELECT * FROM t;
  -- msg: START TRANSACTION
  -- msg: INSERT 1
  -- error 22012: division by zero
  -- X: 10 Y: 2
  -- X: 20 Y: 0
  -- X: 30 Y: 3

  COMMIT;
  -- msg: COMMIT

The ``UPDATE`` changed the first row before it failed on the second one, but
that change was undone, and the ``INSERT`` before it was committed. A syntax
error, or any other error, is the same. The only exception is a sequence: a
value that a failed statement took with ``NEXT VALUE FOR`` isn't given out
again.

The errors of class ``40`` (transaction rollback) are different. They roll back
the whole transaction, so nothing that it changed is kept, and the
transaction has ended:

- ``40001`` (serialization failure) is when the transaction conflicts with
  another one (see :ref:`transactions:Isolation Levels`). The transaction can
  be tried again.
- ``40002`` (integrity constraint violation) is when a deferred constraint
  isn't satisfied at the ``COMMIT``.
- ``40V01`` (transaction rollback) is when a ``COMMIT`` fails for any other
  reason, such as an I/O error.

A statement that isn't in a transaction runs in a transaction of its own (see
:doc:`transactions`), so when it fails, nothing is kept.

Warnings
--------

A warning doesn't stop the statement or roll back the transaction, and a
statement can have more than one warning, such as a ``01004`` for each value
that a ``CAST`` truncated. The ``02000`` (no data) condition of a query or
statement that has no rows is shown the same way as a warning, but it isn't
one.

At most 100 warnings are kept, which is the ``DIAGNOSTICS SIZE`` of the
transaction. A smaller limit can be set with :doc:`set-transaction`
(for the next transaction) or :doc:`set-session-characteristics` (for every
transaction after it). When there are more warnings than that, the most recent
ones are kept.

How the warnings of a statement reach you depends on how it's run:

- :doc:`cli` prints a ``Warning`` line for each warning (and a ``Notice`` line
  for ``02000``) before the result. ``vsql in`` prints a ``WARNING`` line for
  each one (and a ``NOTICE`` line with ``-verbose``).
- In V (see :doc:`language-v`), ``Connection.warnings`` has the warnings, and
  ``Connection.more_conditions`` is true when some were dropped because of the
  limit. They aren't cleared before each statement, so call
  ``clear_warnings()`` before the statements that you want the warnings of.
- In C, with the SQL/CLI (see :doc:`language-c`), a routine returns
  ``SQL_SUCCESS_WITH_INFO`` instead of ``SQL_SUCCESS`` when there was a
  warning, and ``SQLGetDiagRec`` or ``SQLGetDiagField`` reads it.
- :doc:`server` sends each warning as a notice, before the result.

For example, in the CLI:

.. code-block:: sql

  SET TRANSACTION DIAGNOSTICS SIZE 1;
  VALUES CAST('abcde' AS CHARACTER(3)) || CAST('abcde' AS CHARACTER(3));
  -- msg: SET TRANSACTION
  -- warning 01004: string data, right truncation
  -- COL1: abcabc

The ``VALUES`` truncated two strings, but only one warning is kept.

Handling Errors
---------------

In V, an error is an ``SQLState``, which can be checked by its type (such as
``vsql.SQLState42P01``) or by its ``code()`` (see
:ref:`language-v:Errors and Warnings`).

This includes errors that aren't caused by the SQL itself, such as reading a
file (``58030``) or a file that isn't a vsql database (``XX001``). The only
exception is an error returned by your own code, such as a custom function (see
:doc:`custom-functions`) or a virtual table (see :doc:`virtual-tables`), which
is returned as it is.

An error can also be handled by its class (the first two characters):

.. code-block:: v

   db.query('SELECT * FROM bar') or {
   	if err.code() >= vsql.sqlstate_to_int('42000')
   		&& err.code() <= vsql.sqlstate_to_int('42ZZZ') {
   		println('Class 42 — Syntax Error or Access Rule Violation')
   	}
   }

See also
`examples/error-handling.v <https://github.com/elliotchance/vsql/blob/main/examples/error-handling.v>`_.
