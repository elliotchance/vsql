Functions
=========

.. contents::

Aggregate Functions
-------------------

Aggregate functions calculate a single value from a set of rows (see
``GROUP BY`` in :doc:`select`). ``NULL`` values are ignored, with a ``01003``
warning. If all of the values are ``NULL`` (or there are no rows) the result is
``NULL``, except for ``COUNT``.

``AVG`` and ``SUM`` accept any number. ``COUNT``, ``MAX`` and ``MIN`` accept any
type.

The value can be preceded by ``DISTINCT`` to only use each value once, so
``COUNT(DISTINCT city)`` is the number of different cities. Values are the same
if they are equal with ``=``, such as ``1.5`` and ``1.50``. It can also be
preceded by ``ALL``, which is the same as not having either.

The examples use this table:

.. code-block:: sql

  CREATE TABLE products (city VARCHAR(20), price FLOAT);
  INSERT INTO products (city, price) VALUES
    ('New York', 8.05e0), ('New York', 18.05e0),
    ('San Francisco', 7.5e0), ('San Francisco', 17.5e0),
    ('San Francisco', NULL);

AVG
^^^

.. code-block:: sql

   AVG(SMALLINT) SMALLINT
   AVG(INTEGER) INTEGER
   AVG(BIGINT) BIGINT
   AVG(NUMERIC(p, s)) NUMERIC(p, s)
   AVG(DECIMAL(p, s)) DECIMAL(p, s)
   AVG(REAL) REAL
   AVG(DOUBLE PRECISION) DOUBLE PRECISION

Returns the average value. The result has the same type as the values, so the
average of exact numbers is truncated to their scale. For example, the average
of the ``INTEGER`` values 1, 2 and 4 is 2. Use a ``CAST`` to get more digits,
such as ``AVG(CAST(x AS NUMERIC(10, 2)))`` which is 2.33.

**Examples**

.. code-block:: sql

  SELECT AVG(price) FROM products;
  -- COL1: 12.775e0

  SELECT city, AVG(price) FROM products GROUP BY city;
  -- CITY: New York COL2: 13.05e0
  -- CITY: San Francisco COL2: 12.5e0

COUNT
^^^^^

.. code-block:: sql

   COUNT(ANY) INTEGER

Count the number of non-``NULL`` values.

There is a special form ``COUNT(*)`` that will count all rows.

**Examples**

These examples show the difference between counting all rows and only counting
those that have a non-``NULL`` ``price``.

.. code-block:: sql

  SELECT COUNT(*) FROM products;
  -- COL1: 5

  SELECT COUNT(price) FROM products;
  -- COL1: 4

MAX
^^^

.. code-block:: sql

   MAX(ANY) ANY

Returns the maximum value, using the same rules as ``>``. The result has the
same type as the values.

**Examples**

.. code-block:: sql

  SELECT MAX(price) FROM products;
  -- COL1: 18.05e0

  SELECT city, MAX(price) FROM products GROUP BY city;
  -- CITY: New York COL2: 18.05e0
  -- CITY: San Francisco COL2: 17.5e0

MIN
^^^

.. code-block:: sql

   MIN(ANY) ANY

Returns the minimum value, using the same rules as ``<``. The result has the
same type as the values.

**Examples**

.. code-block:: sql

  SELECT MIN(price) FROM products;
  -- COL1: 7.5e0

  SELECT city, MIN(price) FROM products GROUP BY city;
  -- CITY: New York COL2: 8.05e0
  -- CITY: San Francisco COL2: 7.5e0

SUM
^^^

.. code-block:: sql

   SUM(SMALLINT) BIGINT
   SUM(INTEGER) BIGINT
   SUM(BIGINT) BIGINT
   SUM(NUMERIC(p, s)) NUMERIC
   SUM(DECIMAL(p, s)) DECIMAL
   SUM(REAL) REAL
   SUM(DOUBLE PRECISION) DOUBLE PRECISION

Returns the sum (total) of all values. The sum of exact numbers keeps their
scale but has no limit on the precision. A ``22003`` error is returned if the
sum is out of range for the result type.

**Examples**

.. code-block:: sql

  SELECT SUM(price) FROM products;
  -- COL1: 51.1e0

  SELECT city, SUM(price) FROM products GROUP BY city;
  -- CITY: New York COL2: 26.1e0
  -- CITY: San Francisco COL2: 25e0

Date & Time
-----------

CURRENT_DATE
^^^^^^^^^^^^

See :doc:`dates-times`.

CURRENT_TIME
^^^^^^^^^^^^

