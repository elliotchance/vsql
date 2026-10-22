FAQ
===

.. contents::

Why are my table and column names in upper case?
-------------------------------------------------

The SQL standard defines two types of identifiers: *regular* and *delimited*. A
regular identifier is a word (such as ``foo``) whereas a delimited identifier is
surrounded by double-quotes (such as ``"foo"``).

The SQL standard states that regular identifiers are always converted to
upper-case. Apart from being a styling choice, this also means that regular
identifiers are not case-sensitive so ``foo``, ``Foo`` and ``FOO`` are all valid
and all mean the same thing, but will be represented as ``FOO``.

Conversely, delimited identifiers keep their case. So ``"foo"`` and ``"Foo"``
are not the same. But it's worth noting that all identifiers still exist in the
same set, so ``"FOO"`` and ``FOO`` (or, ``foo``, ``Foo``, etc) *are* actually
the same.

These rules apply to all identifiers (table names, column names, ``AS`` names,
etc). So, using delimited identifiers also allows you to control the alias, for
example: ``SELECT 1 + 2 AS "the Total"`` will keep the column name
``the Total``.

Why is there no "LIMIT" syntax?
-------------------------------

Several open source databases provide a ``LIMIT`` style syntax. However, this is
not part of the SQL standard. The standard way to perform these are:

1. ``OFFSET 5 ROWS`` skips the first 5 rows.
2. ``FETCH FIRST 3 ROWS ONLY`` will return a maximum of 3 rows (equivalent to
   ``LIMIT 3``).
3. ``OFFSET 1 ROW FETCH FIRST 5 ROWS ONLY`` will skip the first row and return a
   maximum of 5 rows.

Where can I find the SQL standard?
----------------------------------

The SQL standard is not free. However, you can find older versions publicly
available and these will be close enough to use as a reference:

1. `SQL 2016 Foundation Grammar (BNF) <https://jakewheat.github.io/sql-overview/sql-2016-foundation-grammar.html>`_
2. `SQL 1999 <https://sql-99.readthedocs.io/en/latest/>`_

See also :doc:`sql-standard`.

Why is there no ``NOW()`` function?
-----------------------------------

The ``NOW()`` function commonly found in other databases is not actually part of
the SQL standard. Instead you must use one of ``CURRENT_TIMESTAMP`` or
``LOCALTIMESTAMP`` depending if you need to include the time zone or not. See
:doc:`dates-times`.

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
