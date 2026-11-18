Random Functions
================

.. contents::
   :local:
   :depth: 1

RANDOM
^^^^^^

.. code-block:: sql

   RANDOM() DOUBLE PRECISION

A random number that is at least 0 and less than 1. It's a different number
each time it's called, even in the same statement, so it can't be used in a
``CHECK`` constraint.

.. warning::

   ``RANDOM`` isn't cryptographically secure: the numbers that it returns can
   be predicted from the ones before it. Use ``GENERATE_UUID_V4`` for a value
   that must not be guessed, such as a token.

``RANDOM`` is a vsql extension flagged by ``V403-06`` (see :doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES RANDOM() >= 0 AND RANDOM() < 1;
  -- COL1: TRUE

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - PostgreSQL: ``RANDOM()``.
  - MySQL and SQL Server: ``RAND()``.
  - SQLite: ``RANDOM()`` returns a random 64-bit integer instead, use
    ``ABS(RANDOM()) / 9223372036854775808.0``.
  - Oracle: ``DBMS_RANDOM.VALUE``.
