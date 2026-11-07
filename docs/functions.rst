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
   * - ``COS``
     - Trigonometric
     - T622
   * - ``COSH``
     - Trigonometric
     - T622
   * - ``COUNT``
     - Aggregate
     - Core (E091-02)
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
   * - ``EXP``
     - Exponent and Logarithm
     - T621
   * - ``FLOOR``
     - Rounding
     - T621
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
   * - ``POSITION``
     - String
     - Core (E021-11)
   * - ``POWER``
     - Exponent and Logarithm
     - T621
   * - ``SIN``
     - Trigonometric
     - T622
   * - ``SINH``
     - Trigonometric
     - T622
   * - ``SQRT``
     - Exponent and Logarithm
     - T621
   * - ``SUBSTRING``
     - String
     - Core (E021-06)
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

The examples use this table:

.. code-block:: sql

  CREATE TABLE products (city VARCHAR(20), price FLOAT);
  INSERT INTO products (city, price) VALUES
    ('New York', 8.05e0), ('New York', 18.05e0),
    ('San Francisco', 7.5e0), ('San Francisco', 17.5e0),
    ('San Francisco', NULL);

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

The same as ``CURRENT_TIMESTAMP``, including that it can be a ``DEFAULT`` (see
:doc:`create-table`). It doesn't take a precision (``NOW(3)`` is a ``42883``
error), use ``CURRENT_TIMESTAMP(3)`` instead.

``NOW`` isn't a reserved word, so it can still be the name of a table or a
column. A custom function (see :doc:`custom-functions`) with the name ``NOW`` has
to be called with quotes: ``"NOW"()``.

**Compatibility**

- **SQL standard:** Not standard, it's a vsql extension flagged by
  ``V402-01`` (see :doc:`sql-flagging`). ``CURRENT_TIMESTAMP`` should be used
  if the SQL needs to be portable.
- **Other databases:**

  - PostgreSQL: ``NOW``, the time the transaction started.
  - MySQL: ``NOW``, without a time zone.
  - SQL Server: ``SYSDATETIMEOFFSET()``.
  - SQLite: ``DATETIME('now')``, a string in UTC.
  - Oracle: ``CURRENT_TIMESTAMP`` or ``SYSTIMESTAMP``.

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

.. code-block:: sql

   SUBSTRING(CHARACTER VARYING(n) FROM INTEGER) CHARACTER VARYING(n)
   SUBSTRING(CHARACTER VARYING(n) FROM INTEGER FOR INTEGER) CHARACTER VARYING(n)

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

**Compatibility**

- **SQL standard:** Core SQL (E021-06). ``USING`` is part of T061 (UCS
  support).
- **Other databases:** none of them have ``USING``.

  - PostgreSQL: ``SUBSTRING(string FROM start FOR length)``,
    ``SUBSTRING(string, start, length)`` or ``SUBSTR``.
  - MySQL: ``SUBSTRING(string FROM start FOR length)``,
    ``SUBSTRING(string, start, length)`` or ``SUBSTR``.
  - SQLite: ``SUBSTR(string, start, length)`` or ``SUBSTRING``.
  - SQL Server: ``SUBSTRING(string, start, length)``, the length is required.
  - Oracle: ``SUBSTR(string, start, length)``.

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
