VALUES
======

A ``VALUES`` statement is used to create one or more rows that can be used as a
virtual table.

.. contents::

Syntax
------

.. code-block:: text

  VALUES <expression>, ...
  VALUES ROW(<expression>, ...), ...
  [ OFFSET <integer> { ROW | ROWS } ]
  [ FETCH FIRST [ <integer> ] { ROW | ROWS } ONLY ]

``VALUES 1, 2`` is two rows of one column. Use ``ROW`` for more than one column
in a row, such as ``VALUES ROW(1, 2)``.

VALUES
------

For each *expression*, the names ``COL1``, ``COL2``, etc will be used. The
names of the columns cannot be overridden directly in the ``VALUES`` statement,
but rather need to be wrapped in a ``SELECT``:

.. code-block:: sql

  SELECT * FROM (VALUES ROW(1, 2, 3)) AS t1 (foo, bar, baz);

Every row must have the same number of columns, and the values in each column
must have compatible types (all character strings, all numbers, all ``BOOLEAN``
or the same kind of date or time). The column has a type that can hold all of
them, such as ``INTEGER`` for ``VALUES 1, 200000``.

EXPLAIN
-------

The query planner uses a plan operation for the ``VALUES`` and it can be
explained:

.. code-block:: sql

  EXPLAIN VALUES ROW('hello', 1.22);
  -- EXPLAIN: VALUES (COL1 CHARACTER(5), COL2 NUMERIC(3, 2)) = ROW('hello', 1.22)

  EXPLAIN SELECT *
  FROM (VALUES ROW(123, 'hi'), ROW(456, 'there')) AS foo (bar, baz);
  -- EXPLAIN: FOO:
  -- EXPLAIN:   VALUES (BAR SMALLINT, BAZ CHARACTER(5)) = ROW(123, 'hi'), ROW(456, 'there')
  -- EXPLAIN: TABLE FOO (BAR SMALLINT, BAZ CHARACTER(5))
  -- EXPLAIN: EXPR (FOO.BAR SMALLINT, FOO.BAZ CHARACTER(5))

Examples
--------

.. code-block:: sql

  VALUES ROW('cool', 12.3);
  -- COL1: cool COL2: 12.3

  SELECT * FROM (VALUES ROW(1, 'foo', TRUE)) AS t;
  -- COL1: 1 COL2: foo COL3: TRUE

  SELECT * FROM (VALUES ROW(1, 'foo', TRUE)) AS t1 (abc, col2, "f");
  -- ABC: 1 COL2: foo f: TRUE

  SELECT * FROM (VALUES ROW(123, 'hi'), ROW(456, 'there')) AS t;
  -- COL1: 123 COL2: hi
  -- COL1: 456 COL2: there
