SELECT
======

.. contents::

Syntax
------

.. code-block:: txt

  SELECT <expression> [ AS <name> ] , ...
  [ FROM <table_name> ]
  [ WHERE <condition> ]

The SQL standard defines two types of identifiers: regular and delimited. A
regular identifier is a word (such as ``foo``) whereas a delimited identifier is
surrounded by double-quotes (such as ``"foo"``). A regular identifier is always
converted to upper-case, whereas as delimited identifier keeps it's case. This
applies to any identifier (table names, column names, ``AS`` names, etc).

For each *expression*, the naming convention follows:

1. If ``name`` is provided, that will be used.
2. If ``expression`` refered to a column, the column name will be used.
3. Otherwise, the name ``COL<number>`` will be used where *number* is the position of the column (starting at 1).

If ``FROM`` is not provided, the result will always be one row containing the
result of the expressions.

If ``WHERE`` is not provided all rows are returned.

Examples
--------

.. code-block:: sql

  SELECT * FROM products;

  SELECT price * (1 + tax) AS total
  FROM products;
