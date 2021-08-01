.. contents::

Why are my field/column names in upper case?
--------------------------------------------

The SQL standard defines two types of identifiers: *regular* and *delimited*. A
regular identifier is a word (such as ``foo``) whereas a delimited identifier is
surrounded by double-quotes (such as ``"foo"``).

The SQL standard states that regular identifiers are always converted to
upper-case. Apart from being styling choice, this also means that regular
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
2. ``FETCH FIRST 3 ROWS ONLY`` will return a maximum of 3 rows (equivilent to ``LIMIT 3``).
3. ``OFFSET 1 ROW FETCH FIRST 5 ROWS ONLY`` will skip the first row and return a maximum of 5 rows.
