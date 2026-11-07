Functions
=========

.. contents::
   :local:
   :depth: 2

Overview
--------

Each function is in one category. The code block below each function's name
lists each combination of argument types it accepts and the type of the
result.

Unless the function says otherwise:

- The result is ``NULL`` if any argument is ``NULL``. A bare ``NULL`` can't be an
  argument because it has no type (``ABS(NULL)`` is a syntax error), so use a
  ``CAST``, such as ``ABS(CAST(NULL AS INTEGER))``.

- A function called with an argument of the wrong kind, such as
  ``UPPER(123)``, returns a ``42883`` error (function does not exist). Numbers
  and strings are not converted to each other.

Functions that aren't listed here can be added with :doc:`custom-functions`.

Each function also has a **Compatibility** section:

- **SQL standard** is the feature of ISO/IEC 9075-2:2016 (SQL:2016) that the
  function belongs to. Core SQL is the part of the standard that every
  conforming database has to support, the others are optional features. See
  :doc:`sql-compliance` for all of the features, and :doc:`sql-flagging` to
  find SQL that isn't standard.

- **Other databases** is how to get the same result in PostgreSQL, MySQL,
  SQLite, SQL Server and Oracle, with the same or a different name. The
  mathematical functions of SQLite (other than ``ABS``) need
  ``SQLITE_ENABLE_MATH_FUNCTIONS``, which is on by default since SQLite 3.35.

.. list-table::
   :header-rows: 1

   * - Function
     - Category
     - SQL standard

   * - ``ABS``
     - Arithmetic
     - T441
   * - ``ACOS``
     - Trigonometric
     - T622
   * - ``ASIN``
     - Trigonometric
     - T622
   * - ``ATAN``
     - Trigonometric
     - T622
   * - ``ANY``
     - Aggregate
     - T031
   * - ``AVG``
     - Aggregate
     - Core (E091-01)
   * - ``CEIL``
     - Rounding
     - T621
   * - ``CEILING``
     - Rounding
     - T621
   * - ``CHAR_LENGTH``
     - String
     - Core (E021-04)
   * - ``CHARACTER_LENGTH``
     - String
     - Core (E021-04)
   * - ``COALESCE``
     - Conditional
     - Core (F261-04)
   * - ``CORR``
     - Statistical
     - T621
   * - ``COS``
     - Trigonometric
     - T622
   * - ``COSH``
     - Trigonometric
     - T622
   * - ``COUNT``
     - Aggregate
     - Core (E091-02)
   * - ``COVAR_POP``
     - Statistical
     - T621
   * - ``COVAR_SAMP``
     - Statistical
     - T621
   * - ``CURRENT_CATALOG``
     - Session
     - F762
   * - ``CURRENT_DATE``
     - Date and Time
     - Core (F051-06)
   * - ``CURRENT_SCHEMA``
     - Session
     - F763
   * - ``CURRENT_TIME``
     - Date and Time
     - F411
   * - ``CURRENT_TIMESTAMP``
     - Date and Time
     - F411
   * - ``EVERY``
     - Aggregate
     - T031
   * - ``EXP``
     - Exponent and Logarithm
     - T621
   * - ``FLOOR``
     - Rounding
     - T621
   * - ``LISTAGG``
     - Aggregate
     - T625
   * - ``LN``
     - Exponent and Logarithm
     - T621
   * - ``LOCALTIME``
     - Date and Time
     - Core (F051-07)
   * - ``LOCALTIMESTAMP``
     - Date and Time
     - Core (F051-08)
   * - ``LOG``
     - Exponent and Logarithm
     - T623
   * - ``LOG10``
     - Exponent and Logarithm
     - T624
   * - ``LOWER``
     - String
     - Core (E021-08)
   * - ``MAX``
     - Aggregate
     - Core (E091-03)
   * - ``MIN``
     - Aggregate
     - Core (E091-04)
   * - ``MOD``
     - Arithmetic
     - T441
   * - ``NOW``
     - Date and Time
     - Not standard (V402-01)
   * - ``NULLIF``
     - Conditional
     - Core (F261-03)
   * - ``OCTET_LENGTH``
     - String
     - Core (E021-05)
   * - ``OVERLAY``
     - String
     - T312
   * - ``POSITION``
     - String
     - Core (E021-11)
   * - ``POWER``
     - Exponent and Logarithm
     - T621
   * - ``REGR_AVGX``
     - Statistical
     - T621
   * - ``REGR_AVGY``
     - Statistical
     - T621
   * - ``REGR_COUNT``
     - Statistical
     - T621
   * - ``REGR_INTERCEPT``
     - Statistical
     - T621
   * - ``REGR_R2``
     - Statistical
     - T621
   * - ``REGR_SLOPE``
     - Statistical
     - T621
   * - ``REGR_SXX``
     - Statistical
     - T621
   * - ``REGR_SXY``
     - Statistical
     - T621
   * - ``REGR_SYY``
     - Statistical
     - T621
   * - ``SIN``
     - Trigonometric
     - T622
   * - ``SINH``
     - Trigonometric
     - T622
   * - ``SOME``
     - Aggregate
     - T031
   * - ``SQRT``
     - Exponent and Logarithm
     - T621
   * - ``STDDEV_POP``
     - Statistical
     - T621
   * - ``STDDEV_SAMP``
     - Statistical
     - T621
   * - ``SUBSTRING``
     - String
     - Core (E021-06), T581
   * - ``SUM``
     - Aggregate
     - Core (E091-05)
   * - ``TAN``
     - Trigonometric
     - T622
   * - ``TANH``
     - Trigonometric
     - T622
   * - ``TRIM``
     - String
     - Core (E021-09)
   * - ``UPPER``
     - String
     - Core (E021-08)
   * - ``VAR_POP``
     - Statistical
     - T621
   * - ``VAR_SAMP``
     - Statistical
     - T621

Aggregate
---------

Aggregate functions calculate a single value from a set of rows (see
``GROUP BY`` in :doc:`select`). ``NULL`` values are ignored, with a ``01003``
warning. If all of the values are ``NULL`` (or there are no rows) the result is
``NULL``, except for ``COUNT``.

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

The statistical functions (see *Statistical*) are aggregate functions too.

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

AVG
^^^

.. code-block:: sql

   AVG(SMALLINT) SMALLINT
   AVG(INTEGER) INTEGER
   AVG(BIGINT) BIGINT
   AVG(NUMERIC(p, s)) NUMERIC(p, s)
   AVG(DECIMAL(p, s)) DECIMAL(p, s)
   AVG(REAL) REAL
   AVG(DOUBLE PRECISION) DOUBLE PRECISION

Returns the average value. The result has the same type as the values, so the
average of exact numbers is truncated to their scale. For example, the average
of the ``INTEGER`` values 1, 2 and 4 is 2. Use a ``CAST`` to get more digits,
such as ``AVG(CAST(x AS NUMERIC(10, 2)))`` which is 2.33.

A value that isn't a number (such as a ``VARCHAR``) is a ``42883`` error.

**Examples**

.. code-block:: sql

  SELECT AVG(price) FROM products;
  -- COL1: 12.775e0

  SELECT city, AVG(price) FROM products GROUP BY city;
  -- CITY: New York COL2: 13.05e0
  -- CITY: San Francisco COL2: 12.5e0

**Compatibility**

- **SQL standard:** Core SQL (E091-01). The standard lets the result of exact
  numbers have more digits than the values, vsql keeps the same type.
- **Other databases:** ``AVG`` in all of them. SQL Server also truncates the
  average of integers. PostgreSQL, MySQL, SQLite and Oracle return the
  fractional part, such as 2.33 for the example above.

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

Arithmetic
----------

Arithmetic functions return the absolute value or the remainder of a number.
The result has the type of an argument (see each function).

They accept any number. If there is no version of the function
for the argument types, an exact number (such as an ``INTEGER``) is converted to
a ``NUMERIC`` when possible, otherwise to a ``DOUBLE PRECISION``, and a ``REAL``
is converted to a ``DOUBLE PRECISION``.

A number literal has the smallest type that holds it, so ``-5`` is a
``SMALLINT`` and ``1.50`` is a ``NUMERIC(3, 2)``.

ABS
^^^

.. code-block:: sql

   ABS(SMALLINT) SMALLINT
   ABS(INTEGER) INTEGER
   ABS(BIGINT) BIGINT
   ABS(REAL) REAL
   ABS(DOUBLE PRECISION) DOUBLE PRECISION
   ABS(DECIMAL(p, s)) DECIMAL(p, s)
   ABS(NUMERIC(p, s)) NUMERIC(p, s)

