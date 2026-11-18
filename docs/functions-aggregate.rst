Aggregate Functions
===================

.. contents::
   :local:
   :depth: 1

Aggregate functions calculate a single value from a set of rows (see
``GROUP BY`` in :doc:`select`). ``NULL`` values are ignored, with a ``01003``
warning. If all of the values are ``NULL`` (or there are no rows) the result is
``NULL``, except for ``COUNT``. ``CUME_DIST``, ``DENSE_RANK``, ``PERCENT_RANK``
and ``RANK`` don't ignore ``NULL`` values, and always have a result.

The value can be preceded by ``DISTINCT`` to only use each value once, so
``COUNT(DISTINCT city)`` is the number of different cities. Values are the same
if they are equal with ``=``, such as ``1.5`` and ``1.50``. It can also be
preceded by ``ALL``, which is the same as not having either.

The value can be any expression, such as ``SUM(price * quantity)``, but it
can't contain another aggregate function (``AVG(MAX(x))`` is a ``42601``
error). An aggregate function also can't be used in a ``WHERE`` clause or in
``VALUES``, because there are no groups of rows there.

An aggregate function can be followed by ``FILTER (WHERE condition)`` to only
use the rows where the condition is true. For example, ``COUNT(*) FILTER (WHERE
price > 10e0)`` counts the rows with a price over 10. The condition can use any
column, but it can't contain an aggregate function, a subquery or a column of
an outer query (all ``42601`` errors). ``FILTER`` is in the SQL standard
(T612), PostgreSQL and SQLite. In MySQL, SQL Server and Oracle, use a ``CASE``
in the value instead, such as ``SUM(CASE WHEN price > 10e0 THEN price END)``.

The statistical functions (see :doc:`functions-statistical`) are aggregate
functions too.

``LISTAGG`` and the ordered set functions (``CUME_DIST``, ``DENSE_RANK``,
``MODE``, ``PERCENT_RANK``, ``PERCENTILE_CONT``, ``PERCENTILE_DISC`` and
``RANK``) are followed by ``WITHIN GROUP (ORDER BY sort_key [ASC | DESC], ...)``, which is
the order of the rows of the group that they use. ``NULL`` is before any other
value with ``ASC``, and after it with ``DESC``.

The argument of an ordered set function isn't one of the rows of the group:
it's evaluated once for each group, like the select list. So it can be a
literal or a grouping column, but not another column of the table (a
``42803`` error). Only the sort keys use the rows.

The examples use this table:

.. code-block:: sql

  CREATE TABLE products (city VARCHAR(20), price FLOAT);
  INSERT INTO products (city, price) VALUES
    ('New York', 8.05e0), ('New York', 18.05e0),
    ('San Francisco', 7.5e0), ('San Francisco', 17.5e0),
    ('San Francisco', NULL);

ANY
^^^

.. code-block:: sql

   ANY(BOOLEAN) BOOLEAN

