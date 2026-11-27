FAQ
===

.. contents::

Why are my table and column names in upper case?
-------------------------------------------------

A name that isn't in double quotes (a *regular identifier*) is converted to
upper case, as the SQL standard requires, so ``foo``, ``Foo`` and ``FOO`` are
all the name ``FOO``. Put a name in double quotes (such as ``"foo"``) to keep
its case. See :doc:`identifiers`.

Where can I find the SQL standard?
----------------------------------

The SQL standard is not free. However, you can find older versions publicly
available and these will be close enough to use as a reference:

1. `SQL 2016 Foundation Grammar (BNF) <https://jakewheat.github.io/sql-overview/sql-2016-foundation-grammar.html>`_
2. `SQL 1999 <https://sql-99.readthedocs.io/en/latest/>`_

See also :doc:`sql-standard`.

Why does ``SELECT 1`` give a syntax error?
------------------------------------------

The SQL standard requires a ``SELECT`` to have a ``FROM``. Use ``VALUES`` to
calculate an expression without a table:

.. code-block:: sql

   VALUES 1 + 2;
   -- COL1: 3

   VALUES ROW(CURRENT_DATE, UPPER('hello'));
   -- COL1: 2022-07-04 COL2: HELLO

Many PostgreSQL clients send a ``SELECT`` without a ``FROM``, so ``vsql server``
allows it (see :doc:`server`).

Why can't I use a number with a ``FLOAT`` or ``DOUBLE PRECISION``?
------------------------------------------------------------------

A number such as ``1.5`` is an exact ``NUMERIC``, and exact and approximate
numbers can't be mixed in arithmetic (``1.5 * price`` is an error if ``price``
is a ``DOUBLE PRECISION``). Write an approximate number with an exponent, such
as ``1.5e0``, or use ``CAST``. See :doc:`numbers`.

How do I see which tables exist?
--------------------------------

``vsql out`` prints the ``CREATE`` statement for every schema, sequence and
table in a database file (see :doc:`cli`). From V, ``Connection.catalog()``
lists the schemas, tables and sequences.

Will new versions of vsql open my database file?
------------------------------------------------

Yes. Every version of vsql can open a file created by an older version. A file
that uses a feature from a newer version may only be readable (or not open at
all) in an older version. See *Compatibility* in :doc:`file-format`.

Is my data safe if the process crashes or the power fails?
----------------------------------------------------------

Yes. Each statement is committed through a write-ahead log, so a database
file always has all or none of a statement's changes, and a transaction that
wasn't committed is rolled back. On macOS a power failure can still lose
statements unless ``full_fsync`` is on. See :doc:`durability`, which also
explains how to back up a database.