See :doc:`dates-times`.

CURRENT_TIMESTAMP
^^^^^^^^^^^^^^^^^

See :doc:`dates-times`.

LOCALTIME
^^^^^^^^^

See :doc:`dates-times`.

LOCALTIMESTAMP
^^^^^^^^^^^^^^

See :doc:`dates-times`.

Mathematical Functions
----------------------

All mathematical and string functions return ``NULL`` if any argument is
``NULL``.

Mathematical functions accept any numeric argument. If there is no version of
the function for the argument's type, an exact numeric argument (such as
``INTEGER``) is converted to ``NUMERIC`` when possible, otherwise to
``DOUBLE PRECISION``. For example, ``LN(10)`` is the same as ``LN(10e0)``.

ABS
^^^

.. code-block:: sql

   ABS(SMALLINT) SMALLINT
   ABS(INTEGER) INTEGER
   ABS(BIGINT) BIGINT
   ABS(REAL) REAL
   ABS(DOUBLE PRECISION) DOUBLE PRECISION
   ABS(DECIMAL) DECIMAL
   ABS(NUMERIC) NUMERIC

Absolute value. The result is the same type as the argument. When using
``DECIMAL`` or ``NUMERIC`` the same scale and precision is returned.

**Examples**

.. code-block:: sql

  VALUES ABS(1.2e0);
  -- COL1: 1.2e0

  VALUES ABS(-1.23e0);
  -- COL1: 1.23e0

  VALUES ABS(-1.23);
  -- COL1: 1.23

ACOS
^^^^

.. code-block:: sql

   ACOS(DOUBLE PRECISION) DOUBLE PRECISION

Inverse (arc) cosine.

**Examples**

.. code-block:: sql

  VALUES ACOS(0.2);
  -- COL1: 1.369438406005e0

ASIN
^^^^

.. code-block:: sql

   ASIN(DOUBLE PRECISION) DOUBLE PRECISION

Inverse (arc) sine.

**Examples**

.. code-block:: sql

  VALUES ASIN(0.2);
  -- COL1: 0.20135792079e0

ATAN
^^^^

.. code-block:: sql

   ATAN(DOUBLE PRECISION) DOUBLE PRECISION

Inverse (arc) tangent.

**Examples**

.. code-block:: sql

  VALUES ATAN(0.2);
  -- COL1: 0.19739555985e0

CEIL
^^^^

.. code-block:: sql

   CEIL(DOUBLE PRECISION) DOUBLE PRECISION
   CEIL(NUMERIC) NUMERIC

Round up to the nearest integer. Any exact numeric argument (such as
``INTEGER`` or ``DECIMAL``) returns a ``NUMERIC`` with a scale of 0.

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

  VALUES CEILING(3.7e0);
  -- COL1: 4e0

  VALUES CEIL(3.7);
  -- COL1: 4

  VALUES CEILING(-3.7);
  -- COL1: -3

CEILING
^^^^^^^

.. code-block:: sql

   CEILING(DOUBLE PRECISION) DOUBLE PRECISION
   CEILING(NUMERIC) NUMERIC

``CEILING`` is an alias of ``CEIL``.

COS
^^^

.. code-block:: sql

   COS(DOUBLE PRECISION) DOUBLE PRECISION

Cosine.

**Examples**

.. code-block:: sql

  VALUES COS(1.2);
  -- COL1: 0.362357754477e0

COSH
^^^^

.. code-block:: sql

   COSH(DOUBLE PRECISION) DOUBLE PRECISION

Hyperbolic cosine.

**Examples**

.. code-block:: sql

  VALUES COSH(1.2);
  -- COL1: 1.810655567324e0

EXP
^^^

.. code-block:: sql

   EXP(DOUBLE PRECISION) DOUBLE PRECISION

Exponential.

**Examples**

.. code-block:: sql

  VALUES EXP(3.7);
  -- COL1: 40.447304360067e0

FLOOR
^^^^^

.. code-block:: sql

   FLOOR(DOUBLE PRECISION) DOUBLE PRECISION
   FLOOR(NUMERIC) NUMERIC

Round down to the nearest integer. Any exact numeric argument (such as
``INTEGER`` or ``DECIMAL``) returns a ``NUMERIC`` with a scale of 0.

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

LN
^^^

.. code-block:: sql

   LN(DOUBLE PRECISION) DOUBLE PRECISION

Natural logarithm (base e).

**Examples**

.. code-block:: sql

  VALUES LN(13.7);
  -- COL1: 2.617395832834e0

LOG10
^^^^^

