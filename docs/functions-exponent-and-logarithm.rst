Exponent and Logarithm Functions
================================

.. contents::
   :local:
   :depth: 1

Exponents and logarithms accept any number, which is converted to a
``DOUBLE PRECISION`` (so ``LN(10)`` is the same as ``LN(10e0)``), and they
return a ``DOUBLE PRECISION``. A result that is too large or too small to be a
``DOUBLE PRECISION`` is a ``22003`` error (numeric value out of range).

.. _function-cbrt:

CBRT
^^^^

.. code-block:: sql

   CBRT(DOUBLE PRECISION) DOUBLE PRECISION

Cube root. Unlike ``SQRT``, the argument can be negative, so ``CBRT(-8)`` is -2.
The result is approximate, even for a perfect cube.

``CBRT`` is a vsql extension flagged by ``V403-10`` (see :doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES CBRT(27);
  -- COL1: 3e0

  VALUES CBRT(-8);
  -- COL1: -2e0

  VALUES CBRT(2);
  -- COL1: 1.259921049895e0

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - PostgreSQL: ``CBRT``.
  - MySQL, SQLite, SQL Server and Oracle: ``POWER(x, 1.0 / 3)``, for an ``x``
    that isn't negative.

.. _function-exp:

EXP
^^^

.. code-block:: sql

   EXP(DOUBLE PRECISION) DOUBLE PRECISION

Exponential, *e* (2.718281828459...) raised to the power of the argument. The
result is always greater than 0, so an argument greater than about 709.78 (the
result is too large) or less than about -745.13 (the result is too small) is a
``22003`` error.

``EXP(1)`` is *e* itself, there's no separate ``E()`` function.

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

.. _function-ln:

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

.. _function-log:

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

.. _function-log10:

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

.. _function-power:

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

.. _function-sqrt:

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
