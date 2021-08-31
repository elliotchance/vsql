SELECT
======

A `SELECT` statement is used to retrieve rows from a table. It can also be used
to evaulate expressions without a table (see *FROM*).

.. contents::

Syntax
------

.. code-block:: txt

  SELECT <expression> [ AS <name> ] , ...
  FROM <table_name>
  [ WHERE <condition> ]
  [ OFFSET <integer> { ROW | ROWS } ]
  [ FETCH FIRST <integer> { ROW | ROWS } ONLY ]

SELECT
------

For each *expression*, the naming convention follows:

1. If ``name`` is provided, that will be used.
2. If ``expression`` refered to a column, the column name will be used.
3. Otherwise, the name ``COL<number>`` will be used where *number* is the position of the column (starting at 1).

WHERE
-----

If ``WHERE`` is not provided all rows are returned.

OFFSET
------

If ``OFFSET`` is provided, that number of rows will be skipped. If the
``OFFSET`` rows is greater than whole result set zero rows will be returned.

Using ``ROW`` or ``ROWS`` has no functional difference and either can be used
with any value. Both words are provided soley for grammatical benefit.

FETCH
-----

``FETCH`` can be used to limit the number of rows returned. ``FETCH`` can be
used in combination with ``OFFSET`` for further control.

If the ``FETCH`` rows is greater than the total set, all rows will be returned.

Using ``ROW`` or ``ROWS`` has no functional difference and either can be used
with any value. Both words are provided soley for grammatical benefit.

Examples
========

.. code-block:: sql

  SELECT * FROM products;

  SELECT price * (1 + tax) AS total
  FROM products;
