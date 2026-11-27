Trigonometric Functions
=======================

.. contents::
   :local:
   :depth: 1

The trigonometric functions, including the hyperbolic functions (``SINH``,
``COSH`` and ``TANH``), use radians. ``DEGREES`` and ``RADIANS`` convert between
radians and degrees. They accept any number, which is converted to a
``DOUBLE PRECISION`` (so ``SIN(1)`` is the same as ``SIN(1e0)``), and they
return a ``DOUBLE PRECISION``. A function that has a ``DECFLOAT`` version
returns a ``DECFLOAT`` for a ``DECFLOAT`` argument instead.

ACOS
^^^^

.. code-block:: sql

   ACOS(DOUBLE PRECISION) DOUBLE PRECISION
   ACOS(DECFLOAT(p)) DECFLOAT(p)

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
   ASIN(DECFLOAT(p)) DECFLOAT(p)

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
   ATAN(DECFLOAT(p)) DECFLOAT(p)

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

ATAN2
^^^^^

.. code-block:: sql

   ATAN2(y DOUBLE PRECISION, x DOUBLE PRECISION) DOUBLE PRECISION

``ATAN2(Y, X)`` is the angle of the point (``X``, ``Y``) from the positive x
axis. It's the inverse tangent of ``Y / X``, but the result is between -π and
π because the signs of both arguments are used. ``ATAN2(0, 0)`` is 0.

``ATAN2`` is a vsql extension flagged by ``V403-07`` (see :doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES ATAN2(1, 1);
  -- COL1: 0.785398163397e0

  VALUES ATAN2(-1, -1);
  -- COL1: -2.356194490192e0

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:** ``ATAN2(y, x)`` in all of them, except SQL Server, which
  calls it ``ATN2(y, x)``.

COS
^^^

.. code-block:: sql

   COS(DOUBLE PRECISION) DOUBLE PRECISION
   COS(DECFLOAT(p)) DECFLOAT(p)

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
   COSH(DECFLOAT(p)) DECFLOAT(p)

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

DEGREES
^^^^^^^

.. code-block:: sql

   DEGREES(x DOUBLE PRECISION) DOUBLE PRECISION

Converts an angle in radians to degrees. A result that is too large to be a
``DOUBLE PRECISION`` is a ``22003`` error (numeric value out of range).

``DEGREES`` is a vsql extension flagged by ``V403-08`` (see :doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES DEGREES(PI());
  -- COL1: 180e0

  VALUES DEGREES(-1);
  -- COL1: -57.295779513082e0

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:** ``DEGREES`` in all of them, except Oracle, use
  ``x * 180 / ACOS(-1)``.

PI
^^

.. code-block:: sql

   PI() DOUBLE PRECISION

π, the ratio of a circle's circumference to its diameter (3.14159265358979...).

``PI`` is a vsql extension flagged by ``V403-05`` (see :doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES PI();
  -- COL1: 3.14159265359e0

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:** ``PI()`` in all of them, except Oracle, use
  ``ACOS(-1)``.

RADIANS
^^^^^^^

.. code-block:: sql

   RADIANS(x DOUBLE PRECISION) DOUBLE PRECISION

Converts an angle in degrees to radians.

``RADIANS`` is a vsql extension flagged by ``V403-09`` (see :doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES RADIANS(180);
  -- COL1: 3.14159265359e0

  VALUES RADIANS(0.5);
  -- COL1: 0.00872664626e0

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:** ``RADIANS`` in all of them, except Oracle, use
  ``x * ACOS(-1) / 180``.

SIN
^^^

.. code-block:: sql

   SIN(DOUBLE PRECISION) DOUBLE PRECISION
   SIN(DECFLOAT(p)) DECFLOAT(p)

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
   SINH(DECFLOAT(p)) DECFLOAT(p)

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
   TAN(DECFLOAT(p)) DECFLOAT(p)

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
   TANH(DECFLOAT(p)) DECFLOAT(p)

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
