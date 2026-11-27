Type Conversion
===============

.. contents::

A value is converted from one type to another in four ways:

1. An explicit ``CAST`` (`Explicit Casts`_).
2. Storing a value in a column, with ``INSERT`` or ``UPDATE``, which is called
   a *store assignment* (`Store Assignment`_).
3. Combining the values of a ``UNION``, ``CASE``, ``VALUES``, ``COALESCE`` and
   so on into one type (`Combined Types`_).
4. Arithmetic between different numeric types (`Expressions`_).

There's no other implicit conversion. In particular, a character string is
never converted to a number or a datetime (or the other way around) unless it's
cast.

Explicit Casts
--------------

``CAST(value AS type)`` converts a value to any type that it can be cast to.
``value::type`` is the same, as a vsql extension (see :doc:`sql-flagging`).

.. list-table::
  :header-rows: 1

  * - ↓ From / To →
    - Exact number
    - Approximate number
    - ``DECFLOAT``
    - Character string
    - Binary string
    - ``BOOLEAN``
    - Datetime
    - Interval

  * - Exact number
    - ✅
    - ✅
    - ✅
    - ✅
    - ❌
    - ❌
    - ❌
    - ✅ [1]_

  * - Approximate number
    - ✅
    - ✅
    - ✅
    - ✅
    - ❌
    - ❌
    - ❌
    - ❌

  * - ``DECFLOAT``
    - ✅
    - ✅
    - ✅
    - ✅
    - ❌
    - ❌
    - ❌
    - ❌

  * - Character string
    - ✅
    - ✅
    - ✅
    - ✅
    - ❌
    - ✅
    - ✅
    - ✅

  * - Binary string
    - ❌
    - ❌
    - ❌
    - ❌
    - ✅
    - ❌
    - ❌
    - ❌

  * - ``BOOLEAN``
    - ❌
    - ❌
    - ❌
    - ✅
    - ❌
    - ✅
    - ❌
    - ❌

  * - Datetime
    - ❌
    - ❌
    - ❌
    - ✅
    - ❌
    - ❌
    - ✅ [2]_
    - ❌

  * - Interval
    - ✅ [1]_
    - ❌
    - ❌
    - ✅
    - ❌
    - ❌
    - ❌
    - ✅ [3]_

A cast that isn't in the table is a ``42846`` error when the statement is
prepared, even if there are no rows. A cast that is in the table can still fail
for a value that doesn't fit:

- A number that's out of range for the target is a ``22003`` error. Digits
  after the scale of the target are truncated, not rounded, so
  ``CAST(2.9 AS INTEGER)`` is ``2``.
- A character string cast to a number, ``BOOLEAN``, datetime or interval has
  its leading and trailing spaces removed, and the rest must be a literal of
  that type, or it's a ``22018`` (or ``22007`` for a datetime, ``22006`` for an
  interval) error.
- A number, ``BOOLEAN``, datetime or interval cast to a character string is its
  literal, which must fit (``22001``, or ``22018`` for a ``BOOLEAN``).
- A character string cast to a shorter character string is truncated, with a
  ``01004`` warning (see :doc:`sqlstate`).

.. code-block:: sql

  VALUES CAST('  42 ' AS INTEGER);
  -- COL1: 42

  VALUES CAST('4x' AS INTEGER);
  -- error 22018: invalid character value for cast

  VALUES CAST('abcdef' AS VARCHAR(3));
  -- warning 01004: string data, right truncation
  -- COL1: abc

  VALUES CAST(TRUE AS INTEGER);
  -- error 42846: cannot coerce BOOLEAN to INTEGER

The details of each kind of cast are on the pages for the types:
:ref:`numbers:Casting`, :ref:`text:Casting`, :doc:`binary`,
:ref:`booleans:Casting` and :ref:`dates-times:Casting`.

Store Assignment
----------------

A value that's stored in a column (by ``INSERT``, ``UPDATE`` or a ``DEFAULT``)
is converted to the type of the column. It's the same as a ``CAST``, except:

- A numeric column only accepts a number, and a character string column
  doesn't accept a number. A binary string, a ``BOOLEAN``, a datetime and an
  interval column only accept the same kind of value: a ``DATE``, ``TIME`` or
  ``TIMESTAMP`` (with or without a time zone) in the same one of those, and a
  year-month or day-time interval in the same kind of interval. A datetime,
  interval or binary string also can't be stored in any other kind of column.
  Anything else is a ``42846`` error, so a string must be cast to a number or a
  date before it's stored.
- A character string that's too long is a ``22001`` error, rather than a
  warning, unless the extra characters are all spaces, which are removed.

A number with more digits after the point than the column allows is truncated
(towards zero), and it's only an error if what's left is out of range:

.. code-block:: sql

  CREATE TABLE t (x INTEGER, c CHARACTER(5));
  -- msg: CREATE TABLE 1

  INSERT INTO t (x, c) VALUES (2.9, 'ab');
  -- msg: INSERT 1

  INSERT INTO t (x, c) VALUES (-2.9e0, 'abc  ');
  -- msg: INSERT 1

  INSERT INTO t (x, c) VALUES ('3', 'abc');
  -- error 42846: cannot coerce CHARACTER(1) to INTEGER

  INSERT INTO t (x, c) VALUES (3, 'abcdef');
  -- error 22001: string data right truncation for CHARACTER(5)

  SELECT x, c || '|' FROM t;
  -- X: 2 COL2: ab   |
  -- X: -2 COL2: abc  |

A ``CHARACTER(n)`` is padded with spaces, a ``BINARY(n)`` with ``X'00'``, and a
``TIME`` or ``TIMESTAMP`` keeps only the fractional seconds of the column. A
``TIME WITH TIME ZONE`` stored in a ``TIME WITHOUT TIME ZONE`` (or a
``TIMESTAMP``) keeps its local time.

The value of a dynamic parameter is converted to the type of the parameter in
the same way (see :ref:`prepared-statements:Data Types`).

Combined Types
--------------

When several values make one result, they're all converted to one type, which
is worked out from all of their types when the statement is prepared:

- Each column of a ``VALUES`` with more than one row.
- Each column of a ``UNION``, ``EXCEPT`` or ``INTERSECT``.
- The results of a ``CASE``, and the values of ``COALESCE``, ``NULLIF``,
  ``GREATEST`` and ``LEAST``.

The types must be the same kind, by the same groups as a store assignment,
except that all numbers (including a ``DECFLOAT``) can be combined. Otherwise
it's a ``42804`` error:

.. code-block:: sql

  VALUES 'a', 1;
  -- error 42804: data type mismatch in row 2, column 1 of VALUES: expected CHARACTER(1) but got INTEGER

The combined type of each kind is:

- **Exact numbers:** a ``NUMERIC`` (or a ``DECIMAL`` if any of them is), with
  the largest scale, and enough digits for the largest integer part (an
  ``INTEGER`` needs 10 digits). Integers of different sizes are the largest
  of them.
- **Approximate numbers:** a ``DOUBLE PRECISION`` if any of them is an
  approximate number, or a ``REAL`` if they're all ``REAL``.
- **DECFLOAT:** a ``DECFLOAT`` if any of them is, with the largest precision of
  the ``DECFLOAT`` values.
- **Character strings:** the longest length. It's a ``CHARACTER LARGE OBJECT``
  if any of them is, otherwise a ``CHARACTER VARYING`` if any of them is,
  otherwise a ``CHARACTER``, which is padded with spaces.
- **Binary strings:** the same as character strings, with ``BINARY LARGE
  OBJECT``, ``BINARY VARYING`` and ``BINARY``.
- **Datetimes:** the largest fractional seconds precision, with a time zone if
  any of them has one. A ``DATE``, ``TIME`` and ``TIMESTAMP`` can't be
  combined with each other.
- **Intervals:** from the first start field to the last end field.

.. code-block:: sql

  VALUES 1, 2.25;
  -- COL1: 1.00
  -- COL1: 2.25

  VALUES 1 UNION ALL VALUES 1.5e0;
  -- COL1: 1e0
  -- COL1: 1.5e0

  SELECT x || '|' FROM (VALUES 'abc', 'a') AS t (x);
  -- COL1: abc|
  -- COL1: a  |

  VALUES CASE WHEN FALSE THEN 1 ELSE 2.50 END;
  -- COL1: 2.50

  VALUES TIME '10:00:00' UNION ALL VALUES TIME '11:00:00.5';
  -- COL1: 10:00:00.0
  -- COL1: 11:00:00.5

  VALUES INTERVAL '1' DAY UNION ALL VALUES INTERVAL '2:30' HOUR TO MINUTE;
  -- COL1: 1 00:00
  -- COL1: 0 02:30

Expressions
-----------

Arithmetic between two different numeric types converts them to one type, such
as an ``INTEGER`` and a ``BIGINT`` to a ``BIGINT``, or an exact and an
approximate number to a ``DOUBLE PRECISION``. The result type of each
operation is explained in :doc:`numbers`, and of datetime arithmetic in
:ref:`dates-times:Datetime Arithmetic`.

Any two numbers can be compared, whatever their types. Values of any other
kind can only be compared with the same kind, so ``1 = '1'`` and
``DATE '2020-01-01' = '2020-01-01'`` are ``42883`` errors:

.. code-block:: sql

  VALUES 1 = 1.0e0;
  -- COL1: TRUE

  VALUES 1 = '1';
  -- error 42883: cannot compare INTEGER and CHARACTER(1)

  VALUES CAST('1' AS INTEGER) = 1;
  -- COL1: TRUE

Notes
-----

.. [1] Only an interval with a single field, such as ``INTERVAL DAY``. The
   number is the value of that field.

.. [2] See the table in :ref:`dates-times:Casting`. A ``DATE`` and a ``TIME``
   can't be cast to each other.

.. [3] Only to an interval of the same kind (year-month or day-time).