``ANY(CONDITION)`` returns ``TRUE`` if any of the values is ``TRUE``, otherwise
``FALSE``.
``UNKNOWN`` values are ``NULL``, so they're ignored like any other ``NULL``. If
there are no values (or they're all ``UNKNOWN``) the result is ``UNKNOWN``.

``CONDITION`` must be a ``BOOLEAN``, such as a column or a condition like
``price > 10``, otherwise it's a ``42883`` error.

``ANY`` and ``SOME`` are the same function. They're also the quantifiers of a
comparison with a subquery, such as ``x = ANY (SELECT ...)`` (see
:doc:`expressions`). When the parentheses contain a subquery it's the
comparison, otherwise it's this aggregate function, so ``x = ANY (y)`` compares
``x`` with ``ANY(y)``.

**Examples**

.. code-block:: sql

  SELECT ANY(price > 18) FROM products;
  -- COL1: TRUE

  SELECT city, ANY(price > 18) FROM products GROUP BY city;
  -- CITY: New York COL2: TRUE
  -- CITY: San Francisco COL2: FALSE

**Compatibility**

- **SQL standard:** T031 (BOOLEAN data type).
- **Other databases:**

  - PostgreSQL: ``BOOL_OR``. It doesn't have ``ANY`` and ``SOME`` as aggregate
    functions, because of the subquery comparisons.
  - MySQL and SQLite: ``MAX``, because their booleans are the numbers 0 and 1.
  - SQL Server: ``MAX(CASE WHEN condition THEN 1 ELSE 0 END) = 1``.
  - Oracle: ``BOOLEAN_OR_AGG`` (Oracle 23ai).

ANY_VALUE
^^^^^^^^^

.. code-block:: sql

   ANY_VALUE(ANY) ANY

Returns any one of the values that isn't ``NULL``, or ``NULL`` if they all are
(or there are no rows). Which one isn't defined, so it's useful for a column
that has the same value in every row of a group, without adding it to the
``GROUP BY``. The result has the same type as the values.

**Examples**

.. code-block:: sql

  SELECT city, ANY_VALUE(country) FROM stores GROUP BY city;
  -- CITY: Paris COL2: France

**Compatibility**

- **SQL standard:** Optional feature T626.
- **Other databases:** ``ANY_VALUE`` in PostgreSQL (16 and later), MySQL and
  Oracle. SQLite returns a value from any row for a column that isn't grouped.

AVG
^^^

.. code-block:: sql

   AVG(SMALLINT) NUMERIC(21, 16)
   AVG(INTEGER) NUMERIC(26, 16)
   AVG(BIGINT) NUMERIC(35, 16)
   AVG(NUMERIC(p, s)) NUMERIC(p - s + MAX(s, 16), MAX(s, 16))
   AVG(DECIMAL(p, s)) DECIMAL(p - s + MAX(s, 16), MAX(s, 16))
   AVG(REAL) REAL
   AVG(DOUBLE PRECISION) DOUBLE PRECISION

Returns the average value. The average of exact numbers (including integers)
has the scale of a division (see :doc:`numbers`): at least 16 digits after the
decimal point, truncated. For example, the average of the ``INTEGER`` values 1,
2 and 4 is 2.3333333333333333. The average of approximate numbers has the same
type as the values.

A value that isn't a number (such as a ``VARCHAR``) is a ``42883`` error.

**Examples**

.. code-block:: sql

  SELECT AVG(price) FROM products;
  -- COL1: 12.775e0

  SELECT city, AVG(price) FROM products GROUP BY city;
  -- CITY: New York COL2: 13.05e0
  -- CITY: San Francisco COL2: 12.5e0

**Compatibility**

- **SQL standard:** Core SQL (E091-01). The precision and scale of the average
  of exact numbers are implementation-defined, but at least those of the values.
- **Other databases:** ``AVG`` in all of them. SQL Server truncates the
  average of integers. PostgreSQL, MySQL, SQLite and Oracle return the
  fractional part, such as 2.3333333333333333 for the example above.

COUNT
^^^^^

.. code-block:: sql

   COUNT(*) INTEGER
   COUNT(ANY) INTEGER

``COUNT(*)`` counts the rows, including rows that only contain ``NULL`` values.
``DISTINCT`` can't be used with ``*``.

``COUNT(VALUE)`` counts the values that are not ``NULL``. The value can be any
type.

The result is 0 when there are no rows, or (for ``COUNT(VALUE)``) all of the
values are ``NULL``.

**Examples**

These examples show the difference between counting all rows and only counting
those that have a non-``NULL`` ``price``.

.. code-block:: sql

  SELECT COUNT(*) FROM products;
  -- COL1: 5

  SELECT COUNT(price) FROM products;
  -- COL1: 4

  SELECT COUNT(DISTINCT city) FROM products;
  -- COL1: 2

  SELECT city, COUNT(*) FROM products GROUP BY city;
  -- CITY: New York COL2: 2
  -- CITY: San Francisco COL2: 3

  SELECT city, COUNT(*) FILTER (WHERE price > 10e0) FROM products GROUP BY city;
  -- CITY: New York COL2: 1
  -- CITY: San Francisco COL2: 1

**Compatibility**

- **SQL standard:** Core SQL (E091-02).
- **Other databases:** ``COUNT`` in all of them. The result is a
  ``BIGINT`` in PostgreSQL and MySQL, and an ``INT`` in SQL Server (which has
  ``COUNT_BIG`` for a ``BIGINT``).

CUME_DIST
^^^^^^^^^

.. code-block:: sql

   CUME_DIST(VALUE, ...) WITHIN GROUP (ORDER BY sort_key, ...) DOUBLE PRECISION

The cumulative distribution of a hypothetical row with the values if it was
added to the group: the number of rows before it or equal to it (including
itself) divided by the number of rows (including itself). It's between 0 and 1.

The hypothetical row has a value for each sort key, so there must be the same
number of arguments as sort keys (otherwise it's a ``42601`` error), and each
must be comparable with its sort key (otherwise it's a ``42883`` error). Rows
with a ``NULL`` sort key aren't ignored.

**Examples**

.. code-block:: sql

  SELECT CUME_DIST(10e0) WITHIN GROUP (ORDER BY price) FROM products;
  -- COL1: 0.666666666667e0

**Compatibility**

- **SQL standard:** T612 (Advanced OLAP operations).
- **Other databases:** PostgreSQL and Oracle have the same syntax. MySQL,
  SQLite and SQL Server only have ``CUME_DIST`` as a window function.

DENSE_RANK
^^^^^^^^^^

.. code-block:: sql

   DENSE_RANK(VALUE, ...) WITHIN GROUP (ORDER BY sort_key, ...) INTEGER

The rank that a hypothetical row with the values would have if it was added to
the group, without gaps: one more than the number of distinct values (of all of
the sort keys) before it. Rows that are equal to it don't change its rank.

The hypothetical row has a value for each sort key, so there must be the same
number of arguments as sort keys (otherwise it's a ``42601`` error), and each
must be comparable with its sort key (otherwise it's a ``42883`` error). Rows
with a ``NULL`` sort key aren't ignored.

**Examples**

.. code-block:: sql

  SELECT DENSE_RANK('Oakland') WITHIN GROUP (ORDER BY city) FROM products;
  -- COL1: 2

**Compatibility**

- **SQL standard:** T612 (Advanced OLAP operations).
- **Other databases:** PostgreSQL and Oracle have the same syntax. MySQL,
  SQLite and SQL Server only have ``DENSE_RANK`` as a window function.

EVERY
^^^^^

.. code-block:: sql

   EVERY(BOOLEAN) BOOLEAN

``EVERY(CONDITION)`` returns ``TRUE`` if every value is ``TRUE``, and ``FALSE``
if any value is ``FALSE``. ``UNKNOWN`` values are ``NULL``, so they're ignored like any other
``NULL``. If there are no values (or they're all ``UNKNOWN``) the result is
``UNKNOWN``.

``CONDITION`` must be a ``BOOLEAN``, such as a column or a condition like
``price > 10``, otherwise it's a ``42883`` error.

**Examples**

.. code-block:: sql

  SELECT EVERY(price > 7) FROM products;
  -- COL1: TRUE

  SELECT city, EVERY(price > 8) FROM products GROUP BY city;
  -- CITY: New York COL2: TRUE
  -- CITY: San Francisco COL2: FALSE

**Compatibility**

- **SQL standard:** T031 (BOOLEAN data type).
- **Other databases:**

  - PostgreSQL: ``EVERY`` or ``BOOL_AND``.
  - MySQL and SQLite: ``MIN``, because their booleans are the numbers 0 and 1.
  - SQL Server: ``MIN(CASE WHEN condition THEN 1 ELSE 0 END) = 1``.
  - Oracle: ``BOOLEAN_AND_AGG`` (Oracle 23ai).

LISTAGG
^^^^^^^

.. code-block:: sql

   LISTAGG([DISTINCT] VALUE, 'separator' [overflow])
     WITHIN GROUP (ORDER BY sort_key [ASC | DESC], ...)
     CHARACTER VARYING(10485760)

   overflow:
     ON OVERFLOW ERROR
     ON OVERFLOW TRUNCATE ['filler'] WITH COUNT
     ON OVERFLOW TRUNCATE ['filler'] WITHOUT COUNT

Joins the string values into one string, with the separator between them. The
values are in the order of the ``WITHIN GROUP``, which can sort by any
expression (not only the value). Values that are equal for every sort key are
in the order that they're read in. The separator (and filler) must be a string
literal.

With ``DISTINCT``, each value is only used once, in the position where it's
first seen. Values are the same if they are equal with ``=``, so ``'a'`` and
``'a  '`` are the same value.

The result can't be longer than 10485760 characters (the longest
``VARCHAR``). By default a longer result is a ``22001`` error, which can also be
written as ``ON OVERFLOW ERROR``. With ``ON OVERFLOW TRUNCATE``, the result is
as many of the values as fit, followed by the separator and the filler
(``'...'`` if it's not specified). ``WITH COUNT`` also adds the number of values
that were left out in brackets, such as ``a, b, c, ...(5)``.

A value that isn't a string is a ``42883`` error. Use a ``CAST`` to join other
types, such as ``LISTAGG(CAST(id AS VARCHAR(20)), ', ')``.

**Examples**

.. code-block:: sql

  SELECT LISTAGG(city, ', ') WITHIN GROUP (ORDER BY price) FROM products;
  -- COL1: San Francisco, San Francisco, New York, San Francisco, New York

  SELECT LISTAGG(DISTINCT city, ', ') WITHIN GROUP (ORDER BY city DESC) FROM products;
  -- COL1: San Francisco, New York

  SELECT LISTAGG(city, ' | ') WITHIN GROUP (ORDER BY price DESC) FILTER (WHERE price > 10e0) FROM products;
  -- COL1: New York | San Francisco

**Compatibility**

- **SQL standard:** T625. The standard lets the result be a ``CLOB`` instead,
  which vsql doesn't have.
- **Other databases:** Oracle and Db2 have the same syntax. Oracle also has
  ``ON OVERFLOW``. SQL Server has ``STRING_AGG(value, separator) WITHIN GROUP
  (ORDER BY ...)``, PostgreSQL has ``STRING_AGG(value, separator ORDER BY
  ...)``, and MySQL has ``GROUP_CONCAT(value ORDER BY ... SEPARATOR
  separator)``. SQLite has ``GROUP_CONCAT`` and ``STRING_AGG``.

MAX
^^^

.. code-block:: sql

   MAX(ANY) ANY

Returns the maximum value, using the same rules as ``>``. The value can be any
type, including a ``BOOLEAN`` (``TRUE`` is greater than ``FALSE``), a date or
time, or a string. The result has the same type as the values.

``DISTINCT`` doesn't change the result.

**Examples**

.. code-block:: sql

  SELECT MAX(price) FROM products;
  -- COL1: 18.05e0

  SELECT city, MAX(price) FROM products GROUP BY city;
  -- CITY: New York COL2: 18.05e0
  -- CITY: San Francisco COL2: 17.5e0

  SELECT MAX(city) FROM products;
  -- COL1: San Francisco

**Compatibility**

- **SQL standard:** Core SQL (E091-03).
- **Other databases:** ``MAX`` in all of them. PostgreSQL doesn't accept a
  ``BOOLEAN``, use ``BOOL_OR`` instead.

MIN
^^^

.. code-block:: sql

   MIN(ANY) ANY

Returns the minimum value, using the same rules as ``<``. The value can be any
type, including a ``BOOLEAN`` (``FALSE`` is less than ``TRUE``), a date or time,
or a string. The result has the same type as the values.

``DISTINCT`` doesn't change the result.

**Examples**

.. code-block:: sql

  SELECT MIN(price) FROM products;
  -- COL1: 7.5e0

  SELECT city, MIN(price) FROM products GROUP BY city;
  -- CITY: New York COL2: 8.05e0
  -- CITY: San Francisco COL2: 7.5e0

**Compatibility**

- **SQL standard:** Core SQL (E091-04).
- **Other databases:** ``MIN`` in all of them. PostgreSQL doesn't accept a
  ``BOOLEAN``, use ``BOOL_AND`` instead.

MODE
^^^^

.. code-block:: sql

   MODE() WITHIN GROUP (ORDER BY sort_key) ANY

Returns the most frequent value of the sort key. When several values are the
most frequent, the result is the first of them in the order of the sort key,
so it's the smallest with ``ASC`` and the largest with ``DESC``. Values are the
same if they are equal with ``=``.

``MODE`` has no arguments (``MODE(x)`` is a ``42883`` error) and there must be
one sort key. The sort key can be any type that can be compared with ``=``,
such as a number, a string or a date, and the result has the same type.
``NULL`` values are ignored, with a ``01003`` warning, and if there are no
values the result is ``NULL``.

``MODE`` is a vsql extension flagged by ``V405-01`` (see :doc:`sql-flagging`).
It isn't a reserved word, so a column or a table can still be called ``mode``.

**Examples**

.. code-block:: sql

  SELECT MODE() WITHIN GROUP (ORDER BY city) FROM products;
  -- COL1: San Francisco

  SELECT MODE() WITHIN GROUP (ORDER BY price) FROM products;
  -- COL1: 7.5e0

  SELECT MODE() WITHIN GROUP (ORDER BY price DESC) FROM products;
  -- COL1: 18.05e0

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - PostgreSQL: ``MODE() WITHIN GROUP (ORDER BY x)``.
  - Oracle: ``STATS_MODE(x)``, which returns any one of the most frequent
    values when there's a tie.
  - DuckDB: ``MODE(x)``.
  - MySQL, SQLite and SQL Server: ``GROUP BY`` the value, sort the groups by
    ``COUNT(*) DESC`` and keep the first row.

PERCENT_RANK
^^^^^^^^^^^^

.. code-block:: sql

   PERCENT_RANK(VALUE, ...) WITHIN GROUP (ORDER BY sort_key, ...) DOUBLE PRECISION

The relative rank of a hypothetical row with the values if it was added to the
group: the number of rows before it divided by the number of rows of the group
(not including itself), or 0 if the group has no rows. It's between 0 and 1.

The hypothetical row has a value for each sort key, so there must be the same
number of arguments as sort keys (otherwise it's a ``42601`` error), and each
must be comparable with its sort key (otherwise it's a ``42883`` error). Rows
with a ``NULL`` sort key aren't ignored.

**Examples**

.. code-block:: sql

  SELECT PERCENT_RANK(10e0) WITHIN GROUP (ORDER BY price) FROM products;
  -- COL1: 0.6e0

**Compatibility**

- **SQL standard:** T612 (Advanced OLAP operations).
- **Other databases:** PostgreSQL and Oracle have the same syntax. MySQL,
  SQLite and SQL Server only have ``PERCENT_RANK`` as a window function.

PERCENTILE_CONT
^^^^^^^^^^^^^^^

.. code-block:: sql

   PERCENTILE_CONT(FRACTION) WITHIN GROUP (ORDER BY sort_key) DOUBLE PRECISION

The value at ``FRACTION`` (from 0 to 1) of the way through the sorted values,
so ``PERCENTILE_CONT(0.5)`` is the median. When that's between two values, the
result is between them in proportion: the position is ``FRACTION * (N - 1)``
(where ``N`` is the number of values), and ``PERCENTILE_CONT(0.5)`` of 10 and 20
is 15.

There must be one sort key, and it must be a number. ``NULL`` values are
ignored, with a ``01003`` warning, and if there are no values the result is
``NULL``. A ``FRACTION`` that's less than 0 or more than 1 is a ``22003``
error.

The value in between is cast to the type of the sort key before it's returned
as a ``DOUBLE PRECISION``, so the result for integers is truncated to an integer
(``PERCENTILE_CONT(0.5)`` of 1 and 2 is 1). Sort by ``CAST(x AS DOUBLE
PRECISION)`` to keep the fraction.

**Examples**

.. code-block:: sql

  SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price) FROM products;
  -- COL1: 12.775e0

  SELECT city, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price) FROM products GROUP BY city;
  -- CITY: New York COL2: 13.05e0
  -- CITY: San Francisco COL2: 12.5e0

**Compatibility**

- **SQL standard:** T612 (Advanced OLAP operations).
- **Other databases:** PostgreSQL, Oracle and SQL Server (only as a window
  function) have the same syntax. PostgreSQL and Oracle don't truncate a
  percentile of integers. MySQL and SQLite don't have it.

PERCENTILE_DISC
^^^^^^^^^^^^^^^

.. code-block:: sql

   PERCENTILE_DISC(FRACTION) WITHIN GROUP (ORDER BY sort_key) DOUBLE PRECISION

The first of the sorted values where at least ``FRACTION`` (from 0 to 1) of the
values are equal to it or before it. Unlike ``PERCENTILE_CONT``, the result is
always one of the values.

There must be one sort key, and it must be a number. ``NULL`` values are
ignored, with a ``01003`` warning, and if there are no values the result is
``NULL``. A ``FRACTION`` that's less than 0 or more than 1 is a ``22003``
error.

**Examples**

.. code-block:: sql

  SELECT PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY price) FROM products;
  -- COL1: 8.05e0

  SELECT PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY price DESC) FROM products;
  -- COL1: 17.5e0

**Compatibility**

- **SQL standard:** T612 (Advanced OLAP operations). The result is a
  ``DOUBLE PRECISION`` because the standard makes it an approximate number.
- **Other databases:** PostgreSQL, Oracle and SQL Server (only as a window
  function) have the same syntax, and return the type of the sort key. MySQL
  and SQLite don't have it.

PRODUCT
^^^^^^^

.. code-block:: sql

   PRODUCT(SMALLINT) BIGINT
   PRODUCT(INTEGER) BIGINT
   PRODUCT(BIGINT) BIGINT
   PRODUCT(NUMERIC(p, s)) DOUBLE PRECISION
   PRODUCT(DECIMAL(p, s)) DOUBLE PRECISION
   PRODUCT(REAL) DOUBLE PRECISION
   PRODUCT(DOUBLE PRECISION) DOUBLE PRECISION

Returns the product of all values (every value multiplied together). Values
can be zero or negative.

The product of integers is an exact ``BIGINT``, and a ``22003`` error is
returned if it's out of range (larger than 9223372036854775807 or less than
-9223372036854775808). Any other number gives an approximate ``DOUBLE
PRECISION``. An exact product of ``NUMERIC`` or ``DECIMAL`` values would have
the scales of all of them added together, so its scale would grow with the
number of rows, and no ``NUMERIC`` type can hold that.

The product of no rows (or only ``NULL`` values) is ``NULL``, not 1. Use
``COALESCE(PRODUCT(x), 1)`` to get 1.

A value that isn't a number (such as a ``VARCHAR``) is a ``42883`` error.

``PRODUCT`` is a vsql extension flagged by ``V405-02`` (see
:doc:`sql-flagging`). It isn't a reserved word, so a column or a table can
still be called ``product``.

**Examples**

.. code-block:: sql

  SELECT city, PRODUCT(price) FROM products GROUP BY city;
  -- CITY: New York COL2: 145.3025e0
  -- CITY: San Francisco COL2: 131.25e0

  SELECT PRODUCT(x), PRODUCT(DISTINCT x) FROM (VALUES (2), (-3), (2)) AS t (x);
  -- COL1: -12 COL2: -6

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - DuckDB: ``PRODUCT(x)``.
  - PostgreSQL, MySQL, SQLite, SQL Server and Oracle don't have it.
    ``EXP(SUM(LN(x)))`` is close when every value is positive.

RANK
^^^^

.. code-block:: sql

   RANK(VALUE, ...) WITHIN GROUP (ORDER BY sort_key, ...) INTEGER

The rank that a hypothetical row with the values would have if it was added to
the group: one more than the number of rows before it. Rows that are equal to
it don't change its rank.

The hypothetical row has a value for each sort key, so there must be the same
number of arguments as sort keys (otherwise it's a ``42601`` error), and each
must be comparable with its sort key (otherwise it's a ``42883`` error). Rows
with a ``NULL`` sort key aren't ignored.

**Examples**

.. code-block:: sql

  SELECT RANK(10e0) WITHIN GROUP (ORDER BY price) FROM products;
  -- COL1: 4

  SELECT RANK(17.5e0) WITHIN GROUP (ORDER BY price DESC) FROM products;
  -- COL1: 2

**Compatibility**

- **SQL standard:** T612 (Advanced OLAP operations).
- **Other databases:** PostgreSQL and Oracle have the same syntax. MySQL,
  SQLite and SQL Server only have ``RANK`` as a window function.

SOME
^^^^

.. code-block:: sql

   SOME(BOOLEAN) BOOLEAN

``SOME`` is another name for ``ANY``, see ``ANY``.

**Examples**

.. code-block:: sql

  SELECT SOME(price > 18) FROM products;
  -- COL1: TRUE

**Compatibility**

- **SQL standard:** T031 (BOOLEAN data type).
- **Other databases:** see ``ANY``.

SUM
^^^

.. code-block:: sql

   SUM(SMALLINT) BIGINT
   SUM(INTEGER) BIGINT
   SUM(BIGINT) BIGINT
   SUM(NUMERIC(p, s)) NUMERIC
   SUM(DECIMAL(p, s)) DECIMAL
   SUM(REAL) REAL
   SUM(DOUBLE PRECISION) DOUBLE PRECISION

Returns the sum (total) of all values. The sum of integers is a ``BIGINT``, so
it can be larger than any one value. The sum of exact numbers keeps their scale
but has no limit on the precision. A ``22003`` error is returned if the sum is
out of range for the result type (such as a sum of ``BIGINT`` values that is
larger than 9223372036854775807).

The sum of no rows (or only ``NULL`` values) is ``NULL``, not 0. Use
``COALESCE(SUM(x), 0)`` to get 0.

A value that isn't a number (such as a ``VARCHAR``) is a ``42883`` error.

**Examples**

.. code-block:: sql

  SELECT SUM(price) FROM products;
  -- COL1: 51.1e0

  SELECT city, SUM(price) FROM products GROUP BY city;
  -- CITY: New York COL2: 26.1e0
  -- CITY: San Francisco COL2: 25e0

**Compatibility**

- **SQL standard:** Core SQL (E091-05).
- **Other databases:** ``SUM`` in all of them. PostgreSQL returns a
  ``NUMERIC`` for the sum of ``BIGINT`` values, so it can't overflow.
