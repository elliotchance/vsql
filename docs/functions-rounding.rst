Rounding Functions
==================

.. contents::
   :local:
   :depth: 1

Rounding functions round a number to an integer, up (``CEIL``), down
(``FLOOR``), to the nearest (``ROUND``) or towards zero (``TRUNC``). ``ROUND``
and ``TRUNC`` can also round to a number of decimal places. They accept any
number. An exact number (such as an ``INTEGER``
or ``DECIMAL``) is converted to a ``NUMERIC``, and an approximate number (``REAL``
or ``DOUBLE PRECISION``) to a ``DOUBLE PRECISION``.

CEIL
^^^^

.. code-block:: sql

   CEIL(DOUBLE PRECISION) DOUBLE PRECISION
   CEIL(NUMERIC(p, s)) NUMERIC(p - s + 1, 0)
   CEIL(SMALLINT) SMALLINT
   CEIL(INTEGER) INTEGER
   CEIL(BIGINT) BIGINT
   CEIL(DECFLOAT(p)) DECFLOAT(p)

Round up to the nearest integer (towards positive infinity), so ``CEIL(-3.7)``
is -3.

A ``NUMERIC`` or ``DECIMAL`` argument returns a ``NUMERIC`` with a scale of 0.
It has one more digit than the integer part of the argument, because rounding
up may need one, such as ``CEIL(9.5)`` is 10. A ``SMALLINT``, ``INTEGER`` or
``BIGINT`` argument is already an integer, so it's returned as it is, with the
same type. A ``REAL`` argument returns a ``DOUBLE PRECISION``.

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
   CEILING(SMALLINT) SMALLINT
   CEILING(INTEGER) INTEGER
   CEILING(BIGINT) BIGINT
   CEILING(DECFLOAT(p)) DECFLOAT(p)

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
   FLOOR(SMALLINT) SMALLINT
   FLOOR(INTEGER) INTEGER
   FLOOR(BIGINT) BIGINT
   FLOOR(DECFLOAT(p)) DECFLOAT(p)

Round down to the nearest integer (towards negative infinity), so
``FLOOR(-3.3)`` is -4.

A ``NUMERIC`` or ``DECIMAL`` argument returns a ``NUMERIC`` with a scale of 0.
It has one more digit than the integer part of the argument, because rounding
down may need one, such as ``FLOOR(-9.5)`` is -10. A ``SMALLINT``, ``INTEGER``
or ``BIGINT`` argument is already an integer, so it's returned as it is, with
the same type. A ``REAL`` argument returns a ``DOUBLE PRECISION``.

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

ROUND
^^^^^

.. code-block:: sql

   ROUND(x DOUBLE PRECISION) DOUBLE PRECISION
   ROUND(x DOUBLE PRECISION, places BIGINT) DOUBLE PRECISION
   ROUND(x NUMERIC(p, s)) NUMERIC(p - s + 1, 0)
   ROUND(x NUMERIC(p, s), places BIGINT) NUMERIC(p - s + PLACES + 1, PLACES)
   ROUND(x DECFLOAT(p)) DECFLOAT(p)
   ROUND(x DECFLOAT(p), places BIGINT) DECFLOAT(p)

Round to the nearest integer, or to ``PLACES`` decimal places. Half is rounded
away from zero, so ``ROUND(2.5)`` is 3 and ``ROUND(-2.5)`` is -3, for exact and
approximate numbers. ``PLACES`` can be any integer. When it's negative, the
number is rounded to the left of the decimal point, so ``ROUND(1250, -2)`` is
1300.

An exact numeric argument (such as ``INTEGER`` or ``DECIMAL``) returns a
``NUMERIC``. When ``PLACES`` is a constant, it's the scale of the result (but
not more than the scale of the argument, or less than 0), and the result has
one more digit for the integer part, because rounding up may need one, such as
``ROUND(9.5)`` is 10. Otherwise, the result has the scale of the argument. A
``REAL`` argument returns a ``DOUBLE PRECISION``.

``ROUND`` is a vsql extension flagged by ``V403-02`` (see :doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES ROUND(9.5);
  -- COL1: 10

  VALUES ROUND(-1.255, 2);
  -- COL1: -1.26

  VALUES ROUND(1250, -2);
  -- COL1: 1300

  VALUES ROUND(-2.5e0);
  -- COL1: -3e0

  VALUES ROUND(1.2345e0, 2);
  -- COL1: 1.23e0

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:** ``ROUND`` in all of them. SQL Server needs the decimal
  places. PostgreSQL and MySQL may round half of an approximate number to the
  nearest even number, and SQLite always returns a floating point number.

TRUNC
^^^^^

.. code-block:: sql

   TRUNC(x DOUBLE PRECISION) DOUBLE PRECISION
   TRUNC(x DOUBLE PRECISION, places BIGINT) DOUBLE PRECISION
   TRUNC(x NUMERIC(p, s)) NUMERIC(p - s, 0)
   TRUNC(x NUMERIC(p, s), places BIGINT) NUMERIC(p - s + PLACES, PLACES)
   TRUNC(x DECFLOAT(p)) DECFLOAT(p)
   TRUNC(x DECFLOAT(p), places BIGINT) DECFLOAT(p)

Truncate towards zero to an integer, or to ``PLACES`` decimal places, so
``TRUNC(-9.99)`` is -9. ``PLACES`` can be negative, like ``ROUND``, and the type
of the result is the same as ``ROUND``, but without the extra digit.

``TRUNC`` is a vsql extension flagged by ``V403-03`` (see :doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES TRUNC(-9.99);
  -- COL1: -9

  VALUES TRUNC(-1.259, 2);
  -- COL1: -1.25

  VALUES TRUNC(1999, -3);
  -- COL1: 1000

  VALUES TRUNC(1.99e0, 1);
  -- COL1: 1.9e0

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - PostgreSQL and Oracle: ``TRUNC``.
  - MySQL: ``TRUNCATE(x, places)``.
  - SQLite: ``TRUNC(x)``, without decimal places.
  - SQL Server: ``ROUND(x, places, 1)``.
