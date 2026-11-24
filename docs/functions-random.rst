Random Functions
================

.. contents::
   :local:
   :depth: 1

RANDOM
^^^^^^

.. code-block:: sql

   RANDOM() DOUBLE PRECISION
   RANDOM(min NUMBER, max NUMBER) NUMBER

``RANDOM()`` is a random number that is at least 0 and less than 1.

``RANDOM(min, max)`` is a random number from ``min`` to ``max``. The result has
the type of ``min`` and ``max`` combined, the same as a ``CASE`` or a
``UNION``, so ``RANDOM(1, 6)`` is an ``INTEGER``, ``RANDOM(1, 10000000000)`` is
a ``BIGINT`` and ``RANDOM(1.00, 9.99)`` is a ``NUMERIC(3, 2)``:

- An exact number (``SMALLINT``, ``INTEGER``, ``BIGINT``, ``NUMERIC`` or
  ``DECIMAL``) includes both ``min`` and ``max``, and every value with the
  scale of the result is equally likely. ``RANDOM(1.00, 9.99)`` is one of
  ``1.00``, ``1.01``, ..., ``9.99``.
- An approximate number (``REAL`` or ``DOUBLE PRECISION``) or a ``DECFLOAT`` is
  at least ``min`` and less than ``max``, like ``min + RANDOM() * (max - min)``.

If ``min`` is equal to ``max`` the result is ``min``, and if ``min`` is greater
than ``max`` it's a ``22023`` error. If either is ``NULL``, the result is
``NULL``.

It's a different number each time it's called, even in the same statement, so
it can't be used in a ``CHECK`` constraint.

.. warning::

   ``RANDOM`` isn't cryptographically secure: the numbers that it returns can
   be predicted from the ones before it. Use ``RANDOM_BINARY`` or
   ``GENERATE_UUID_V4`` for a value that must not be guessed, such as a token.

``RANDOM()`` is a vsql extension flagged by ``V403-06``, and ``RANDOM(min,
max)`` by ``V403-24`` (see :doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES RANDOM() >= 0 AND RANDOM() < 1;
  -- COL1: TRUE

  VALUES RANDOM(1, 6) BETWEEN 1 AND 6;
  -- COL1: TRUE

  VALUES RANDOM(5, 5);
  -- COL1: 5

  VALUES RANDOM(6, 1);
  -- error 22023: invalid parameter value: RANDOM minimum 6 is greater than maximum 1

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - PostgreSQL: ``RANDOM()`` and ``RANDOM(min, max)``.
  - MySQL and SQL Server: ``RAND()``, and ``FLOOR(RAND() * (max - min + 1)) +
    min`` for a range.
  - SQLite: ``RANDOM()`` returns a random 64-bit integer instead, use
    ``ABS(RANDOM()) / 9223372036854775808.0``.
  - Oracle: ``DBMS_RANDOM.VALUE`` and ``DBMS_RANDOM.VALUE(low, high)``.

RANDOM_BINARY
^^^^^^^^^^^^^

.. code-block:: sql

   RANDOM_BINARY(n BIGINT) BINARY VARYING(n)

``n`` random bytes. The bytes come from a cryptographically secure generator
(unlike ``RANDOM``), so they can be used for tokens, salts and keys.

``n`` can be from 0 (which is ``X''``) to the maximum length of a ``BINARY
VARYING`` (10485760), otherwise it's a ``22023`` error. If ``n`` is ``NULL``,
the result is ``NULL``. It's a different value each time it's called, so it
can't be used in a ``CHECK`` constraint.

``RANDOM_BINARY`` is a vsql extension flagged by ``V403-26`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES OCTET_LENGTH(RANDOM_BINARY(16));
  -- COL1: 16

  VALUES RANDOM_BINARY(0) = X'';
  -- COL1: TRUE

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - PostgreSQL: ``gen_random_bytes(n)`` (pgcrypto).
  - MySQL: ``RANDOM_BYTES(n)``.
  - SQL Server: ``CRYPT_GEN_RANDOM(n)``.
  - SQLite: ``randomblob(n)``.
  - Oracle: ``DBMS_CRYPTO.RANDOMBYTES(n)``.

RANDOM_NORMAL
^^^^^^^^^^^^^

.. code-block:: sql

   RANDOM_NORMAL() DOUBLE PRECISION
   RANDOM_NORMAL(mean DOUBLE PRECISION) DOUBLE PRECISION
   RANDOM_NORMAL(mean DOUBLE PRECISION, stddev DOUBLE PRECISION) DOUBLE PRECISION

A random number from a normal distribution with a mean of ``mean`` (0 if it's
left out) and a standard deviation of ``stddev`` (1 if it's left out).

If ``stddev`` is 0 the result is ``mean``, and if it's negative it's a
``22023`` error. If either is ``NULL``, the result is ``NULL``. It's a
different number each time it's called, so it can't be used in a ``CHECK``
constraint.

``RANDOM_NORMAL`` is a vsql extension flagged by ``V403-25`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES RANDOM_NORMAL(100, 15) BETWEEN -1000 AND 1000;
  -- COL1: TRUE

  VALUES RANDOM_NORMAL(100, 0);
  -- COL1: 100e0

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - PostgreSQL: ``random_normal(mean, stddev)``.
  - Oracle: ``DBMS_RANDOM.NORMAL`` (a mean of 0 and a standard deviation of 1
    only).
  - MySQL, SQL Server and SQLite: no equivalent.
