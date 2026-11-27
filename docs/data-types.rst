Data Types
==========

.. contents::

Every value in vsql has a data type, and so does every column, every
expression and every parameter. This page lists all of the types, with their
aliases, parameters and limits. The pages for each kind of type explain how
they're stored, written as literals, compared and cast:

- :doc:`numbers` (exact numbers, approximate numbers and ``DECFLOAT``)
- :doc:`text` (character strings)
- :doc:`binary` (binary strings)
- :doc:`booleans`
- :doc:`dates-times` (datetimes and intervals)

Any type can be the type of a column (see :doc:`create-table`) or the target of
a ``CAST``, and any column allows ``NULL`` unless it's declared ``NOT NULL``.

Predefined Types
----------------

An alias is another name for exactly the same type. A column declared with an
alias is always shown with the name in the first column of the table (such as
in the ``INFORMATION_SCHEMA``):

.. list-table::
  :header-rows: 1

  * - Type
    - Aliases
    - Parameters
    - Limits

  * - ``SMALLINT``
    -
    -
    - -32768 to 32767

  * - ``INTEGER``
    - ``INT``
    -
    - -2147483648 to 2147483647

  * - ``BIGINT``
    -
    -
    - -9223372036854775808 to 9223372036854775807

  * - ``NUMERIC(p, s)``
    -
    - Precision *p* from 1 to 1000 (1000 if it's not specified), scale *s*
      from 0 to *p* (0 if it's not specified).
    - *p* digits, *s* of them after the decimal point

  * - ``DECIMAL(p, s)``
    - ``DEC(p, s)``
    - The same as ``NUMERIC``.
    - The same as ``NUMERIC``

  * - ``REAL``
    -
    -
    - -3.4e+38 to 3.4e+38

  * - ``DOUBLE PRECISION``
    - ``FLOAT``, ``FLOAT(p)``
    - Precision *p* from 1 to 53, which is ignored.
    - -1.7e+308 to +1.7e+308

  * - ``DECFLOAT(p)``
    -
    - Precision *p* is 16 or 34 (34 if it's not specified).
    - 16 digits and an exponent from -383 to 384, or 34 digits and an exponent
      from -6143 to 6144

  * - ``CHARACTER(n)``
    - ``CHAR(n)``, ``NATIONAL CHARACTER(n)``, ``NATIONAL CHAR(n)``,
      ``NCHAR(n)``
    - Length *n* from 1 to 10485760 (1 if it's not specified).
    - Exactly *n* characters, padded with spaces

  * - ``CHARACTER VARYING(n)``
    - ``CHAR VARYING(n)``, ``VARCHAR(n)``, ``NATIONAL CHARACTER VARYING(n)``,
      ``NATIONAL CHAR VARYING(n)``, ``NCHAR VARYING(n)``
    - Length *n* from 1 to 10485760 (10485760 if it's not specified).
    - Up to *n* characters

  * - ``CHARACTER LARGE OBJECT(n)``
    - ``CHAR LARGE OBJECT(n)``, ``CLOB(n)``,
      ``NATIONAL CHARACTER LARGE OBJECT(n)``, ``NCHAR LARGE OBJECT(n)``,
      ``NCLOB(n)``
    - Length *n* from 1 to 2147483647 (2147483647 if it's not specified),
      with an optional ``K``, ``M`` or ``G`` multiplier.
    - Up to *n* characters

  * - ``BINARY(n)``
    -
    - Length *n* from 1 to 10485760 (1 if it's not specified).
    - Exactly *n* octets, padded with ``X'00'``

  * - ``BINARY VARYING(n)``
    - ``VARBINARY(n)``
    - Length *n* from 1 to 10485760, which must be specified.
    - Up to *n* octets

  * - ``BINARY LARGE OBJECT(n)``
    - ``BLOB(n)``
    - Length *n* from 1 to 2147483647 (2147483647 if it's not specified),
      with an optional ``K``, ``M`` or ``G`` multiplier.
    - Up to *n* octets

  * - ``BOOLEAN``
    -
    -
    - ``TRUE``, ``FALSE`` or ``UNKNOWN`` (``NULL``)

  * - ``DATE``
    -
    -
    - ``0001-01-01`` to ``9999-12-31``

  * - ``TIME(f) WITHOUT TIME ZONE``
    - ``TIME(f)``
    - Fractional seconds precision *f* from 0 to 6 (0 if it's not specified).
    - ``00:00:00`` to ``23:59:59.999999``

  * - ``TIME(f) WITH TIME ZONE``
    -
    - The same as ``TIME(f) WITHOUT TIME ZONE``.
    - The same as ``TIME(f) WITHOUT TIME ZONE``, with a time zone from
      ``-14:00`` to ``+14:00``

  * - ``TIMESTAMP(f) WITHOUT TIME ZONE``
    - ``TIMESTAMP(f)``
    - Fractional seconds precision *f* from 0 to 6 (6 if it's not specified).
    - ``0001-01-01 00:00:00`` to ``9999-12-31 23:59:59.999999``

  * - ``TIMESTAMP(f) WITH TIME ZONE``
    -
    - The same as ``TIMESTAMP(f) WITHOUT TIME ZONE``.
    - The same as ``TIMESTAMP(f) WITHOUT TIME ZONE``, with a time zone from
      ``-14:00`` to ``+14:00``

  * - ``INTERVAL start(p) TO end(f)``
    -
    - An interval qualifier, such as ``YEAR TO MONTH`` or ``DAY TO SECOND``.
      The leading field precision *p* is from 1 to 8 (2 if it's not
      specified), and the fractional seconds precision *f* of a ``SECOND``
      is from 0 to 6 (6 if it's not specified).
    - *p* digits in the start field

The interval qualifiers are listed in :ref:`dates-times:INTERVAL`. A
``NUMERIC``, ``DECIMAL``, ``DECFLOAT`` or ``FLOAT`` without a precision, a
``CHARACTER VARYING``, ``CHARACTER LARGE OBJECT`` or ``BINARY LARGE OBJECT``
without a length, and a ``TIME`` or ``TIMESTAMP`` without a fractional seconds
precision all use the default in the table. ``BINARY VARYING`` is the only type
that must have a length.

The only character set is UTF-8, so the national character string types (such
as ``NCHAR``) are the same as the character string types. The length of a
character string type can also be in octets, such as ``VARCHAR(10 OCTETS)``
(see :doc:`text`).

``ARRAY``, ``MULTISET``, ``ROW``, ``JSON``, reference types and user-defined
types aren't supported.

Example
-------

The ``COLUMNS`` view of the ``INFORMATION_SCHEMA`` (see
:doc:`information-schema`) shows the type of each column, with its aliases
resolved and its defaults filled in:

.. code-block:: sql

  CREATE TABLE products (id INT, name VARCHAR(20), price DEC(7, 2), weight FLOAT);
  -- msg: CREATE TABLE 1

  SELECT column_name, data_type, character_maximum_length, numeric_precision, numeric_scale
  FROM information_schema.columns
  WHERE table_name = 'PRODUCTS'
  ORDER BY ordinal_position;
  -- COLUMN_NAME: ID DATA_TYPE: INTEGER CHARACTER_MAXIMUM_LENGTH: NULL NUMERIC_PRECISION: 32 NUMERIC_SCALE: 0
  -- COLUMN_NAME: NAME DATA_TYPE: CHARACTER VARYING CHARACTER_MAXIMUM_LENGTH: 20 NUMERIC_PRECISION: NULL NUMERIC_SCALE: NULL
  -- COLUMN_NAME: PRICE DATA_TYPE: DECIMAL CHARACTER_MAXIMUM_LENGTH: NULL NUMERIC_PRECISION: 7 NUMERIC_SCALE: 2
  -- COLUMN_NAME: WEIGHT DATA_TYPE: DOUBLE PRECISION CHARACTER_MAXIMUM_LENGTH: NULL NUMERIC_PRECISION: 53 NUMERIC_SCALE: NULL

The ``NUMERIC_PRECISION`` of an ``INTEGER`` is in bits, and of a ``DECIMAL``
in digits.

Limits
------

There are two ways to go over the limits of a type. A declared type that's
larger than its limit (or has a parameter that's out of range) is a ``42601``
error, wherever it's written, such as in ``CREATE TABLE`` or ``CAST``:

.. code-block:: sql

  CREATE TABLE t (x VARCHAR(10485761));
  -- error 42601: syntax error: CHARACTER VARYING length must not be greater than 10485760

  CREATE TABLE t (x DECFLOAT(20));
  -- error 42601: syntax error: DECFLOAT precision must be 16 or 34

A value that doesn't fit in its type is an error when the value is stored or
cast: ``22003`` for a number, ``22001`` for a character or binary string, and
``22015`` for an interval:

.. code-block:: sql

  INSERT INTO products (id, name, price, weight) VALUES (1, 'Widget', 123456.7, 1.5);
  -- error 22003: numeric value out of range

  INSERT INTO products (id, name, price, weight) VALUES (1, 'A very long product name', 1.5, 1.5);
  -- error 22001: string data right truncation for CHARACTER VARYING(20)

The limits of the file and database (such as the size of a row and the number
of columns in a table) are in :doc:`limitations`.
