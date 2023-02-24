Functions
=========

.. contents::

Aggregate Functions
-------------------

AVG
^^^

.. code-block:: sql

   AVG(DOUBLE PRECISION) DOUBLE PRECISION

Returns the average value. If any of the expressions are ``NULL`` the result
will also be ``NULL``.

**Examples**

.. code-block:: sql

  SELECT AVG(price) FROM products;
  -- COL1: 4.36666
  
  SELECT city, AVG(price) FROM products GROUP BY city;
  -- CITY: New York COL1: 8.96666
  -- CITY: San Francisco COL1: 6.5

COUNT
^^^^^

.. code-block:: sql

   COUNT(ANY) INTEGER

Count the number of non-``NULL`` expressions.

There is a special form ``COUNT(*)`` that will count all rows.

**Examples**

These example show the difference between count all rows and only counting those
that have a non-``NULL`` ``first_name``.

.. code-block:: sql

  SELECT COUNT(*) FROM people;
  -- 12
  
  SELECT COUNT(first_name) FROM people;
  -- 10

MAX
^^^

.. code-block:: sql

   MAX(DOUBLE PRECISION) DOUBLE PRECISION

Returns the maximum value. If any of the expressions are ``NULL`` the result
will also be ``NULL``.

**Examples**

.. code-block:: sql

  SELECT MAX(price) FROM products;
  -- COL1: 20.45
  
  SELECT city, MAX(price) FROM products GROUP BY city;
  -- CITY: New York COL1: 18.05
  -- CITY: San Francisco COL1: 17.5

MIN
^^^

.. code-block:: sql

   MIN(DOUBLE PRECISION) DOUBLE PRECISION

Returns the minimum value. If any of the expressions are ``NULL`` the result
will also be ``NULL``.

**Examples**

.. code-block:: sql

  SELECT MIN(price) FROM products;
  -- COL1: 10.45
  
  SELECT city, MIN(price) FROM products GROUP BY city;
  -- CITY: New York COL1: 8.05
  -- CITY: San Francisco COL1: 7.5

SUM
^^^

.. code-block:: sql

   SUM(DOUBLE PRECISION) DOUBLE PRECISION

Returns the sum (total) of all values. If any of the expressions are ``NULL``
the result will also be ``NULL``.

**Examples**

.. code-block:: sql

  SELECT SUM(price) FROM products;
  -- COL1: 487.75
  
  SELECT city, SUM(price) FROM products GROUP BY city;
  -- CITY: New York COL1: 196.35
  -- CITY: San Francisco COL1: 291.4

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

ABS
^^^

.. code-block:: sql

   ABS(DOUBLE PRECISION) DOUBLE PRECISION

Absolute value.

**Examples**

.. code-block:: sql

  VALUES ABS(1.2);
  -- 1.2
  
  VALUES ABS(-1.23);
  -- 1.23

ACOS
^^^^

.. code-block:: sql

   ACOS(DOUBLE PRECISION) DOUBLE PRECISION

Inverse (arc) cosine.

**Examples**

.. code-block:: sql

  VALUES ACOS(0.2);
  -- COL1: 1.369438

ASIN
^^^^

.. code-block:: sql

   ASIN(DOUBLE PRECISION) DOUBLE PRECISION

Inverse (arc) sine.

**Examples**

.. code-block:: sql

  VALUES ASIN(0.2);
  -- COL1: 0.201358

ATAN
^^^^

.. code-block:: sql

   ATAN(DOUBLE PRECISION) DOUBLE PRECISION

Inverse (arc) tangent.

**Examples**

.. code-block:: sql

  VALUES ATAN(0.2);
  -- COL1: 0.197396

CEIL
^^^^

.. code-block:: sql

   CEIL(DOUBLE PRECISION) DOUBLE PRECISION

Round up to the nearest integer.

**Examples**

.. code-block:: sql

  VALUES CEIL(3.7);
  -- COL1: 4

  VALUES CEIL(3.3);
  -- COL2: 4

  VALUES CEIL(-3.7);
  -- COL3: -3

  VALUES CEIL(-3.3);
  -- COL4: -3

  VALUES CEILING(3.7);
  -- COL1: 4

CEILING
^^^^^^^

.. code-block:: sql

   CEILING(DOUBLE PRECISION) DOUBLE PRECISION

``CEILING`` is an alias of ``CEIL``.

COS
^^^

.. code-block:: sql

   COS(DOUBLE PRECISION) DOUBLE PRECISION

Cosine.

**Examples**

.. code-block:: sql

  VALUES COS(1.2);
  -- COL1: 0.362358

COSH
^^^^

.. code-block:: sql

   COSH(DOUBLE PRECISION) DOUBLE PRECISION

Hyperbolic cosine.

**Examples**

.. code-block:: sql

  VALUES COSH(1.2);
  -- COL1: 1.810656

EXP
^^^

.. code-block:: sql

   EXP(DOUBLE PRECISION) DOUBLE PRECISION

