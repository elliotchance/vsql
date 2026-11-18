Arithmetic Functions
====================

.. contents::
   :local:
   :depth: 1

Arithmetic functions return the absolute value, factorial or remainder of a
number, the greatest common divisor or least common multiple of two integers,
or which bucket a number is in. The result has the type of an argument (see each
function).

They accept any number. If there is no version of the function
for the argument types, an exact number (such as an ``INTEGER``) is converted to
a ``NUMERIC`` when possible, otherwise to a ``DOUBLE PRECISION``, and a ``REAL``
is converted to a ``DOUBLE PRECISION``. If any argument is a ``DECFLOAT``, every
argument is converted to a ``DECFLOAT`` with the largest precision of the
``DECFLOAT`` arguments, and so is the result (see :doc:`numbers` for which
functions are exact). A function without a ``DECFLOAT`` version converts it to
a ``DOUBLE PRECISION``.

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
   ABS(DECFLOAT(p)) DECFLOAT(p)

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

FACTORIAL
^^^^^^^^^

.. code-block:: sql

   FACTORIAL(BIGINT) NUMERIC

The factorial of an integer: the product of every integer from 1 to the
argument, and ``FACTORIAL(0)`` is 1. A ``SMALLINT`` or ``INTEGER`` is converted
to a ``BIGINT``. The result is an exact ``NUMERIC``, so a large factorial keeps
every digit.

A negative argument, or one greater than 449 (the result would have more than
1000 digits, the largest ``NUMERIC``), is a ``22003`` error (numeric value out
of range).