Absolute value. The result is the same type as the argument, including the
precision and scale of a ``DECIMAL`` or ``NUMERIC``.

The smallest value of each integer type has no positive value in the same type,
so it's a ``22003`` error, such as ``ABS(CAST(-32768 AS SMALLINT))``. The
literal ``-32768`` is a ``SMALLINT``, so ``ABS(-32768)`` is also an error, use
``ABS(CAST(-32768 AS INTEGER))``.

**Examples**

.. code-block:: sql

  VALUES ABS(1.2e0);
  -- COL1: 1.2e0

  VALUES ABS(-1.23e0);
  -- COL1: 1.23e0

  VALUES ABS(-1.230);
  -- COL1: 1.230

  VALUES ABS(-32768);
  -- error 22003: numeric value out of range

**Compatibility**

- **SQL standard:** T441 (ABS and MOD functions).
- **Other databases:** ``ABS`` in all of them.

MOD
^^^

.. code-block:: sql

   MOD(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION
   MOD(NUMERIC, NUMERIC) NUMERIC
   MOD(SMALLINT, SMALLINT) SMALLINT
   MOD(INTEGER, INTEGER) INTEGER
   MOD(BIGINT, BIGINT) BIGINT

``MOD(DIVIDEND, DIVISOR)`` is the modulus, the remainder of dividing
``DIVIDEND`` by ``DIVISOR``. The result has
the same sign as ``DIVIDEND``, so ``MOD(-7, 3)`` is -1 and ``MOD(7, -3)`` is 1.
A ``DIVISOR`` of 0 is a ``22012`` error (division by zero), for every type.

When both arguments are integers the result has the type of ``DIVISOR`` (the
result is always smaller than it), such as ``MOD(BIGINT, SMALLINT) SMALLINT``.
When either is a ``NUMERIC`` or ``DECIMAL``, the result is a ``NUMERIC`` with
the larger scale of the two. When either is approximate (``REAL`` or
``DOUBLE PRECISION``), the result is a ``DOUBLE PRECISION``.

The standard only allows integers (exact numbers with a scale of 0). An
argument with a scale or an approximate literal, such as ``MOD(5.5, 2)``, is a
vsql extension flagged by ``V403-01`` (see :doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES MOD(232e0, 3e0);
  -- COL1: 1e0

  VALUES MOD(10.7e0, 0.8e0);
  -- COL1: 0.3e0

  VALUES MOD(10.7, 0.8);
  -- COL1: 0.3

  VALUES MOD(-7, 3);
  -- COL1: -1

  VALUES MOD(7, 0);
  -- error 22012: division by zero

**Compatibility**

- **SQL standard:** T441 (ABS and MOD functions), for integers.
- **Other databases:**

  - PostgreSQL and MySQL: ``MOD(x, y)`` or ``x % y``.
  - SQLite: ``x % y``, or ``MOD(x, y)`` which always returns a floating point
    number.
  - SQL Server: ``x % y``.
  - Oracle: ``MOD(x, y)``.

Conditional
-----------

Conditional functions choose between values. Unlike other functions, their
result isn't always ``NULL`` when an argument is ``NULL``. See also ``CASE`` in
:doc:`expressions`.

COALESCE
^^^^^^^^

.. code-block:: sql

   COALESCE(ANY, ANY, ...) ANY

``COALESCE`` returns the first value that is not ``NULL``. If all values are
``NULL`` then ``NULL`` is also returned.

It needs at least two values and they must have compatible types (all character
strings, all numbers, all ``BOOLEAN`` or the same kind of date or time),
otherwise it's a ``42804`` error. The result has a type that can hold any of
them, so ``COALESCE(1, 2.5)`` is a ``NUMERIC``.

The values are checked in order, and the values after the first one that is not
``NULL`` aren't evaluated. So ``COALESCE(1, 1 / 0)`` is 1, not an error.

``COALESCE(x, y)`` is the same as:

.. code-block:: sql

  CASE WHEN x IS NOT NULL THEN x ELSE y END

**Examples**

.. code-block:: sql

  VALUES COALESCE(1, 2);
  -- COL1: 1

  VALUES COALESCE(CAST(NULL AS INTEGER), 2);
  -- COL1: 2

  VALUES COALESCE(1, 2.5);
  -- COL1: 1.0

  VALUES COALESCE(1, 'a');
  -- error 42804: data type mismatch in argument 2 of COALESCE: expected SMALLINT but got CHARACTER(1)

**Compatibility**

- **SQL standard:** Core SQL (F261-04).
- **Other databases:** ``COALESCE`` in all of them. There are also two
  argument versions: ``IFNULL`` (MySQL, SQLite), ``ISNULL`` (SQL Server) and
  ``NVL`` (Oracle).

NULLIF
^^^^^^

.. code-block:: sql

   NULLIF(ANY, ANY) ANY

``NULLIF(VALUE1, VALUE2)`` returns ``NULL`` if ``VALUE1`` and ``VALUE2`` are
equal. Otherwise
``VALUE1`` is returned. The result has the type of ``VALUE1``.

The values are compared with ``=``, so ``1`` and ``1.0`` are equal, and so are
``'a'`` and ``'a '``. They must have compatible types, otherwise it's a
``42804`` error. If either value is ``NULL`` they aren't equal, so ``VALUE1``
is returned.

``NULLIF`` is useful to avoid dividing by zero, ``x / NULLIF(y, 0)`` is
``NULL`` instead of an error when ``y`` is 0.

``NULLIF(x, y)`` is the same as:

.. code-block:: sql

  CASE WHEN x = y THEN NULL ELSE x END

**Examples**

.. code-block:: sql

  VALUES NULLIF(123, 123);
  -- COL1: NULL

  VALUES NULLIF(123, 456);
  -- COL1: 123

  VALUES NULLIF(1, 1.0);
  -- COL1: NULL

**Compatibility**

- **SQL standard:** Core SQL (F261-03).
- **Other databases:** ``NULLIF`` in all of them.

Date and Time
-------------

These functions return the current date and time (see :doc:`dates-times` for
the types). The time is taken once for each statement, so every use in the
same statement has the same value, even if the statement takes a while. Each
execution of a prepared statement has a new time.

The time zone is the time zone of the session.

CURRENT_DATE
^^^^^^^^^^^^

.. code-block:: sql

   CURRENT_DATE DATE

Provides the current date (eg. ``2022-03-24``) within the time zone of the
session. There are no parentheses (``CURRENT_DATE()`` is a syntax error).

**Compatibility**

- **SQL standard:** Core SQL (F051-06).
- **Other databases:**

  - PostgreSQL, MySQL (also ``CURDATE()``) and SQLite: ``CURRENT_DATE``. The
    SQLite date is a string in UTC.
  - SQL Server: ``CAST(GETDATE() AS DATE)``.
  - Oracle: ``CURRENT_DATE``, but it also has the time, use
    ``TRUNC(CURRENT_DATE)``.

CURRENT_TIME
^^^^^^^^^^^^

.. code-block:: sql

   CURRENT_TIME TIME(0) WITH TIME ZONE
   CURRENT_TIME(p) TIME(p) WITH TIME ZONE

Provides the time with the time zone (eg. ``15:45:55+05:00``) within the time
zone of the session.

The precision is optional and if not provided will use a value of ``0``.
Otherwise, it must be an integer between ``0`` and ``6`` (a ``42601`` error
otherwise) and controls both the subsecond accuracy and result type.

``CURRENT_TIME`` differs from ``LOCALTIME`` which returns the same time, but
without the time zone.

**Compatibility**

- **SQL standard:** F411 (time zone specification).
- **Other databases:**

  - PostgreSQL: ``CURRENT_TIME``.
  - MySQL (also ``CURTIME()``) and SQLite: ``CURRENT_TIME``, but without a time
    zone. The SQLite time is a string in UTC.
  - SQL Server: ``CAST(SYSDATETIMEOFFSET() AS TIME)``, but without a time
    zone.
  - Oracle has no ``TIME`` type.

CURRENT_TIMESTAMP
^^^^^^^^^^^^^^^^^

.. code-block:: sql

   CURRENT_TIMESTAMP TIMESTAMP(6) WITH TIME ZONE
   CURRENT_TIMESTAMP(p) TIMESTAMP(p) WITH TIME ZONE

Provides the date and time with the time zone (eg.
``2022-03-24 15:45:55.123456+05:00``) within the time zone of the session.

The precision is optional and if not provided will use a value of ``6``.
Otherwise, it must be an integer between ``0`` and ``6`` (a ``42601`` error
otherwise) and controls both the subsecond accuracy and result type.

``CURRENT_TIMESTAMP`` can be the ``DEFAULT`` of a column (see
:doc:`create-table`).

``CURRENT_TIMESTAMP`` differs from ``LOCALTIMESTAMP`` which returns the same
date and time, but without the time zone.

**Compatibility**

- **SQL standard:** F411 (time zone specification).
- **Other databases:**

  - PostgreSQL and Oracle: ``CURRENT_TIMESTAMP``. In PostgreSQL it's the time
    the transaction started, not the statement.
  - MySQL, SQL Server and SQLite: ``CURRENT_TIMESTAMP``, but without a time
    zone. The SQLite timestamp is a string in UTC. SQL Server has
    ``SYSDATETIMEOFFSET()`` for the time zone.

LOCALTIME
^^^^^^^^^

.. code-block:: sql

   LOCALTIME TIME(0) WITHOUT TIME ZONE
   LOCALTIME(p) TIME(p) WITHOUT TIME ZONE

Provides the time without the time zone (eg. ``15:45:55``) within the time zone
of the session.

The precision is optional and if not provided will use a value of ``0``.
Otherwise, it must be an integer between ``0`` and ``6`` (a ``42601`` error
otherwise) and controls both the subsecond accuracy and result type.

``LOCALTIME`` differs from ``CURRENT_TIME`` which returns the same time, but
also includes the time zone.

**Compatibility**

- **SQL standard:** Core SQL (F051-07).
- **Other databases:**

  - PostgreSQL: ``LOCALTIME``.
  - MySQL: ``CURRENT_TIME`` (``LOCALTIME`` is the date and time).
  - SQL Server: ``CAST(SYSDATETIME() AS TIME)``.
  - SQLite: ``TIME('now', 'localtime')``.
  - Oracle has no ``TIME`` type.

LOCALTIMESTAMP
^^^^^^^^^^^^^^

.. code-block:: sql

   LOCALTIMESTAMP TIMESTAMP(6) WITHOUT TIME ZONE
   LOCALTIMESTAMP(p) TIMESTAMP(p) WITHOUT TIME ZONE

Provides the date and time without the time zone (eg.
``2022-03-24 15:45:55.123456``) within the time zone of the session.

The precision is optional and if not provided will use a value of ``6``.
Otherwise, it must be an integer between ``0`` and ``6`` (a ``42601`` error
otherwise) and controls both the subsecond accuracy and result type.

``LOCALTIMESTAMP`` differs from ``CURRENT_TIMESTAMP`` which returns the same
date and time, but also includes the time zone.

**Compatibility**

- **SQL standard:** Core SQL (F051-08).
- **Other databases:**

  - PostgreSQL, MySQL and Oracle: ``LOCALTIMESTAMP``.
  - SQL Server: ``SYSDATETIME()``.
  - SQLite: ``DATETIME('now', 'localtime')``.

NOW
^^^

.. code-block:: sql

   NOW() TIMESTAMP(6) WITH TIME ZONE

Returns the time now, read from the wall clock each time it's called. It
doesn't take a precision (``NOW(3)`` is a ``42883`` error), use
``CAST(NOW() AS TIMESTAMP(3) WITH TIME ZONE)`` instead.

This is different from ``CURRENT_TIMESTAMP``, which is the time the statement
started and is the same everywhere in the statement, even if the statement
takes a long time. ``NOW()`` can be different each time it's called, including
in the same statement:

.. code-block:: sql

   SELECT CURRENT_TIMESTAMP AS started, NOW() AS now FROM big_table;
   -- STARTED is the same for every row, NOW moves as the rows are read.

Use ``NOW()`` when you need the actual time, such as to measure how long
something takes or to record when each row was processed. Use
``CURRENT_TIMESTAMP`` when the statement needs one consistent time.

Because it can return a different value each time, ``NOW()`` is not
deterministic, so it can't be used in a ``CHECK`` constraint (a ``42601``
error). It's also a function, not a datetime value function like
``CURRENT_TIMESTAMP``, so it can't be a ``DEFAULT`` (a syntax error). Use
``CURRENT_TIMESTAMP`` for both.

``NOW`` isn't a reserved word, so it can still be the name of a table or a
column. A custom function (see :doc:`custom-functions`) can't be registered as
``now()``, because that function already exists.

**Compatibility**

- **SQL standard:** Not standard, it's a vsql extension flagged by
  ``V402-01`` (see :doc:`sql-flagging`). The standard has no function that
  reads the clock each time it's called. ``CURRENT_TIMESTAMP`` is portable, but
  it's the time the statement started.
- **Other databases:**

  - PostgreSQL: ``CLOCK_TIMESTAMP()``. PostgreSQL's ``NOW()`` is the time the
    transaction started.
  - MySQL: ``SYSDATE(6)``, without a time zone. MySQL's ``NOW()`` is the time
    the statement started.
  - SQL Server: ``SYSDATETIMEOFFSET()``.
  - SQLite: ``DATETIME('now')``, a string in UTC.
  - Oracle: ``SYSTIMESTAMP``.

Exponent and Logarithm
----------------------

Exponents and logarithms accept any number, which is converted to a
``DOUBLE PRECISION`` (so ``LN(10)`` is the same as ``LN(10e0)``), and they
return a ``DOUBLE PRECISION``. A result that is too large or too small to be a
``DOUBLE PRECISION`` is a ``22003`` error (numeric value out of range).

EXP
^^^

.. code-block:: sql

   EXP(DOUBLE PRECISION) DOUBLE PRECISION

Exponential, *e* (2.718281828459...) raised to the power of the argument. The
result is always greater than 0, so an argument greater than about 709.78 (the
result is too large) or less than about -745.13 (the result is too small) is a
``22003`` error.

**Examples**

.. code-block:: sql

  VALUES EXP(3.7);
  -- COL1: 40.447304360067e0

  VALUES EXP(1);
  -- COL1: 2.718281828459e0

  VALUES EXP(1000);
  -- error 22003: numeric value out of range

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:** ``EXP`` in all of them.

LN
^^

.. code-block:: sql

   LN(DOUBLE PRECISION) DOUBLE PRECISION

Natural logarithm (base *e*). The argument must be greater than 0, otherwise
it's a ``2201E`` error (invalid argument for natural logarithm).

**Examples**

.. code-block:: sql

  VALUES LN(13.7);
  -- COL1: 2.617395832834e0

  VALUES LN(1);
  -- COL1: 0e0

  VALUES LN(0);
  -- error 2201E: invalid argument for natural logarithm

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:**

  - PostgreSQL, MySQL, SQLite and Oracle: ``LN``.
  - SQL Server: ``LOG(x)``. MySQL also has ``LOG(x)``, which is the natural
    logarithm there too, but in PostgreSQL and SQLite ``LOG(x)`` is base 10.

LOG
^^^

.. code-block:: sql

   LOG(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION

``LOG(BASE, NUMBER)`` is the logarithm of ``NUMBER`` in ``BASE``, so ``LOG(2, 8)`` is 3. ``NUMBER`` must be
greater than 0, and ``BASE`` must be greater than 0 and not 1, otherwise it's a
``22003`` error (numeric value out of range). A ``BASE`` between 0 and 1 gives
the negative of the logarithm in ``1 / BASE``.

``LOG(10, x)`` is the same as ``LOG10(x)``, and ``LN(x)`` is the logarithm in
base *e*. There is no ``LOG`` with one argument, because other databases
disagree on its base.

**Examples**

.. code-block:: sql

  VALUES LOG(2, 8);
  -- COL1: 3e0

  VALUES LOG(10, 1000);
  -- COL1: 3e0

  VALUES LOG(2.5, 13.7);
  -- COL1: 2.856512394795e0

  VALUES LOG(1, 10);
  -- error 22003: numeric value out of range

**Compatibility**

- **SQL standard:** T623 (general logarithm functions).
- **Other databases:**

  - PostgreSQL, MySQL, SQLite and Oracle: ``LOG(base, number)``.
  - SQL Server: ``LOG(number, base)``, the arguments are the other way around.

LOG10
^^^^^

.. code-block:: sql

   LOG10(DOUBLE PRECISION) DOUBLE PRECISION

Logarithm in base 10, the same as ``LOG(10, NUMBER)``. The argument must be
greater than 0, otherwise it's a ``22003`` error (numeric value out of range).

**Examples**

.. code-block:: sql

  VALUES LOG10(13.7);
  -- COL1: 1.136720567156e0

  VALUES LOG10(1000);
  -- COL1: 3e0

  VALUES LOG10(0);
  -- error 22003: numeric value out of range

**Compatibility**

- **SQL standard:** T624 (common logarithm functions).
- **Other databases:**

  - PostgreSQL, MySQL, SQLite and SQL Server: ``LOG10``. PostgreSQL and SQLite
    also have ``LOG(x)``, which is base 10 there.
  - Oracle: ``LOG(10, x)``.

POWER
^^^^^

.. code-block:: sql

   POWER(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION

``POWER(BASE, EXPONENT)`` is ``BASE`` raised to the power of ``EXPONENT``. Both are converted to
``DOUBLE PRECISION``, so the result is always approximate, even for integers.

- ``POWER(0, 0)`` is 1.
- A ``BASE`` of 0 with a negative ``EXPONENT`` is a ``2201F`` error (invalid
  argument for power function).
- A negative ``BASE`` needs an ``EXPONENT`` that is a whole number, otherwise
  it's a ``2201F`` error.
- A result that is too large or too small (but not 0) is a ``22003`` error,
  such as ``POWER(10, 400)``.

**Examples**

.. code-block:: sql

  VALUES POWER(3.7, 2.5);
  -- COL1: 26.333240780428e0

  VALUES POWER(2, 10);
  -- COL1: 1024e0

  VALUES POWER(-2, 3);
  -- COL1: -8e0

  VALUES POWER(0, -1);
  -- error 2201F: invalid argument for power function

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:**

  - PostgreSQL: ``POWER`` or the ``^`` operator.
  - MySQL and SQLite: ``POWER`` or ``POW``.
  - SQL Server and Oracle: ``POWER``.

SQRT
^^^^

.. code-block:: sql

   SQRT(DOUBLE PRECISION) DOUBLE PRECISION

Square root. The result is approximate, even for a perfect square. The argument
can't be negative, otherwise it's a ``2201F`` error (invalid argument for power
function), because ``SQRT(x)`` is the same as ``POWER(x, 0.5)``.

**Examples**

.. code-block:: sql

  VALUES SQRT(3.7);
  -- COL1: 1.923538406167e0

  VALUES SQRT(16);
  -- COL1: 4e0

  VALUES SQRT(-1);
  -- error 2201F: invalid argument for power function

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:** ``SQRT`` in all of them. MySQL and SQLite return
  ``NULL`` for a negative argument.

Rounding
--------

Rounding functions round a number to an integer, up (``CEIL``) or down
(``FLOOR``). They accept any number. An exact number (such as an ``INTEGER``
or ``DECIMAL``) is converted to a ``NUMERIC``, and an approximate number (``REAL``
or ``DOUBLE PRECISION``) to a ``DOUBLE PRECISION``.

CEIL
^^^^

.. code-block:: sql

   CEIL(DOUBLE PRECISION) DOUBLE PRECISION
   CEIL(NUMERIC(p, s)) NUMERIC(p - s + 1, 0)

Round up to the nearest integer (towards positive infinity), so ``CEIL(-3.7)``
is -3.

An exact numeric argument (such as ``INTEGER`` or ``DECIMAL``) returns a
``NUMERIC`` with a scale of 0. It has one more digit than the integer part of
the argument, because rounding up may need one, such as ``CEIL(9.5)`` is 10.
An integer argument has the precision of its type, such as ``NUMERIC(10)`` for
an ``INTEGER``. A ``REAL`` argument returns a ``DOUBLE PRECISION``.

**Examples**

.. code-block:: sql

  VALUES CEIL(3.7e0);
  -- COL1: 4e0

  VALUES CEIL(3.3e0);
  -- COL1: 4e0

  VALUES CEIL(-3.7e0);
  -- COL1: -3e0

  VALUES CEIL(-3.3e0);
  -- COL1: -3e0

  VALUES CEIL(3.7);
  -- COL1: 4

  VALUES CEIL(9.5);
  -- COL1: 10

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:**

  - PostgreSQL, MySQL and SQLite: ``CEIL`` and ``CEILING``.
  - SQL Server: ``CEILING``.
  - Oracle: ``CEIL``.

CEILING
^^^^^^^

.. code-block:: sql

   CEILING(DOUBLE PRECISION) DOUBLE PRECISION
   CEILING(NUMERIC(p, s)) NUMERIC(p - s + 1, 0)

``CEILING`` is another name for ``CEIL``, see ``CEIL``.

**Examples**

.. code-block:: sql

  VALUES CEILING(3.7e0);
  -- COL1: 4e0

  VALUES CEILING(-3.7);
  -- COL1: -3

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:** see ``CEIL``.

FLOOR
^^^^^

.. code-block:: sql

   FLOOR(DOUBLE PRECISION) DOUBLE PRECISION
   FLOOR(NUMERIC(p, s)) NUMERIC(p - s + 1, 0)

Round down to the nearest integer (towards negative infinity), so
``FLOOR(-3.3)`` is -4.

An exact numeric argument (such as ``INTEGER`` or ``DECIMAL``) returns a
``NUMERIC`` with a scale of 0. It has one more digit than the integer part of
the argument, because rounding down may need one, such as ``FLOOR(-9.5)`` is
-10. An integer argument has the precision of its type, such as
``NUMERIC(10)`` for an ``INTEGER``. A ``REAL`` argument returns a
``DOUBLE PRECISION``.

**Examples**

.. code-block:: sql

  VALUES FLOOR(3.7e0);
  -- COL1: 3e0

  VALUES FLOOR(3.3e0);
  -- COL1: 3e0

  VALUES FLOOR(-3.7e0);
  -- COL1: -4e0

  VALUES FLOOR(-3.3e0);
  -- COL1: -4e0

  VALUES FLOOR(3.7);
  -- COL1: 3

  VALUES FLOOR(-3.7);
  -- COL1: -4

  VALUES FLOOR(-3);
  -- COL1: -3

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:** ``FLOOR`` in all of them.

Statistical
-----------

Statistical functions are aggregate functions (see *Aggregate*) that describe
the spread of a set of numbers, or the relationship between two sets of
numbers. They accept any number, which is converted to a ``DOUBLE PRECISION``,
and they return a ``DOUBLE PRECISION`` (except ``REGR_COUNT``). They can't be
used with ``DISTINCT`` or ``ALL`` (a ``42601`` error).

The functions with two arguments, ``FUNCTION(Y, X)``, treat each row as a
point, where ``Y`` is the dependent variable (the vertical axis) and ``X`` is
the independent variable (the horizontal axis). Note that ``Y`` is first. A
row is ignored if either value is ``NULL``, with a ``01003`` warning. The
regression functions describe the line that fits the points best (the
least-squares line), ``Y = REGR_SLOPE(Y, X) * X + REGR_INTERCEPT(Y, X)``.

``NULL`` is returned when there are no rows, and for the functions that can't
be calculated from the rows (such as the sample variance of one row). A result
that is too large or too small to be a ``DOUBLE PRECISION`` is a ``22003``
error, except for ``CORR``, ``REGR_R2``, ``REGR_SLOPE`` and
``REGR_INTERCEPT``, which return ``NULL`` instead.

The results are calculated so that they're still accurate when the values are
very large or very close together, which can make them slightly different
(in the last digits) from the formulas below.

The examples use this table:

.. code-block:: sql

  CREATE TABLE points (x FLOAT, y FLOAT);
  INSERT INTO points (x, y) VALUES
    (1e0, 1e0), (2e0, 3e0), (3e0, 2e0), (4e0, 5e0), (5e0, NULL);

CORR
^^^^

.. code-block:: sql

   CORR(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION

``CORR(Y, X)`` is the correlation coefficient (Pearson's), between -1 and 1. It
is 1 when the points are on a line that goes up, -1 when they're on a line that
goes down, and close to 0 when ``Y`` doesn't depend on ``X``. It's
``REGR_SXY / SQRT(REGR_SXX * REGR_SYY)``.

The result is ``NULL`` if there are no rows, or if every ``X`` (or every ``Y``)
is the same.

**Examples**

.. code-block:: sql

  SELECT CORR(y, x), CORR(-y, x) FROM points;
  -- COL1: 0.83152184062e0 COL2: -0.83152184062e0

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions). The standard defines ``CORR`` as the square root of ``REGR_R2``, which is never negative. vsql returns the sign as well, like the other databases.
- **Other databases:** PostgreSQL and Oracle: ``CORR``. MySQL, SQLite and SQL Server don't have it.

COVAR_POP
^^^^^^^^^

.. code-block:: sql

   COVAR_POP(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION

``COVAR_POP(Y, X)`` is the population covariance, ``REGR_SXY / N`` where ``N``
is the number of rows. It's positive when ``Y`` tends to be larger when ``X`` is
larger, and negative when ``Y`` tends to be smaller.

**Examples**

.. code-block:: sql

  SELECT COVAR_POP(y, x) FROM points;
  -- COL1: 1.375e0

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:** PostgreSQL and Oracle: ``COVAR_POP``. MySQL, SQLite and SQL Server don't have it.

COVAR_SAMP
^^^^^^^^^^

.. code-block:: sql

   COVAR_SAMP(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION

``COVAR_SAMP(Y, X)`` is the sample covariance, ``REGR_SXY / (N - 1)`` where
``N`` is the number of rows. The result is ``NULL`` if there are less than two
rows.

**Examples**

.. code-block:: sql

  SELECT COVAR_SAMP(y, x) FROM points;
  -- COL1: 1.833333333333e0

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:** PostgreSQL and Oracle: ``COVAR_SAMP``. MySQL, SQLite and SQL Server don't have it.

REGR_AVGX
^^^^^^^^^

.. code-block:: sql

   REGR_AVGX(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION

``REGR_AVGX(Y, X)`` is the average of ``X``. Unlike ``AVG(X)``, it ignores the
rows where ``Y`` is ``NULL``.

**Examples**

.. code-block:: sql

  SELECT REGR_AVGX(y, x), AVG(x) FROM points;
  -- COL1: 2.5e0 COL2: 3e0

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:** PostgreSQL and Oracle: ``REGR_AVGX``. MySQL, SQLite and SQL Server don't have it.

REGR_AVGY
^^^^^^^^^

.. code-block:: sql

   REGR_AVGY(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION

``REGR_AVGY(Y, X)`` is the average of ``Y``. Unlike ``AVG(Y)``, it ignores the
rows where ``X`` is ``NULL``.

**Examples**

.. code-block:: sql

  SELECT REGR_AVGY(y, x) FROM points;
  -- COL1: 2.75e0

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:** PostgreSQL and Oracle: ``REGR_AVGY``. MySQL, SQLite and SQL Server don't have it.

REGR_COUNT
^^^^^^^^^^

.. code-block:: sql

   REGR_COUNT(DOUBLE PRECISION, DOUBLE PRECISION) INTEGER

``REGR_COUNT(Y, X)`` is the number of rows where neither ``Y`` nor ``X`` is
``NULL``. It's 0 when there are no rows.

**Examples**

.. code-block:: sql

  SELECT COUNT(*), REGR_COUNT(y, x) FROM points;
  -- COL1: 5 COL2: 4

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:** PostgreSQL and Oracle: ``REGR_COUNT``. MySQL, SQLite and SQL Server don't have it. PostgreSQL returns a ``BIGINT``.

REGR_INTERCEPT
^^^^^^^^^^^^^^

.. code-block:: sql

   REGR_INTERCEPT(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION

``REGR_INTERCEPT(Y, X)`` is the value of ``Y`` where the line that fits the
points crosses ``X = 0``, ``REGR_AVGY - REGR_SLOPE * REGR_AVGX``.

The result is ``NULL`` if there are no rows, or if every ``X`` is the same
(because the line would be vertical).

**Examples**

.. code-block:: sql

  SELECT REGR_INTERCEPT(y, x) FROM points;
  -- COL1: 0e0

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:** PostgreSQL and Oracle: ``REGR_INTERCEPT``. MySQL, SQLite and SQL Server don't have it.

REGR_R2
^^^^^^^

.. code-block:: sql

   REGR_R2(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION

``REGR_R2(Y, X)`` is the coefficient of determination, between 0 and 1. It's
how well the line fits the points, from 0 (not at all) to 1 (every point is on
the line). It's the square of ``CORR``.

The result is ``NULL`` if there are no rows, or if every ``X`` is the same.
Otherwise, it's 1 if every ``Y`` is the same (because the line is horizontal).

**Examples**

.. code-block:: sql

  SELECT REGR_R2(y, x) FROM points;
  -- COL1: 0.691428571429e0

  SELECT REGR_R2(2, x) FROM points;
  -- COL1: 1e0

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:** PostgreSQL and Oracle: ``REGR_R2``. MySQL, SQLite and SQL Server don't have it.

REGR_SLOPE
^^^^^^^^^^

.. code-block:: sql

   REGR_SLOPE(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION

``REGR_SLOPE(Y, X)`` is the slope of the line that fits the points, which is
how much ``Y`` increases for each 1 that ``X`` increases, ``REGR_SXY /
REGR_SXX``.

The result is ``NULL`` if there are no rows, or if every ``X`` is the same
(because the line would be vertical).

**Examples**

.. code-block:: sql

  SELECT REGR_SLOPE(y, x) FROM points;
  -- COL1: 1.1e0

  SELECT REGR_SLOPE(y, 2) FROM points;
  -- COL1: NULL

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:** PostgreSQL and Oracle: ``REGR_SLOPE``. MySQL, SQLite and SQL Server don't have it.

REGR_SXX
^^^^^^^^

.. code-block:: sql

   REGR_SXX(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION

``REGR_SXX(Y, X)`` is the sum of the squares of the differences between each
``X`` and the average of ``X``, ``SUM(X * X) - SUM(X) * SUM(X) / N`` where ``N``
is the number of rows. It's 0 if every ``X`` is the same.

**Examples**

.. code-block:: sql

  SELECT REGR_SXX(y, x) FROM points;
  -- COL1: 5e0

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:** PostgreSQL and Oracle: ``REGR_SXX``. MySQL, SQLite and SQL Server don't have it.

REGR_SXY
^^^^^^^^

.. code-block:: sql

   REGR_SXY(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION

``REGR_SXY(Y, X)`` is the sum of the products of the differences between each
``X`` and the average of ``X``, and each ``Y`` and the average of ``Y``,
``SUM(X * Y) - SUM(X) * SUM(Y) / N`` where ``N`` is the number of rows.

**Examples**

.. code-block:: sql

  SELECT REGR_SXY(y, x) FROM points;
  -- COL1: 5.5e0

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:** PostgreSQL and Oracle: ``REGR_SXY``. MySQL, SQLite and SQL Server don't have it.

REGR_SYY
^^^^^^^^

.. code-block:: sql

   REGR_SYY(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION

``REGR_SYY(Y, X)`` is the sum of the squares of the differences between each
``Y`` and the average of ``Y``, ``SUM(Y * Y) - SUM(Y) * SUM(Y) / N`` where ``N``
is the number of rows. It's 0 if every ``Y`` is the same.

**Examples**

.. code-block:: sql

  SELECT REGR_SYY(y, x) FROM points;
  -- COL1: 8.75e0

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:** PostgreSQL and Oracle: ``REGR_SYY``. MySQL, SQLite and SQL Server don't have it.

STDDEV_POP
^^^^^^^^^^

.. code-block:: sql

   STDDEV_POP(DOUBLE PRECISION) DOUBLE PRECISION

``STDDEV_POP(X)`` is the population standard deviation, the square root of
``VAR_POP``.

**Examples**

.. code-block:: sql

  SELECT STDDEV_POP(y) FROM points;
  -- COL1: 1.479019945775e0

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:**

  - PostgreSQL, MySQL (also ``STD`` and ``STDDEV``) and Oracle:
    ``STDDEV_POP``.
  - SQL Server: ``STDEVP``.
  - SQLite doesn't have it.

STDDEV_SAMP
^^^^^^^^^^^

.. code-block:: sql

   STDDEV_SAMP(DOUBLE PRECISION) DOUBLE PRECISION

``STDDEV_SAMP(X)`` is the sample standard deviation, the square root of
``VAR_SAMP``. The result is ``NULL`` if there are less than two values.

**Examples**

.. code-block:: sql

  SELECT STDDEV_SAMP(y) FROM points;
  -- COL1: 1.70782512766e0

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:**

  - PostgreSQL (also ``STDDEV``), MySQL and Oracle: ``STDDEV_SAMP``. In MySQL,
    ``STDDEV`` is ``STDDEV_POP``. In Oracle, ``STDDEV`` is 0 for one value.
  - SQL Server: ``STDEV``.
  - SQLite doesn't have it.

VAR_POP
^^^^^^^

.. code-block:: sql

   VAR_POP(DOUBLE PRECISION) DOUBLE PRECISION

``VAR_POP(X)`` is the population variance, the average of the squares of
the differences between each value and the average,
``(SUM(X * X) - SUM(X) * SUM(X) / N) / N`` where ``N`` is the number of values.

**Examples**

.. code-block:: sql

  SELECT VAR_POP(y) FROM points;
  -- COL1: 2.1875e0

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:**

  - PostgreSQL, MySQL (also ``VARIANCE``) and Oracle: ``VAR_POP``.
  - SQL Server: ``VARP``.
  - SQLite doesn't have it.

VAR_SAMP
^^^^^^^^

.. code-block:: sql

   VAR_SAMP(DOUBLE PRECISION) DOUBLE PRECISION

``VAR_SAMP(X)`` is the sample variance, ``(SUM(X * X) - SUM(X) * SUM(X) /
N) / (N - 1)`` where ``N`` is the number of values. The result is ``NULL`` if
there are less than two values.

**Examples**

.. code-block:: sql

  SELECT VAR_SAMP(y) FROM points;
  -- COL1: 2.916666666667e0

  SELECT VAR_SAMP(y) FROM points WHERE x = 1;
  -- COL1: NULL

**Compatibility**

- **SQL standard:** T621 (enhanced numeric functions).
- **Other databases:**

  - PostgreSQL (also ``VARIANCE``), MySQL and Oracle: ``VAR_SAMP``. In MySQL,
    ``VARIANCE`` is ``VAR_POP``. In Oracle, ``VARIANCE`` is 0 for one value.
  - SQL Server: ``VAR``.
  - SQLite doesn't have it.

Session
-------

Session functions return information about the current connection. There are
no parentheses after their names.

CURRENT_CATALOG
^^^^^^^^^^^^^^^

.. code-block:: sql

   CURRENT_CATALOG CHARACTER VARYING

``CURRENT_CATALOG`` is the name of the current catalog, which is the file name
up to the first ``.``. So, if the complete file path is ``/tmp/mydb.cool.vsql``
the ``CURRENT_CATALOG`` would be ``mydb``. It can be changed with
:doc:`set-catalog`.

When using in-memory databases, the ``CURRENT_CATALOG`` will be ``:memory:``.

**Examples**

.. code-block:: sql

  VALUES CURRENT_CATALOG;
  -- COL1: :memory:

**Compatibility**

- **SQL standard:** F762 (CURRENT_CATALOG).
- **Other databases:**

  - PostgreSQL: ``CURRENT_CATALOG`` or ``CURRENT_DATABASE()``.
  - SQL Server: ``DB_NAME()``.
  - MySQL, SQLite and Oracle have no catalogs.

CURRENT_SCHEMA
^^^^^^^^^^^^^^

.. code-block:: sql

   CURRENT_SCHEMA CHARACTER VARYING

``CURRENT_SCHEMA`` reports the current schema. The current schema is where
objects (such as tables, sequences, etc) are located or created when their name
doesn't include a schema. The default schema is ``PUBLIC``. The current schema
can be changed with :doc:`set-schema`.

**Examples**

.. code-block:: sql

  VALUES CURRENT_SCHEMA;
  -- COL1: PUBLIC

**Compatibility**

- **SQL standard:** F763 (CURRENT_SCHEMA).
- **Other databases:**

  - PostgreSQL: ``CURRENT_SCHEMA``.
  - MySQL: ``DATABASE()`` (a MySQL database is a schema).
  - SQL Server: ``SCHEMA_NAME()``.
  - Oracle: ``SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')``.
  - SQLite has no schemas.

String
------

String functions accept a ``CHARACTER`` or ``CHARACTER VARYING`` (see
:doc:`text`). A ``CHARACTER(n)`` value always has ``n`` characters, so its
padding spaces are counted and searched like any other character.

Lengths and positions are counted in characters, where a multibyte character
(such as ``😊``) counts as one, unless the function says otherwise. The first
character is at position 1.

CHAR_LENGTH
^^^^^^^^^^^

.. code-block:: sql

   CHAR_LENGTH(CHARACTER VARYING) INTEGER

Returns the number of characters (a multibyte character is counted as a single
character). The length of an empty string is 0, and the length of a
``CHARACTER(n)`` is ``n``, including the padding.

**Examples**

.. code-block:: sql

  VALUES CHAR_LENGTH('😊£');
  -- COL1: 2

  VALUES CHAR_LENGTH(CAST('ab' AS CHARACTER(5)));
  -- COL1: 5

**Compatibility**

- **SQL standard:** Core SQL (E021-04).
- **Other databases:**

  - PostgreSQL: ``CHAR_LENGTH``, ``CHARACTER_LENGTH`` or ``LENGTH``, which don't
    count the padding of a ``CHARACTER``.
  - MySQL: ``CHAR_LENGTH`` or ``CHARACTER_LENGTH`` (``LENGTH`` is in bytes).
  - SQLite and Oracle: ``LENGTH``.
  - SQL Server: ``LEN``, which doesn't count spaces at the end.

CHARACTER_LENGTH
^^^^^^^^^^^^^^^^

.. code-block:: sql

   CHARACTER_LENGTH(CHARACTER VARYING) INTEGER

``CHARACTER_LENGTH`` is another name for ``CHAR_LENGTH``, see
``CHAR_LENGTH``.

**Compatibility**

- **SQL standard:** Core SQL (E021-04).
- **Other databases:** see ``CHAR_LENGTH``.

LOWER
^^^^^

.. code-block:: sql

   LOWER(CHARACTER VARYING) CHARACTER VARYING

Returns the input string converted to lower-case. The result has the same type
as the input, such as ``CHARACTER(5)`` for ``LOWER('Hello')``.

The full Unicode case mappings are used, so a character may become several
characters. A result that's longer than the maximum length of the type is
truncated, with a warning (``01004``) if any of the removed characters aren't
spaces. See ``UPPER`` for an example.

**Examples**

.. code-block:: sql

  VALUES LOWER('Hello');
  -- COL1: hello

  VALUES LOWER('ÀÉ');
  -- COL1: àé

**Compatibility**

- **SQL standard:** Core SQL (E021-08).
- **Other databases:** ``LOWER`` in all of them, and ``LCASE`` in MySQL. SQLite
  only converts ASCII letters (unless it's built with ICU).

OCTET_LENGTH
^^^^^^^^^^^^

.. code-block:: sql

   OCTET_LENGTH(CHARACTER VARYING) INTEGER

Returns the length in bytes, which is the length of the string encoded as
UTF-8. A character can be 1 to 4 bytes.

**Examples**

.. code-block:: sql

  VALUES OCTET_LENGTH('😊£');
  -- COL1: 6

  VALUES OCTET_LENGTH('abc');
  -- COL1: 3

**Compatibility**

- **SQL standard:** Core SQL (E021-05).
- **Other databases:**

  - PostgreSQL and SQLite: ``OCTET_LENGTH``.
  - MySQL: ``OCTET_LENGTH`` or ``LENGTH``.
  - SQL Server: ``DATALENGTH``, which is the length in the encoding of the
    value.
  - Oracle: ``LENGTHB``.

OVERLAY
^^^^^^^

.. code-block:: text

   OVERLAY(
     STRING
     PLACING REPLACEMENT
     FROM START
     [ FOR LENGTH ]
     [ USING { CHARACTERS | OCTETS } ]
   )

.. code-block:: sql

   OVERLAY(CHARACTER VARYING(n) PLACING CHARACTER VARYING(m) FROM INTEGER) CHARACTER VARYING(2n + m)
   OVERLAY(CHARACTER VARYING(n) PLACING CHARACTER VARYING(m) FROM INTEGER FOR INTEGER) CHARACTER VARYING(2n + m)

Replaces ``LENGTH`` characters of ``STRING``, starting at ``START``, with
``REPLACEMENT``. ``REPLACEMENT`` can be shorter or longer than the part it
replaces, so the string can shrink or grow. If ``LENGTH`` is not provided, it's
the length of ``REPLACEMENT``, so the same number of characters are
overwritten.

``OVERLAY`` is defined by the SQL standard as:

.. code-block:: sql

  SUBSTRING(STRING FROM 1 FOR START - 1)
    || REPLACEMENT
    || SUBSTRING(STRING FROM START + LENGTH)

So it follows the same rules as ``SUBSTRING`` and ``||``:

- A ``LENGTH`` of 0 inserts ``REPLACEMENT`` before ``START``, and an empty
  ``REPLACEMENT`` deletes the characters.
- A ``START`` after the end of ``STRING`` appends ``REPLACEMENT``, and a
  ``LENGTH`` that goes past the end replaces the rest of ``STRING``.
- A ``START`` before 1 is a ``22011`` error (substring error), because the first
  ``SUBSTRING`` has a negative length.
- A negative ``LENGTH`` isn't an error, the rest of ``STRING`` starts earlier
  and repeats some characters. So ``OVERLAY('abcdef' PLACING 'X' FROM 3 FOR -1)``
  is ``'abXbcdef'``.
- ``START`` and ``LENGTH`` must be integers (or a ``NUMERIC`` or ``DECIMAL``
  with a scale of 0), otherwise it's a ``42601`` error.
- The result is a ``CHARACTER VARYING`` that's long enough for both
  ``SUBSTRING`` results and ``REPLACEMENT``, even though the value can never be
  that long.

``USING CHARACTERS`` (the default) counts ``START`` and ``LENGTH`` in
characters, and ``USING OCTETS`` counts them in bytes, like ``SUBSTRING``.
Without ``FOR``, ``USING OCTETS`` replaces as many bytes as there are in
``REPLACEMENT``.

**Examples**

.. code-block:: sql

  VALUES OVERLAY('Hello World' PLACING 'There' FROM 7);
  -- COL1: Hello There

  VALUES OVERLAY('Hello World' PLACING 'Big ' FROM 7 FOR 0);
  -- COL1: Hello Big World

  VALUES OVERLAY('Hello World' PLACING '' FROM 6 FOR 6);
  -- COL1: Hello

  VALUES OVERLAY('abc' PLACING 'XYZ' FROM 2);
  -- COL1: aXYZ

  VALUES OVERLAY('abc' PLACING 'X' FROM 10);
  -- COL1: abcX

  VALUES OVERLAY('abc' PLACING 'X' FROM 0);
  -- error 22011: substring error

**Compatibility**

- **SQL standard:** T312 (OVERLAY function). ``USING`` is part of T061 (UCS
  support).
- **Other databases:**

  - PostgreSQL: ``OVERLAY``, with the same syntax (without ``USING``).
  - MySQL: ``INSERT(string, start, length, replacement)``. The ``LENGTH`` is
    required, and a ``START`` outside of the string returns ``STRING``
    unchanged.
  - SQL Server: ``STUFF(string, start, length, replacement)``. The ``LENGTH``
    is required, and a ``START`` outside of the string returns ``NULL``.
  - SQLite and Oracle: ``SUBSTR(...) || replacement || SUBSTR(...)``.

POSITION
^^^^^^^^

.. code-block:: sql

   POSITION(CHARACTER VARYING IN CHARACTER VARYING) INTEGER

``POSITION(SEARCH IN STRING)`` returns the start of the left most (first)
match of ``SEARCH`` within ``STRING``. 1 will be the smallest index on a match and 0 is returned if
``SEARCH`` does not exist in ``STRING``. The position is counted in characters
(a multibyte character counts as one).

Matching is case-sensitive. An empty ``SEARCH`` is found at the start of any
``STRING`` (even an empty one), so the result is 1.

**Examples**

.. code-block:: sql

  VALUES POSITION('He' IN 'hello Hello');
  -- COL1: 7

  VALUES POSITION('xx' IN 'hello Hello');
  -- COL1: 0

  VALUES POSITION('£' IN '😊£');
  -- COL1: 2

**Compatibility**

- **SQL standard:** Core SQL (E021-11).
- **Other databases:**

  - PostgreSQL: ``POSITION(search IN string)`` or ``STRPOS(string, search)``.
  - MySQL: ``POSITION(search IN string)``, ``LOCATE(search, string)`` or
    ``INSTR(string, search)``.
  - SQLite and Oracle: ``INSTR(string, search)``.
  - SQL Server: ``CHARINDEX(search, string)``.

SUBSTRING
^^^^^^^^^

.. code-block:: text

   SUBSTRING(
     STRING
     FROM START
     [ FOR LENGTH ]
     [ USING { CHARACTERS | OCTETS } ]
   )

   SUBSTRING(STRING SIMILAR PATTERN ESCAPE ESCAPE_CHARACTER)

.. code-block:: sql

   SUBSTRING(CHARACTER VARYING(n) FROM INTEGER) CHARACTER VARYING(n)
   SUBSTRING(CHARACTER VARYING(n) FROM INTEGER FOR INTEGER) CHARACTER VARYING(n)
   SUBSTRING(CHARACTER VARYING(n) SIMILAR CHARACTER VARYING ESCAPE CHARACTER) CHARACTER VARYING(n)

Returns part of ``STRING``. The result is a ``CHARACTER VARYING`` with the
maximum length of ``STRING``.

``START`` starts at 1 for the first character or byte. If ``START`` is after
the end the returned value will be empty.

If ``LENGTH`` is not provided, all characters or bytes until the end will be
included. Otherwise, only ``LENGTH`` will be included. If ``LENGTH`` goes
beyond the end of the string it will only be used until the end. ``LENGTH``
must not be negative, otherwise a ``22011`` error (substring error) is raised.

``START`` and ``LENGTH`` must be integers (or a ``NUMERIC`` or ``DECIMAL`` with
a scale of 0), so ``SUBSTRING('hello' FROM 2.5)`` is an error. A dynamic
parameter (``?``) can be any number that's a whole number.

A ``START`` before 1 is allowed, but the positions before the first character
still count towards ``LENGTH``. So ``SUBSTRING('hello' FROM 0 FOR 3)`` is
``'he'``, and ``SUBSTRING('hello' FROM -5 FOR 3)`` is empty.

If ``CHARACTERS`` is specified ``START`` and ``LENGTH`` will count in characters
(this works with multibyte characters) whereas ``OCTETS`` will strictly count
in bytes. If ``USING`` is not provided, ``CHARACTERS`` will be used.

With ``SIMILAR``, the part of ``STRING`` that is returned is found with a
pattern instead. ``PATTERN`` must have exactly two of ``ESCAPE_CHARACTER``
followed by a double quote (``"``), otherwise a ``2200C`` error (invalid use of
escape character) is raised. They split it into three patterns, and the whole
of ``STRING`` must match all three together, the same as ``SIMILAR TO`` (see
:doc:`expressions`). The result is the part that matches the middle pattern,
or ``NULL`` if ``STRING`` doesn't match.

The first pattern matches as little as it can from the start, and the last
pattern matches as little as it can from the end, so the middle pattern gets
the rest. Each pattern can be empty, otherwise it must be a valid pattern on
its own (a ``2201B`` error).

**Examples**

.. code-block:: sql

  VALUES SUBSTRING('hello' FROM 2);
  -- COL1: ello

  VALUES SUBSTRING('hello' FROM 20);
  -- COL1:

  VALUES SUBSTRING('hello world' FROM 3 FOR 5);
  -- COL1: llo w

  VALUES SUBSTRING('hello' FROM 0 FOR 3);
  -- COL1: he

  VALUES SUBSTRING('Жabڣc' FROM 4 USING OCTETS);
  -- COL1: bڣc

  VALUES SUBSTRING('hello' FROM 2 FOR -1);
  -- error 22011: substring error

  VALUES SUBSTRING('foobar' SIMILAR '%#"o_b#"%' ESCAPE '#');
  -- COL1: oob

  VALUES SUBSTRING('aaabbb' SIMILAR 'a+#"%#"b*' ESCAPE '#');
  -- COL1: aabbb

  VALUES SUBSTRING('foobar' SIMILAR '#"o_b#"%' ESCAPE '#');
  -- COL1: NULL

  VALUES SUBSTRING('foobar' SIMILAR '%o_b%' ESCAPE '#');
  -- error 2200C: invalid use of escape character

**Compatibility**

- **SQL standard:** Core SQL (E021-06). ``USING`` is part of T061 (UCS
  support), and ``SIMILAR`` is T581 (Regular expression substring function).
- **Other databases:** none of them have ``USING``.

  - PostgreSQL: ``SUBSTRING(string FROM start FOR length)``,
    ``SUBSTRING(string, start, length)`` or ``SUBSTR``.
  - MySQL: ``SUBSTRING(string FROM start FOR length)``,
    ``SUBSTRING(string, start, length)`` or ``SUBSTR``.
  - SQLite: ``SUBSTR(string, start, length)`` or ``SUBSTRING``.
  - SQL Server: ``SUBSTRING(string, start, length)``, the length is required.
  - Oracle: ``SUBSTR(string, start, length)``.

  Only PostgreSQL has ``SIMILAR`` (and also the older
  ``SUBSTRING(string FROM pattern FOR escape)``). The others use a different
  regular expression function, such as ``REGEXP_SUBSTR``.

  A negative ``START`` counts from the end of the string in MySQL, SQLite and
  Oracle, so ``SUBSTR('hello', -3)`` is ``'llo'`` there.

TRIM
^^^^

.. code-block:: text

  TRIM(
    [ [ { LEADING | TRAILING | BOTH } ] [ CHARACTER ] FROM ]
    STRING
  )

.. code-block:: sql

   TRIM(CHARACTER VARYING(n)) CHARACTER VARYING(n)

Removes ``CHARACTER`` from the start (``LEADING``), the end (``TRAILING``) or
both ends (``BOTH``) of ``STRING``, as many times as it's repeated. The result
is a ``CHARACTER VARYING`` with the maximum length of ``STRING``.

If ``LEADING``, ``TRAILING`` or ``BOTH`` is not provided, ``BOTH`` is used.

If ``CHARACTER`` is not provided, a space (``' '``) is used. Only that
character is removed, not other white space such as tabs or new lines.
``CHARACTER`` must be exactly one character, otherwise it's a ``22027`` error
(trim error).

``TRIM(FROM STRING)``, without ``LEADING``, ``TRAILING``, ``BOTH`` or
``CHARACTER``, is a vsql extension flagged by ``V404-01`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES TRIM('  hello world ');
  -- COL1: hello world

  VALUES TRIM('a' FROM 'aaababccaa');
  -- COL1: babcc

  VALUES TRIM(LEADING 'a' FROM 'aaababccaa');
  -- COL1: babccaa

  VALUES TRIM(TRAILING 'a' FROM 'aaababccaa');
  -- COL1: aaababcc

  VALUES TRIM('ab' FROM 'abxab');
  -- error 22027: trim error

**Compatibility**

- **SQL standard:** Core SQL (E021-09).
- **Other databases:**

  - PostgreSQL: ``TRIM``, ``BTRIM``, ``LTRIM`` and ``RTRIM``. The characters
    can be more than one, any of them is removed.
  - MySQL: ``TRIM``. The characters can be more than one, and they're removed
    as a whole string. ``LTRIM`` and ``RTRIM`` only remove spaces.
  - SQLite: ``TRIM(string, characters)``, ``LTRIM`` and ``RTRIM``, any of the
    characters is removed.
  - SQL Server: ``TRIM(characters FROM string)``, ``LTRIM`` and ``RTRIM``.
  - Oracle: ``TRIM``, which only allows one character like the standard, and
    ``LTRIM`` and ``RTRIM`` with any number of characters.

UPPER
^^^^^

.. code-block:: sql

   UPPER(CHARACTER VARYING) CHARACTER VARYING

Returns the input string converted to upper-case. The result has the same type
as the input, such as ``CHARACTER(5)`` for ``UPPER('Hello')``.

The full Unicode case mappings are used, so a character may become several
characters, such as ``ß`` to ``SS``. A result that's longer than the maximum
length of the type is truncated, with a warning (``01004``) if any of the
removed characters aren't spaces.

**Examples**

.. code-block:: sql

  VALUES UPPER('Hello');
  -- COL1: HELLO

  VALUES UPPER(CAST('straße' AS VARCHAR(10)));
  -- COL1: STRASSE

  VALUES UPPER('straße');
  -- warning 01004: string data, right truncation
  -- COL1: STRASS

**Compatibility**

- **SQL standard:** Core SQL (E021-08).
- **Other databases:** ``UPPER`` in all of them, and ``UCASE`` in MySQL. SQLite
  only converts ASCII letters (unless it's built with ICU). The others convert
  ``ß`` to ``SS`` only in some collations or versions.

Trigonometric
-------------

The trigonometric functions, including the hyperbolic functions (``SINH``,
``COSH`` and ``TANH``), use radians. They accept any number, which is converted
to a ``DOUBLE PRECISION`` (so ``SIN(1)`` is the same as ``SIN(1e0)``), and they
return a ``DOUBLE PRECISION``.

ACOS
^^^^

.. code-block:: sql

   ACOS(DOUBLE PRECISION) DOUBLE PRECISION

Inverse (arc) cosine. The result is between 0 and π. The argument must be
between -1 and 1, otherwise it's a ``22003`` error.

**Examples**

.. code-block:: sql

  VALUES ACOS(0.2);
  -- COL1: 1.369438406005e0

  VALUES ACOS(-1);
  -- COL1: 3.14159265359e0

  VALUES ACOS(2);
  -- error 22003: numeric value out of range

**Compatibility**

- **SQL standard:** T622 (trigonometric functions).
- **Other databases:** ``ACOS`` in all of them. MySQL and SQLite return
  ``NULL`` for an argument outside of -1 to 1.

ASIN
^^^^

.. code-block:: sql

   ASIN(DOUBLE PRECISION) DOUBLE PRECISION

Inverse (arc) sine. The result is between -π/2 and π/2. The argument must be
between -1 and 1, otherwise it's a ``22003`` error.

**Examples**

.. code-block:: sql

  VALUES ASIN(0.2);
  -- COL1: 0.20135792079e0

  VALUES ASIN(1.5);
  -- error 22003: numeric value out of range

**Compatibility**

- **SQL standard:** T622 (trigonometric functions).
- **Other databases:** ``ASIN`` in all of them. MySQL and SQLite return
  ``NULL`` for an argument outside of -1 to 1.

ATAN
^^^^

.. code-block:: sql

   ATAN(DOUBLE PRECISION) DOUBLE PRECISION

Inverse (arc) tangent. The result is between -π/2 and π/2, for any argument.

**Examples**

.. code-block:: sql

  VALUES ATAN(0.2);
  -- COL1: 0.19739555985e0

  VALUES ATAN(1e300);
  -- COL1: 1.570796326795e0

**Compatibility**

- **SQL standard:** T622 (trigonometric functions).
- **Other databases:** ``ATAN`` in all of them.

COS
^^^

.. code-block:: sql

   COS(DOUBLE PRECISION) DOUBLE PRECISION

Cosine of an angle in radians. The result is between -1 and 1.

**Examples**

.. code-block:: sql

  VALUES COS(1.2);
  -- COL1: 0.362357754477e0

  VALUES COS(0);
  -- COL1: 1e0

**Compatibility**

- **SQL standard:** T622 (trigonometric functions).
- **Other databases:** ``COS`` in all of them.

COSH
^^^^

.. code-block:: sql

   COSH(DOUBLE PRECISION) DOUBLE PRECISION

Hyperbolic cosine. The result is at least 1.

**Examples**

.. code-block:: sql

  VALUES COSH(1.2);
  -- COL1: 1.810655567324e0

**Compatibility**

- **SQL standard:** T622 (trigonometric functions).
- **Other databases:**

  - PostgreSQL, SQLite and Oracle: ``COSH``.
  - MySQL and SQL Server: ``(EXP(x) + EXP(-x)) / 2``.

SIN
^^^

.. code-block:: sql

   SIN(DOUBLE PRECISION) DOUBLE PRECISION

Sine of an angle in radians. The result is between -1 and 1.

**Examples**

.. code-block:: sql

  VALUES SIN(1.2);
  -- COL1: 0.932039085967e0

**Compatibility**

- **SQL standard:** T622 (trigonometric functions).
- **Other databases:** ``SIN`` in all of them.

SINH
^^^^

.. code-block:: sql

   SINH(DOUBLE PRECISION) DOUBLE PRECISION

Hyperbolic sine.

**Examples**

.. code-block:: sql

  VALUES SINH(1.2);
  -- COL1: 1.509461355412e0

**Compatibility**

- **SQL standard:** T622 (trigonometric functions).
- **Other databases:**

  - PostgreSQL, SQLite and Oracle: ``SINH``.
  - MySQL and SQL Server: ``(EXP(x) - EXP(-x)) / 2``.

TAN
^^^

.. code-block:: sql

   TAN(DOUBLE PRECISION) DOUBLE PRECISION

Tangent of an angle in radians.

**Examples**

.. code-block:: sql

  VALUES TAN(1.2);
  -- COL1: 2.572151622126e0

**Compatibility**

- **SQL standard:** T622 (trigonometric functions).
- **Other databases:** ``TAN`` in all of them.

TANH
^^^^

.. code-block:: sql

   TANH(DOUBLE PRECISION) DOUBLE PRECISION

Hyperbolic tangent. The result is between -1 and 1.

**Examples**

.. code-block:: sql

  VALUES TANH(1.2);
  -- COL1: 0.833654607012e0

**Compatibility**

- **SQL standard:** T622 (trigonometric functions).
- **Other databases:**

  - PostgreSQL, SQLite and Oracle: ``TANH``.
  - MySQL and SQL Server: ``(EXP(2 * x) - 1) / (EXP(2 * x) + 1)``.