.. code-block:: sql

   LOG10(DOUBLE PRECISION) DOUBLE PRECISION

Logarithm in base 10.

**Examples**

.. code-block:: sql

  VALUES LOG10(13.7);
  -- COL1: 1.136720567156e0

MOD
^^^

.. code-block:: sql

   MOD(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION
   MOD(NUMERIC, NUMERIC) NUMERIC
   MOD(SMALLINT, SMALLINT) SMALLINT
   MOD(INTEGER, INTEGER) INTEGER
   MOD(BIGINT, BIGINT) BIGINT

Modulus. The result has the same sign as the first argument. When both
arguments are integers, the result has the type of the second argument (such
as ``MOD(BIGINT, SMALLINT) SMALLINT``). When using
``NUMERIC`` the result will have a precision that is the highest precision
between either parameter. The scale is undetermined.

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

POWER
^^^^^

.. code-block:: sql

   POWER(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION

Power.

**Examples**

.. code-block:: sql

  VALUES POWER(3.7, 2.5);
  -- COL1: 26.333240780428e0

SIN
^^^

.. code-block:: sql

   SIN(DOUBLE PRECISION) DOUBLE PRECISION

Sine.

**Examples**

.. code-block:: sql

  VALUES SIN(1.2);
  -- COL1: 0.932039085967e0

SINH
^^^^

.. code-block:: sql

   SINH(DOUBLE PRECISION) DOUBLE PRECISION

Hyperbolic sine.

**Examples**

.. code-block:: sql

  VALUES SINH(1.2);
  -- COL1: 1.509461355412e0

SQRT
^^^^

.. code-block:: sql

   SQRT(DOUBLE PRECISION) DOUBLE PRECISION

Square root.

**Examples**

.. code-block:: sql

  VALUES SQRT(3.7);
  -- COL1: 1.923538406167e0

TAN
^^^

.. code-block:: sql

   TAN(DOUBLE PRECISION) DOUBLE PRECISION

Tangent.

**Examples**

.. code-block:: sql

  VALUES TAN(1.2);
  -- COL1: 2.572151622126e0

TANH
^^^^

.. code-block:: sql

   TANH(DOUBLE PRECISION) DOUBLE PRECISION

Hyperbolic tangent.

**Examples**

.. code-block:: sql

  VALUES TANH(1.2);
  -- COL1: 0.833654607012e0

String Functions
----------------

CHAR_LENGTH
^^^^^^^^^^^

.. code-block:: sql

   CHAR_LENGTH(CHARACTER VARYING) INTEGER

Returns the character length (multibyte characters are counted as a single
character).

.. code-block:: sql

  VALUES CHAR_LENGTH('😊£');
  -- COL1: 2

CHARACTER_LENGTH
^^^^^^^^^^^^^^^^

.. code-block:: sql

   CHARACTER_LENGTH(CHARACTER VARYING) INTEGER

``CHARACTER_LENGTH`` is an alias of ``CHAR_LENGTH``.

LOWER
^^^^^

.. code-block:: sql

   LOWER(CHARACTER VARYING) CHARACTER VARYING

Returns the input string converted to lower-case. The result has the same type
as the input, such as ``CHARACTER(5)`` for ``LOWER('Hello')``.

.. code-block:: sql

  VALUES LOWER('Hello');
  -- COL1: hello

OCTET_LENGTH
^^^^^^^^^^^^

.. code-block:: sql

   OCTET_LENGTH(CHARACTER VARYING) INTEGER

Returns the length in bytes (UTF-8).

.. code-block:: sql

  VALUES OCTET_LENGTH('😊£');
  -- COL1: 6

POSITION
^^^^^^^^

.. code-block:: sql

   POSITION(CHARACTER VARYING IN CHARACTER VARYING) INTEGER

Returns the start of the left most (first) match of one string within another. 1
will be the smallest index on a match and 0 is returned if the substring does
not exist. The position is counted in characters (a multibyte character
counts as one).

Matching is case-sensitive.

**Examples**

.. code-block:: sql

  VALUES POSITION('He' IN 'hello Hello');
  -- COL1: 7

  VALUES POSITION('xx' IN 'hello Hello');
  -- COL1: 0

SUBSTRING
^^^^^^^^^

``SUBSTRING`` can be constructed in several forms:

.. code-block:: text

   SUBSTRING(
     value
     FROM start_position
     [ FOR string_length ]
     [ USING { CHARACTERS | OCTETS } ]
   )

``start_position`` starts at 1 for the first character or byte. If
``start_position`` is after the end the returned value will be empty.

If ``string_length`` is not provided, all characters or bytes until the end will
be included. Otherwise, only ``string_length`` will be included. If
``string_length`` goes beyond the end of the string it will only be used until
the end. ``string_length`` must not be negative, otherwise a 22011 (substring
error) is raised.

``start_position`` and ``string_length`` must be integers (or a ``NUMERIC`` or
``DECIMAL`` with a scale of 0), so ``SUBSTRING('hello' FROM 2.5)`` is an error.
A host parameter can be any number that's a whole number.

A ``start_position`` before 1 is allowed, but the positions before the first
character still count towards ``string_length``. So ``SUBSTRING('hello' FROM 0
FOR 3)`` is ``'he'``.

If ``CHARACTERS`` is specified the ``start_position`` and ``string_length`` will
count in characters (this works with multibyte characters) whereas ``OCTETS``
will strictly count in bytes. If ``USING`` is not provided, ``CHARACTERS`` will
be used.

.. code-block:: sql

  VALUES SUBSTRING('hello' FROM 2);
  -- COL1: ello

  VALUES SUBSTRING('hello' FROM 20);
  -- COL1:

  VALUES SUBSTRING('hello world' FROM 3 FOR 5);
  -- COL1: llo w

  VALUES SUBSTRING('hello' FROM 0 FOR 3);
  -- COL1: he

  VALUES SUBSTRING('Жabڣc' FROM 4 USING OCTETS);
  -- COL1: bڣc

TRIM
^^^^

``TRIM`` can be constructed in several forms:

.. code-block:: text

  TRIM(
    [ [ { LEADING | TRAILING | BOTH } ] [ trim_character ] FROM ]
    trim_source
  )

If ``LEADING``, ``TRAILING`` or ``BOTH`` is not provided, ``BOTH`` is used.

If ``trim_character`` is not provided, a space (``' '``) is used.

.. code-block:: sql

  VALUES TRIM('  hello world ');
  -- COL1: hello world

  VALUES TRIM('a' FROM 'aaababccaa');
  -- COL1: babcc

  VALUES TRIM(LEADING 'a' FROM 'aaababccaa');
  -- COL1: babccaa

  VALUES TRIM(TRAILING 'a' FROM 'aaababccaa');
  -- COL1: aaababcc

UPPER
^^^^^

.. code-block:: sql

   UPPER(CHARACTER VARYING) CHARACTER VARYING

Returns the input string converted to upper-case. The result has the same type
as the input, such as ``CHARACTER(5)`` for ``UPPER('Hello')``.

.. code-block:: sql

  VALUES UPPER('Hello');
  -- COL1: HELLO

Other Functions
---------------

COALESCE
^^^^^^^^

.. code-block:: sql

   COALESCE(VALUE, VALUE, ...)

``COALESCE`` returns the first value that is not ``NULL``. If all values are
``NULL`` then ``NULL`` is also returned. It needs at least two values and they
must have compatible types (all character strings, all numbers, all
``BOOLEAN`` or the same kind of date or time). The result has a type that can
hold any of them, so ``COALESCE(1, 2.5)`` is a ``NUMERIC``.

.. code-block:: sql

  VALUES COALESCE(1, 2);
  -- COL1: 1

CURRENT_CATALOG
^^^^^^^^^^^^^^^

.. code-block:: sql

   CURRENT_CATALOG

``CURRENT_CATALOG`` is the name of the current catalog, which is the file name
up to the first ``.``. So, if the complete file path is ``/tmp/mydb.cool.vsql``
the ``CURRENT_CATALOG`` would be ``mydb``. It can be changed with
:doc:`set-catalog`.

When using in-memory databases, the ``CURRENT_CATALOG`` will be ``:memory:``.

CURRENT_SCHEMA
^^^^^^^^^^^^^^

.. code-block:: sql

   CURRENT_SCHEMA

``CURRENT_SCHEMA`` reports the current schema. The current schema is where
objects (such as tables, sequences, etc) are located or created. The default
schema is ``PUBLIC``. The current schema can be changed with :doc:`set-schema`.

NULLIF
^^^^^^

.. code-block:: sql

   NULLIF(X, Y)

If ``X`` and ``Y`` are equal, ``NULL`` will be returned. Otherwise ``X`` is
returned.

``NULLIF`` is equivalent to:

.. code-block:: sql

  CASE WHEN X=Y THEN NULL ELSE X END

.. code-block:: sql

  VALUES NULLIF(123, 123);
  -- COL1: NULL
  
  VALUES NULLIF(123, 456);
  -- COL1: 123