Exponential.

**Examples**

.. code-block:: sql

  VALUES EXP(3.7);
  -- COL1: 40.447304

FLOOR
^^^^^

.. code-block:: sql

   FLOOR(DOUBLE PRECISION) DOUBLE PRECISION

Round down to the nearest integer.

**Examples**

.. code-block:: sql

  VALUES FLOOR(3.7);
  -- COL1: 3

  VALUES FLOOR(3.3);
  -- COL1: 3

  VALUES FLOOR(-3.7);
  -- COL1: -4

  VALUES FLOOR(-3.3);
  -- COL1: -4

LN
^^^

.. code-block:: sql

   LN(DOUBLE PRECISION) DOUBLE PRECISION

Natural logarithm (base e).

**Examples**

.. code-block:: sql

  VALUES LN(13.7);
  -- COL1: 2.617396

LOG10
^^^^^

.. code-block:: sql

   LOG10(DOUBLE PRECISION) DOUBLE PRECISION

Logarithm in base 10.

**Examples**

.. code-block:: sql

  VALUES LOG10(13.7);
  -- COL1: 1.136721

MOD
^^^

.. code-block:: sql

   MOD(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION

Modulus.

**Examples**

.. code-block:: sql

  VALUES MOD(232, 3);
  -- COL1: 1

  VALUES MOD(10.7, 0.8);
  -- COL1: 0.3

POWER
^^^^^

.. code-block:: sql

   POWER(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION

Power.

**Examples**

.. code-block:: sql

  VALUES POWER(3.7, 2.5);
  -- COL1: 26.333241

SIN
^^^

.. code-block:: sql

   SIN(DOUBLE PRECISION) DOUBLE PRECISION

Sine.

**Examples**

.. code-block:: sql

  VALUES SIN(1.2);
  -- COL1: 0.932039

SINH
^^^^

.. code-block:: sql

   SINH(DOUBLE PRECISION) DOUBLE PRECISION

Hyperbolic sine.

**Examples**

.. code-block:: sql

  VALUES SINH(1.2);
  -- COL1: 1.509461

SQRT
^^^^

.. code-block:: sql

   SQRT(DOUBLE PRECISION) DOUBLE PRECISION

Square root.

**Examples**

.. code-block:: sql

  VALUES SQRT(3.7);
  -- COL1: 1.923538

TAN
^^^

.. code-block:: sql

   TAN(DOUBLE PRECISION) DOUBLE PRECISION

Tangent.

**Examples**

.. code-block:: sql

  VALUES TAN(1.2);
  -- COL1: 2.572152

TANH
^^^^

.. code-block:: sql

   TANH(DOUBLE PRECISION) DOUBLE PRECISION

Hyperbolic tangent.

**Examples**

.. code-block:: sql

  VALUES TANH(1.2);
  -- COL1: 0.833655

String Functions
----------------

CHAR_LENGTH
^^^^^^^^^^^

.. code-block:: sql

   CHAR_LENGTH(CHARACTER VARYING) INTEGER

Returns the character length (multibyte chatracters are counted as a single
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

Returns the input string converted to lower-case.

.. code-block:: sql

  VALUES LOWER('Hello');
  -- COL1: hello

OCTET_LENGTH
^^^^^^^^^^^^

.. code-block:: sql

   OCTET_LENGTH(CHARACTER VARYING) INTEGER

Returns the byte length (multibyte chatracters are ignored).

.. code-block:: sql

  VALUES OCTET_LENGTH('😊£');
  -- COL1: 6

POSITION
^^^^^^^^

.. code-block:: sql

   POSITION(CHARACTER VARYING IN CHARACTER VARYING) INTEGER

Returns the start of the left most (first) match of one string within another. 1
will be the smallest index on a match and 0 is returned if the substring does
not exist.

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
``start_position`` is out of bounds (either before the start or after the end)
the returned value will be empty.

If ``string_length`` is not provided, all characters or bytes until the end will
be included. Otherwise, only ``string_length`` will be included. If
``string_length`` goes beyond the end of the string it will only be used until
the end.

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

If ``trim_character`` is not provided, a space (`' '`) is used.

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

Returns the input string converted to upper-case.

.. code-block:: sql

  VALUES UPPER('Hello');
  -- COL1: HELLO

Other Functions
---------------

COALESCE
^^^^^^^^

.. code-block:: sql

   COALESCE(VALUE, ...)

``COALESCE`` returns the first value that is not ``NULL``. If all values are
``NULL`` then ``NULL`` is also returned.

.. code-block:: sql

  VALUES COALESCE(1, 2);
  -- COL1: 1

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

``NULLIF`` is equivilent to:

.. code-block:: sql

  CASE WHEN X=Y THEN NULL ELSE X END

.. code-block:: sql

  VALUES NULLIF(123, 123);
  -- COL1: NULL
  
  VALUES NULLIF(123, 456);
  -- COL1: 123
