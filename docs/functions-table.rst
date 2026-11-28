Table Functions
===============

.. contents::
   :local:
   :depth: 1

A table function is used in ``FROM`` instead of a table, and returns rows.
Like a derived table, it can have a correlation name and a list of column
names, such as ``GENERATE_SERIES(1, 3) AS t (n)``. Without a correlation name,
the table has the name of the function.

The arguments can't reference the columns of the other tables in the same
``FROM`` (it isn't ``LATERAL``), but they can reference the columns of an outer
query, so a table function can be in a correlated subquery. The name of a table
function can't have a schema.

GENERATE_SERIES
^^^^^^^^^^^^^^^

.. code-block:: sql

   GENERATE_SERIES(start, stop) TABLE (GENERATE_SERIES exact number)
   GENERATE_SERIES(start, stop, step) TABLE (GENERATE_SERIES exact number)
   GENERATE_SERIES(start DATE, stop DATE, step INTERVAL) TABLE (GENERATE_SERIES DATE)
   GENERATE_SERIES(start TIMESTAMP, stop TIMESTAMP, step INTERVAL) TABLE (GENERATE_SERIES TIMESTAMP)

A table with one column, ``GENERATE_SERIES``, and a row for each value from
``start`` to ``stop``, adding ``step`` each time. ``stop`` is included if a
step reaches it exactly. It's a quick way to get a run of numbers or dates,
instead of a ``VALUES`` with each one written out.

For numbers, ``step`` is ``1`` by default, and the column has the combined type
of all of the arguments (see :doc:`numbers`), which must be exact numbers
(``SMALLINT``, ``INTEGER``, ``BIGINT``, ``NUMERIC`` or ``DECIMAL``). So
``GENERATE_SERIES(1, 2, 0.5)`` is a ``NUMERIC`` with 1 decimal place. Counting
past the largest (or smallest) value of the type ends the series, since
``stop`` is never past it.

For a ``DATE`` or a ``TIMESTAMP`` (with or without a time zone), ``step`` is
required and must be an ``INTERVAL``, and the column has the type of the
datetime plus the interval. Each value is ``start`` plus a whole number of
steps, so adding months keeps the day of ``start``. It's a ``22008`` error if
that day isn't in a month (such as the 31st), the same as adding the interval
to ``start``. A ``DATE`` can't have an interval of hours, minutes or seconds.

A negative ``step`` counts down. There are no rows if ``step`` goes away from
``stop`` (such as ``GENERATE_SERIES(5, 1)``), or if any argument is ``NULL``.
A ``step`` of zero is a ``22023`` error. Any other types are a ``42883`` error.

``GENERATE_SERIES`` is a vsql extension flagged by ``V412-01`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  SELECT * FROM GENERATE_SERIES(1, 3);
  -- GENERATE_SERIES: 1
  -- GENERATE_SERIES: 2
  -- GENERATE_SERIES: 3

  SELECT * FROM GENERATE_SERIES(10, 0, -5);
  -- GENERATE_SERIES: 10
  -- GENERATE_SERIES: 5
  -- GENERATE_SERIES: 0

  SELECT t.n * 10 AS x FROM GENERATE_SERIES(1, 3) AS t (n) WHERE n <> 2;
  -- X: 10
  -- X: 30

  SELECT * FROM GENERATE_SERIES(DATE '2024-01-15', DATE '2024-05-01', INTERVAL '1' MONTH);
  -- GENERATE_SERIES: 2024-01-15
  -- GENERATE_SERIES: 2024-02-15
  -- GENERATE_SERIES: 2024-03-15
  -- GENERATE_SERIES: 2024-04-15

  SELECT * FROM GENERATE_SERIES(TIMESTAMP '2024-01-01 22:00:00', TIMESTAMP '2024-01-02 01:30:00', INTERVAL '90' MINUTE);
  -- GENERATE_SERIES: 2024-01-01T22:00:00
  -- GENERATE_SERIES: 2024-01-01T23:30:00
  -- GENERATE_SERIES: 2024-01-02T01:00:00

**Compatibility**

- **SQL standard:** not standard. The standard's table functions (feature
  T326) are different.
- **Other databases:**

  - PostgreSQL: ``generate_series``. A DATE is a TIMESTAMP, and adding a month
    to the 31st gives the last day of a shorter month. With a correlation name
    and no column list, the column has the correlation name.
  - DuckDB: ``generate_series`` (and ``range``, which leaves out ``stop``).
  - SQL Server: ``GENERATE_SERIES`` (2022), only for numbers, with a column
    named ``value``.
  - MySQL, SQLite and Oracle: none, use a recursive ``WITH``.
