Number Base Functions
=====================

Number base functions write an integer in another base (radix), such as
binary (2), octal (8) or hexadecimal (16), and read it back. Any exact integer
(``SMALLINT``, ``INTEGER`` or ``BIGINT``) can be converted, and it's read back
as a ``BIGINT``. The digits are ``0`` to ``9`` and then ``A`` to ``Z``, so the
radix can be from 2 to 36. Anything else is a ``22003`` error (numeric value
out of range).

A negative number has a ``-`` in front, rather than being written as two's
complement, so ``INTEGER_TO_HEX(-1)`` is ``-1``.

.. contents::
   :local:
   :depth: 1

BASE_TO_INTEGER
^^^^^^^^^^^^^^^

.. code-block:: sql

   BASE_TO_INTEGER(CHARACTER VARYING, BIGINT) BIGINT

Reads the digits of a number in the radix (in upper or lower case), with an
optional ``-`` in front. A digit that isn't in the radix (including spaces or a
prefix such as ``0x``), or no digits, is a ``22018`` error. A number that
doesn't fit in a ``BIGINT`` is a ``22003`` error.

``BASE_TO_INTEGER`` is a vsql extension flagged by ``V403-19`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES BASE_TO_INTEGER('11111111', 2);
  -- COL1: 255

  VALUES BASE_TO_INTEGER('-zz', 36);
  -- COL1: -1295

  VALUES BASE_TO_INTEGER('12', 2);
  -- error 22018: invalid character value for cast

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - MySQL: ``CONV(text, radix, 10)``, which returns text.
  - PostgreSQL, SQLite, SQL Server and Oracle: none built in for any radix.

HEX_TO_INTEGER
^^^^^^^^^^^^^^

.. code-block:: sql

   HEX_TO_INTEGER(CHARACTER VARYING) BIGINT

The same as ``BASE_TO_INTEGER(text, 16)``.

``HEX_TO_INTEGER`` is a vsql extension flagged by ``V403-21`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES HEX_TO_INTEGER('FF');
  -- COL1: 255

  VALUES HEX_TO_INTEGER('7fffffffffffffff');
  -- COL1: 9223372036854775807

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - MySQL: ``CONV(text, 16, 10)``, which returns text.
  - PostgreSQL: ``('x' || LPAD(text, 16, '0'))::BIT(64)::BIGINT``.
  - SQL Server: ``CONVERT(BIGINT, CONVERT(VARBINARY, '0x' + text, 1))``.
  - Oracle: ``TO_NUMBER(text, 'XXXXXXXXXXXXXXXX')``.
  - SQLite: none built in.

INTEGER_TO_BASE
^^^^^^^^^^^^^^^

.. code-block:: sql

   INTEGER_TO_BASE(BIGINT, BIGINT) CHARACTER VARYING

Writes the number with the upper case digits of the radix, without leading
zeros.

``INTEGER_TO_BASE`` is a vsql extension flagged by ``V403-18`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES INTEGER_TO_BASE(255, 2);
  -- COL1: 11111111

  VALUES INTEGER_TO_BASE(-1295, 36);
  -- COL1: -ZZ

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - MySQL: ``CONV(number, 10, radix)``, which writes a negative number as
    two's complement.
  - PostgreSQL: ``TO_BIN``, ``TO_OCT`` and ``TO_HEX`` (16 and later) for those
    radixes only, which write a negative number as two's complement.
  - SQLite, SQL Server and Oracle: none built in for any radix.

INTEGER_TO_HEX
^^^^^^^^^^^^^^

.. code-block:: sql

   INTEGER_TO_HEX(BIGINT) CHARACTER VARYING

The same as ``INTEGER_TO_BASE(number, 16)``.

``INTEGER_TO_HEX`` is a vsql extension flagged by ``V403-20`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES INTEGER_TO_HEX(255);
  -- COL1: FF

  VALUES INTEGER_TO_HEX(-255);
  -- COL1: -FF

**Compatibility**

- **SQL standard:** not standard.
- **Other databases:**

  - MySQL: ``HEX(number)``, which writes a negative number as two's
    complement.
  - PostgreSQL: ``TO_HEX``, in lower case and two's complement for a negative
    number.
  - SQL Server: ``CONVERT(VARCHAR, CONVERT(VARBINARY, number), 2)``.
  - Oracle: ``TO_CHAR(number, 'FMXXXXXXXXXXXXXXXX')``, for a positive number.
  - SQLite: ``PRINTF('%X', number)``.
