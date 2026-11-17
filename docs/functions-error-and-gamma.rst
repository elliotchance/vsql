Error and Gamma Functions
=========================

.. contents::
   :local:
   :depth: 1

The error function and the gamma function, which are used by statistical
distributions (see :doc:`spreadsheet-functions` for some of them). They accept
any number, which is converted to a ``DOUBLE PRECISION``, and they return a
``DOUBLE PRECISION``.

ERF
^^^

.. code-block:: sql

   ERF(DOUBLE PRECISION) DOUBLE PRECISION

The error function, which is between -1 and 1. The probability that a normally
distributed value is less than ``x`` is ``0.5 * ERFC(-(x - mean) / (sd *
SQRT(2)))``.

``ERF`` is a vsql extension flagged by ``V403-14`` (see :doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES ERF(0);
  -- COL1: 0e0

  VALUES ERF(1);
  -- COL1: 0.84270079295e0

  VALUES ERF(-1);
  -- COL1: -0.84270079295e0

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - PostgreSQL: ``ERF``.
  - MySQL, SQLite, SQL Server and Oracle: none.

ERFC
^^^^

.. code-block:: sql

   ERFC(DOUBLE PRECISION) DOUBLE PRECISION

The complementary error function, ``1 - ERF(x)``, which is between 0 and 2.
It's more accurate than ``1 - ERF(x)`` for a large ``x``, where the result is
very small.

``ERFC`` is a vsql extension flagged by ``V403-15`` (see :doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES ERFC(0);
  -- COL1: 1e0

  VALUES ERFC(1);
  -- COL1: 0.15729920705e0

  VALUES ERFC(10);
  -- COL1: 2.08848758376e-45

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - PostgreSQL: ``ERFC``.
  - MySQL, SQLite, SQL Server and Oracle: none.

GAMMA
^^^^^

.. code-block:: sql

   GAMMA(DOUBLE PRECISION) DOUBLE PRECISION

The gamma function, which extends the factorial to all numbers:
``GAMMA(n)`` is the factorial of ``n - 1`` for a positive integer ``n``.

It isn't defined for 0 and the negative integers, so they are a ``22003``
error (numeric value out of range), as is a result that is too large, such as
``GAMMA(172)``. A result that is too small, such as ``GAMMA(-200.5)``, is 0.

``GAMMA`` is a vsql extension flagged by ``V403-16`` (see :doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES GAMMA(5);
  -- COL1: 24e0

  VALUES GAMMA(0.5);
  -- COL1: 1.772453850906e0

  VALUES GAMMA(-0.5);
  -- COL1: -3.544907701811e0

  VALUES GAMMA(0);
  -- error 22003: numeric value out of range

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - PostgreSQL: ``GAMMA``.
  - MySQL, SQLite, SQL Server and Oracle: none.

LGAMMA
^^^^^^

.. code-block:: sql

   LGAMMA(DOUBLE PRECISION) DOUBLE PRECISION

The natural logarithm of the absolute value of the gamma function, so
``LGAMMA(x)`` is ``LN(ABS(GAMMA(x)))``, but without the error when
``GAMMA(x)`` is too large. It's the same as ``GAMMA`` for 0 and the negative
integers, which are a ``22003`` error, and only an argument greater than
about ``2.55e305`` is too large.

``LGAMMA`` is a vsql extension flagged by ``V403-17`` (see :doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES LGAMMA(100);
  -- COL1: 359.134205369575e0

  VALUES LGAMMA(-0.5);
  -- COL1: 1.265512123485e0

  VALUES LGAMMA(-2);
  -- error 22003: numeric value out of range

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - PostgreSQL: ``LGAMMA``.
  - MySQL, SQLite, SQL Server and Oracle: none.