``FACTORIAL`` is a vsql extension flagged by ``V403-11`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES FACTORIAL(5);
  -- COL1: 120

  VALUES FACTORIAL(30);
  -- COL1: 265252859812191058636308480000000

  VALUES FACTORIAL(-1);
  -- error 22003: numeric value out of range

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - PostgreSQL: ``FACTORIAL``.
  - MySQL, SQLite, SQL Server and Oracle: none.

GCD
^^^

.. code-block:: sql

   GCD(SMALLINT, SMALLINT) SMALLINT
   GCD(INTEGER, INTEGER) INTEGER
   GCD(BIGINT, BIGINT) BIGINT

The greatest common divisor of two integers, the largest integer that divides
both of them. It's never negative, ``GCD(x, 0)`` is the absolute value of
``x`` and ``GCD(0, 0)`` is 0.

The result has the larger of the two types, such as ``GCD(SMALLINT, BIGINT)
BIGINT``. A result that doesn't fit in it, such as
``GCD(CAST(-32768 AS SMALLINT), CAST(0 AS SMALLINT))``, is a ``22003`` error
(numeric value out of range).

``GCD`` is a vsql extension flagged by ``V403-12`` (see :doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES GCD(12, 18);
  -- COL1: 6

  VALUES GCD(-12, 0);
  -- COL1: 12

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - PostgreSQL: ``GCD``.
  - MySQL, SQLite, SQL Server and Oracle: none.

LCM
^^^

.. code-block:: sql

   LCM(SMALLINT, SMALLINT) SMALLINT
   LCM(INTEGER, INTEGER) INTEGER
   LCM(BIGINT, BIGINT) BIGINT

The least common multiple of two integers, the smallest integer that both of
them divide. It's never negative, and it's 0 if either argument is 0.

The result has the larger of the two types, such as ``LCM(SMALLINT, BIGINT)
BIGINT``. A result that doesn't fit in it is a ``22003`` error (numeric value
out of range).

``LCM`` is a vsql extension flagged by ``V403-13`` (see :doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES LCM(4, 6);
  -- COL1: 12

  VALUES LCM(-4, 6);
  -- COL1: 12

  VALUES LCM(5, 0);
  -- COL1: 0

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - PostgreSQL: ``LCM``.
  - MySQL, SQLite, SQL Server and Oracle: none.

MOD
^^^

.. code-block:: sql

   MOD(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION
   MOD(NUMERIC, NUMERIC) NUMERIC
   MOD(SMALLINT, SMALLINT) SMALLINT
   MOD(INTEGER, INTEGER) INTEGER
   MOD(BIGINT, BIGINT) BIGINT
   MOD(DECFLOAT(p), DECFLOAT(p)) DECFLOAT(p)

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

SIGN
^^^^

.. code-block:: sql

   SIGN(SMALLINT) SMALLINT
   SIGN(INTEGER) INTEGER
   SIGN(BIGINT) BIGINT
   SIGN(DOUBLE PRECISION) DOUBLE PRECISION
   SIGN(NUMERIC(p, s)) NUMERIC(1)
   SIGN(DECFLOAT(p)) DECFLOAT(p)

The sign of a number: -1 if it's negative, 0 if it's zero and 1 if it's
positive. An integer returns the same type, a ``NUMERIC`` or ``DECIMAL`` returns
a ``NUMERIC(1)``, and a ``REAL`` returns a ``DOUBLE PRECISION``.

``SIGN`` is a vsql extension flagged by ``V403-04`` (see :doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES SIGN(-5);
  -- COL1: -1

  VALUES SIGN(0.0);
  -- COL1: 0

  VALUES SIGN(2.5e0);
  -- COL1: 1e0

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:** ``SIGN`` in all of them.

WIDTH_BUCKET
^^^^^^^^^^^^

.. code-block:: sql

   WIDTH_BUCKET(VALUE, BOUND1, BOUND2, SMALLINT) SMALLINT
   WIDTH_BUCKET(VALUE, BOUND1, BOUND2, INTEGER) INTEGER
   WIDTH_BUCKET(VALUE, BOUND1, BOUND2, BIGINT) BIGINT
   WIDTH_BUCKET(VALUE, BOUND1, BOUND2, NUMERIC(p)) NUMERIC(p)
   WIDTH_BUCKET(VALUE, BOUND1, BOUND2, DECIMAL(p)) DECIMAL(p)

``WIDTH_BUCKET(VALUE, BOUND1, BOUND2, COUNT)`` splits the range from
``BOUND1`` to ``BOUND2`` into ``COUNT`` buckets of the same width, numbered from
1, and returns the bucket that ``VALUE`` is in. Each bucket includes its start
but not its end. A ``VALUE`` before the range is in bucket 0, and one at
``BOUND2`` or after it is in bucket ``COUNT + 1``. ``BOUND1`` can be greater
than ``BOUND2``, then the buckets go down from ``BOUND1``.

``VALUE`` and the bounds can be any numbers. ``COUNT`` must be an integer (an
exact number with a scale of 0), and the result has its type. The bucket is
calculated exactly, even for approximate numbers.

A ``COUNT`` that isn't positive, or bounds that are equal, is a ``2201G`` error
(invalid argument for width bucket function). If ``COUNT + 1`` is too large
for the type of ``COUNT`` it's a ``22003`` error, but only when ``VALUE`` is
after the range.

**Examples**

.. code-block:: sql

  VALUES WIDTH_BUCKET(5, 0, 10, 5);
  -- COL1: 3

  VALUES WIDTH_BUCKET(10, 0, 10, 5);
  -- COL1: 6

  VALUES WIDTH_BUCKET(-1, 0, 10, 5);
  -- COL1: 0

  VALUES WIDTH_BUCKET(8, 10, 0, 5);
  -- COL1: 2

  VALUES WIDTH_BUCKET(5, 0, 10, 0);
  -- error 2201G: invalid argument for width bucket function

**Compatibility**

- **SQL standard:** T612 (Advanced OLAP operations).
- **Other databases:** PostgreSQL, Oracle and Db2 have ``WIDTH_BUCKET``.
  PostgreSQL also has a version that takes an array of bounds. MySQL, SQLite
  and SQL Server don't have it.
