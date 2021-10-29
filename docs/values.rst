VALUES
======

A ``VALUES`` statement is used to create one or more rows that can be used as a
virtual table.

.. contents::

Syntax
------

Single row:

.. code-block:: text

  VALUES <expression>, ...

Multiple rows:

.. code-block:: text

  VALUES ROW(<expression>, ...), ...

VALUES
------

For each *expression*, the names ``COL1``, ``COL2``, etc will be used. The
names of the columns cannot be overridden directly in the ``VALUES`` statement,
but rather need to be wrapped in a ``SELECT``:

.. code-block:: sql

  SELECT * FROM (VALUES 1, 2, 3) AS t1 (foo, bar, baz);

EXPLAIN
-------

The query planner will uses a plan operation for the ``VALUES`` and it can be explained:

.. code-block:: sql

  EXPLAIN VALUES 'hello', 1.22;
  -- EXPLAIN: VALUES ROW('hello', 1.22)

  EXPLAIN SELECT *
  FROM (VALUES ROW(123, 'hi'), ROW(456, 'there')) AS foo (bar, baz);
  -- EXPLAIN: VALUES ROW(123, 'hi'), ROW(456, 'there') AS FOO (BAR, BAZ)

Examples
--------

.. code-block:: sql

  VALUES 'cool', 12.3;
  -- COL1: cool COL2: 12.3

  SELECT * FROM (VALUES 1, 'foo', TRUE);
  -- COL1: 1 COL2: foo COL3: TRUE

  SELECT * FROM (VALUES 1, 'foo', TRUE) AS t1 (abc, col2, "f");
  -- ABC: 1 COL2: foo f: TRUE

  SELECT * FROM (VALUES ROW(123, 'hi'), ROW(456, 'there'));
  -- COL1: 123 COL2: hi
  -- COL1: 456 COL2: there
