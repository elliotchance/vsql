PostgreSQL Functions
====================

.. contents::
   :local:
   :depth: 1

How to write the functions you know from PostgreSQL 18 in vsql. Every function
of the "Functions and Operators" chapter of PostgreSQL's documentation is here,
in the same categories, and each one can be linked to by its name, such as
``compatibility-postgresql.html#split-part``. Functions that have no
equivalent in vsql are listed too, so you can tell that they haven't been
missed. Operators, and predicates such as ``LIKE`` and ``IS DISTINCT FROM``,
aren't listed.

Moving From PostgreSQL
----------------------

A function call on literal values becomes a ``VALUES``, so
``SELECT round(2.345, 2)`` is ``VALUES ROUND(2.345, 2);``. A call on the
columns of a table stays a ``SELECT``.

Each function shows its PostgreSQL signature, and below it the same statement
in vsql with each argument as a comment where its value goes. An example
follows with its result:

.. code-block:: sql

  -- left(string text, n integer) → text
  VALUES SUBSTRING(/*string*/ FROM 1 FOR /*n*/);
  -- left('abcde', 2)
  VALUES SUBSTRING('abcde' FROM 1 FOR 2);
  -- COL1: ab

When an optional argument changes the statement, each form has its own
statement and example. These are the other differences to watch for:

- Names that aren't quoted are folded to upper case, not lower case, so
  ``CREATE TABLE Foo`` creates ``FOO``, and a column without a name is
  ``COL1`` rather than ``?column?``. ``CURRENT_SCHEMA`` is ``PUBLIC``.
- There are no implicit conversions from text. ``'1' + 1`` and
  ``'ab' || 1`` are errors, and a ``DATE`` can't be compared with
  ``'2024-01-01'``. Use ``CAST``, or a literal with its type, such as
  ``DATE '2024-01-01'``. A ``NULL`` that has no type to take from the other
  operand needs a ``CAST`` too, such as ``CAST(NULL AS INTEGER)``.
- ``::`` works for a cast to an SQL type (``'1'::INTEGER``), but not for
  PostgreSQL's own type names such as ``int4`` or ``text``.
- Parameters can be numbered (``$1``, ``$2``, ...) as in PostgreSQL, or be the
  standard ``?``, but a statement can't use both (see
  :doc:`prepared-statements`).
- Dividing two integers gives an integer, as in PostgreSQL, but a decimal
  keeps the decimal places of its operands, so ``1 / 3.0`` is 0.3, where
  PostgreSQL gives 0.33333333333333333333. ``AVG`` of an integer column is
  an integer, and ``CAST(1.5 AS INTEGER)`` truncates to 1, where PostgreSQL
  rounds to 2.
- A number with an exponent, such as ``2.5e0``, is a ``DOUBLE PRECISION``, and
  it's printed with its exponent (``2.5e0``). In PostgreSQL it's a
  ``numeric``.
- Booleans are printed as ``TRUE`` and ``FALSE`` rather than ``t`` and ``f``,
  and a ``TIMESTAMP`` as ``2024-03-15T10:30:00``. A ``DATE`` or
  ``TIMESTAMP`` cast to a string includes its type, such as
  ``DATE '2024-03-15'``.
- Strings are only in single quotes. There are no ``E'...'`` escape strings
  or ``$$`` dollar quoting. Trailing spaces are ignored when strings are
  compared, so ``'a' = 'a  '`` is ``TRUE``.
- An empty string is not ``NULL``, as in PostgreSQL. Most functions return
  ``NULL`` when an argument is ``NULL``, and aggregates skip ``NULL`` values,
  with a ``01003`` warning when they do. ``NULL`` sorts before other values
  in ascending order, where PostgreSQL puts it last, so add ``NULLS LAST``
  (or ``NULLS FIRST`` for a descending order) to an ``ORDER BY`` to get the
  same order as PostgreSQL.
- There are no arrays, ``json``, ``uuid``, geometric, network, range or text
  search types, no window functions (``OVER``) and no functions that return a
  set of rows, so the functions for them have no equivalent. ``interval`` and
  ``bytea`` have equivalent types (``INTERVAL``, and ``BINARY VARYING`` or
  ``BINARY LARGE OBJECT``), but few functions for them yet, so most of the
  ``interval`` and ``bytea`` forms below still have no equivalent. Functions
  that aren't built in can be added with :doc:`custom-functions`.

``vsql server`` (see :doc:`server`) lets PostgreSQL clients connect to vsql.
To list the schemas and tables, it gives them a few of PostgreSQL's system
catalog functions (flagged as ``V501``), which are noted below. They aren't
available to other connections.

Example Tables
--------------

The examples that need a table use the same ``products`` table as
:doc:`compatibility-spreadsheet`, and a sequence:

.. code-block:: sql

  CREATE TABLE products (sku VARCHAR(10), name VARCHAR(20), price DECIMAL(10, 2), qty INTEGER);
  INSERT INTO products VALUES ('A1', 'Apple', 1.50, 10), ('B2', 'Banana', 0.25, 40), ('C3', 'Cherry', 4.00, 5), ('D4', 'Date', 3.00, NULL);

  CREATE SEQUENCE ids;

Comparison Functions
--------------------

num_nonnulls
^^^^^^^^^^^^

Counts how many of its arguments are not null.

.. code-block:: sql

  -- num_nonnulls(VARIADIC "any") → integer
  VALUES (CASE WHEN /*arg1*/ IS NULL THEN 0 ELSE 1 END) + (CASE WHEN /*arg2*/ IS NULL THEN 0 ELSE 1 END);
  -- num_nonnulls(1, NULL, 2)
  VALUES (CASE WHEN 1 IS NULL THEN 0 ELSE 1 END) + (CASE WHEN CAST(NULL AS INTEGER) IS NULL THEN 0 ELSE 1 END) + (CASE WHEN 2 IS NULL THEN 0 ELSE 1 END);
  -- COL1: 2

num_nulls
^^^^^^^^^

Counts how many of its arguments are null.

.. code-block:: sql

  -- num_nulls(VARIADIC "any") → integer
  VALUES (CASE WHEN /*arg1*/ IS NULL THEN 1 ELSE 0 END) + (CASE WHEN /*arg2*/ IS NULL THEN 1 ELSE 0 END);
  -- num_nulls(1, NULL, 2)
  VALUES (CASE WHEN 1 IS NULL THEN 1 ELSE 0 END) + (CASE WHEN CAST(NULL AS INTEGER) IS NULL THEN 1 ELSE 0 END) + (CASE WHEN 2 IS NULL THEN 1 ELSE 0 END);
  -- COL1: 1

Mathematical Functions
----------------------

abs
^^^

Returns the absolute value of a number.

.. code-block:: sql

  -- abs(numeric_type) → numeric_type
  VALUES ABS(/*x*/);
  -- abs(-17.4)
  VALUES ABS(-17.4);
  -- COL1: 17.4

acos
^^^^

Returns the inverse cosine of a number, in radians.

.. code-block:: sql

  -- acos(double precision) → double precision
  VALUES ACOS(/*x*/);
  -- acos(1)
  VALUES ACOS(1e0);
  -- COL1: 0e0

acosd
^^^^^

Returns the inverse cosine of a number, in degrees.

.. code-block:: sql

  -- acosd(double precision) → double precision
  VALUES DEGREES(ACOS(/*x*/));
  -- acosd(0.5)
  VALUES DEGREES(ACOS(0.5e0));
  -- COL1: 60e0

acosh
^^^^^

Returns the inverse hyperbolic cosine of a number.

.. code-block:: sql

  -- acosh(double precision) → double precision
  VALUES LN(/*x*/ + SQRT(/*x*/ * /*x*/ - 1));
  -- acosh(2)
  VALUES LN(2e0 + SQRT(2e0 * 2e0 - 1));
  -- COL1: 1.316957896925e0

asin
^^^^

Returns the inverse sine of a number, in radians.

.. code-block:: sql

  -- asin(double precision) → double precision
  VALUES ASIN(/*x*/);
  -- asin(1)
  VALUES ASIN(1e0);
  -- COL1: 1.570796326795e0

asind
^^^^^

Returns the inverse sine of a number, in degrees.

.. code-block:: sql

  -- asind(double precision) → double precision
  VALUES DEGREES(ASIN(/*x*/));
  -- asind(0.5)
  VALUES DEGREES(ASIN(0.5e0));
  -- COL1: 30e0

asinh
^^^^^

Returns the inverse hyperbolic sine of a number.

.. code-block:: sql

  -- asinh(double precision) → double precision
  VALUES LN(/*x*/ + SQRT(/*x*/ * /*x*/ + 1));
  -- asinh(1)
  VALUES LN(1e0 + SQRT(1e0 * 1e0 + 1));
  -- COL1: 0.88137358702e0

atan
^^^^

Returns the inverse tangent of a number, in radians.

.. code-block:: sql

  -- atan(double precision) → double precision
  VALUES ATAN(/*x*/);
  -- atan(1)
  VALUES ATAN(1e0);
  -- COL1: 0.785398163397e0

atan2
^^^^^

Returns the inverse tangent of y / x, in radians, using the signs of both to find the quadrant.

.. code-block:: sql

  -- atan2(y double precision, x double precision) → double precision
  VALUES ATAN2(/*y*/, /*x*/);
  -- atan2(1, 0)
  VALUES ATAN2(1e0, 0e0);
  -- COL1: 1.570796326795e0

atan2d
^^^^^^

Returns the inverse tangent of y / x, in degrees, using the signs of both to find the quadrant.

.. code-block:: sql

  -- atan2d(y double precision, x double precision) → double precision
  VALUES DEGREES(ATAN2(/*y*/, /*x*/));
  -- atan2d(1, 0)
  VALUES DEGREES(ATAN2(1e0, 0e0));
  -- COL1: 90e0

atand
^^^^^

Returns the inverse tangent of a number, in degrees.

.. code-block:: sql

  -- atand(double precision) → double precision
  VALUES DEGREES(ATAN(/*x*/));
  -- atand(1)
  VALUES DEGREES(ATAN(1e0));
  -- COL1: 45e0

atanh
^^^^^

Returns the inverse hyperbolic tangent of a number.

.. code-block:: sql

  -- atanh(double precision) → double precision
  VALUES LN((1 + /*x*/) / (1 - /*x*/)) / 2;
  -- atanh(0.5)
  VALUES LN((1 + 0.5e0) / (1 - 0.5e0)) / 2;
  -- COL1: 0.549306144334e0

cbrt
^^^^

Returns the cube root of a number.

.. code-block:: sql

  -- cbrt(double precision) → double precision
  VALUES CBRT(/*x*/);
  -- cbrt(64)
  VALUES CBRT(64e0);
  -- COL1: 4e0

ceil
^^^^

Rounds a number up to the nearest integer.

.. code-block:: sql

  -- ceil(numeric) → numeric
  VALUES CEIL(/*x*/);
  -- ceil(-42.8)
  VALUES CEIL(-42.8);
  -- COL1: -42

ceiling
^^^^^^^

Rounds a number up to the nearest integer, the same as ceil.

.. code-block:: sql

  -- ceiling(numeric) → numeric
  VALUES CEILING(/*x*/);
  -- ceiling(95.3)
  VALUES CEILING(95.3);
  -- COL1: 96

cos
^^^

Returns the cosine of an angle in radians.

.. code-block:: sql

  -- cos(double precision) → double precision
  VALUES COS(/*x*/);
  -- cos(0)
  VALUES COS(0e0);
  -- COL1: 1e0

cosd
^^^^

Returns the cosine of an angle in degrees.

.. code-block:: sql

  -- cosd(double precision) → double precision
  VALUES COS(RADIANS(/*x*/));
  -- cosd(60)
  VALUES COS(RADIANS(60e0));
  -- COL1: 0.5e0

cosh
^^^^

Returns the hyperbolic cosine of a number.

.. code-block:: sql

  -- cosh(double precision) → double precision
  VALUES COSH(/*x*/);
  -- cosh(0)
  VALUES COSH(0e0);
  -- COL1: 1e0

cot
^^^

Returns the cotangent of an angle in radians.

.. code-block:: sql

  -- cot(double precision) → double precision
  VALUES 1 / TAN(/*x*/);
  -- cot(0.5)
  VALUES 1 / TAN(0.5e0);
  -- COL1: 1.830487721712e0

cotd
^^^^

Returns the cotangent of an angle in degrees.

.. code-block:: sql

  -- cotd(double precision) → double precision
  VALUES 1 / TAN(RADIANS(/*x*/));
  -- cotd(45)
  VALUES 1 / TAN(RADIANS(45e0));
  -- COL1: 1e0

degrees
^^^^^^^

Converts radians to degrees.

.. code-block:: sql

  -- degrees(double precision) → double precision
  VALUES DEGREES(/*x*/);
  -- degrees(0.5)
  VALUES DEGREES(0.5e0);
  -- COL1: 28.647889756541e0

div
^^^

Divides two numbers and drops the fraction of the quotient (rounding towards zero).

.. code-block:: sql

  -- div(y numeric, x numeric) → numeric
  VALUES TRUNC(/*y*/ / /*x*/);
  -- div(9, 4)
  VALUES TRUNC(9 / 4.0);
  -- COL1: 2

Two integers can be divided with ``/`` alone, which also truncates.

erf
^^^

Returns the error function of a number.

.. code-block:: sql

  -- erf(double precision) → double precision
  VALUES ERF(/*x*/);
  -- erf(1.0)
  VALUES ERF(1e0);
  -- COL1: 0.84270079295e0

erfc
^^^^

Returns the complementary error function of a number (1 - erf).

.. code-block:: sql

  -- erfc(double precision) → double precision
  VALUES ERFC(/*x*/);
  -- erfc(1.0)
  VALUES ERFC(1e0);
  -- COL1: 0.15729920705e0

exp
^^^

Returns e raised to a power.

.. code-block:: sql

  -- exp(double precision) → double precision
  VALUES EXP(/*x*/);
  -- exp(1.0)
  VALUES EXP(1e0);
  -- COL1: 2.718281828459e0

PostgreSQL returns a ``numeric`` with 16 decimal places for ``exp(1.0)``, vsql a ``DOUBLE PRECISION``.

factorial
^^^^^^^^^

Returns the factorial of a whole number.

.. code-block:: sql

  -- factorial(bigint) → numeric
  VALUES FACTORIAL(/*n*/);
  -- factorial(5)
  VALUES FACTORIAL(5);
  -- COL1: 120

The largest argument is 449 (a result with 1000 digits), a larger one is a ``22003`` error.

floor
^^^^^

Rounds a number down to the nearest integer.

.. code-block:: sql

  -- floor(numeric) → numeric
  VALUES FLOOR(/*x*/);
  -- floor(-42.8)
  VALUES FLOOR(-42.8);
  -- COL1: -43

gamma
^^^^^

Returns the gamma function of a number.

.. code-block:: sql

  -- gamma(double precision) → double precision
  VALUES GAMMA(/*x*/);
  -- gamma(5)
  VALUES GAMMA(5e0);
  -- COL1: 24e0

gcd
^^^

Returns the greatest common divisor of two numbers.

.. code-block:: sql

  -- gcd(numeric_type, numeric_type) → numeric_type
  VALUES GCD(/*a*/, /*b*/);
  -- gcd(1071, 462)
  VALUES GCD(1071, 462);
  -- COL1: 21

vsql's ``GCD`` is for integers only, where PostgreSQL also takes a ``numeric`` with decimal places (``gcd(12.0, 18)`` is ``6.0``).

lcm
^^^

Returns the least common multiple of two numbers.

.. code-block:: sql

  -- lcm(numeric_type, numeric_type) → numeric_type
  VALUES LCM(/*a*/, /*b*/);
  -- lcm(4, 6)
  VALUES LCM(4, 6);
  -- COL1: 12

vsql's ``LCM`` is for integers only, where PostgreSQL also takes a ``numeric`` with decimal places.

lgamma
^^^^^^

Returns the natural logarithm of the absolute value of the gamma function.

.. code-block:: sql

  -- lgamma(double precision) → double precision
  VALUES LGAMMA(/*x*/);
  -- lgamma(1000)
  VALUES LGAMMA(1000e0);
  -- COL1: 5905.220423209182e0

ln
^^^

Returns the natural logarithm of a number.

.. code-block:: sql

  -- ln(double precision) → double precision
  VALUES LN(/*x*/);
  -- ln(2.0)
  VALUES LN(2e0);
  -- COL1: 0.69314718056e0

log
^^^

Returns the base 10 logarithm of a number, or the logarithm in any base when it has two arguments.

.. code-block:: sql

  -- log(numeric) → numeric
  VALUES LOG10(/*x*/);
  -- log(100)
  VALUES LOG10(100e0);
  -- COL1: 2e0

  -- log(b numeric, x numeric) → numeric
  VALUES LOG(/*b*/, /*x*/);
  -- log(2.0, 64.0)
  VALUES LOG(2e0, 64e0);
  -- COL1: 6e0

vsql's ``LOG`` always takes the base as its first argument.

log10
^^^^^

Returns the base 10 logarithm of a number.

.. code-block:: sql

  -- log10(numeric) → numeric
  VALUES LOG10(/*x*/);
  -- log10(1000)
  VALUES LOG10(1000e0);
  -- COL1: 3e0

min_scale
^^^^^^^^^

.. code-block:: text

  min_scale(numeric) → integer

Returns the fewest decimal places that are needed to represent a number exactly.

No equivalent.

mod
^^^

Returns the remainder of dividing y by x.

.. code-block:: sql

  -- mod(y numeric_type, x numeric_type) → numeric_type
  VALUES MOD(/*y*/, /*x*/);
  -- mod(9, 4)
  VALUES MOD(9, 4);
  -- COL1: 1

pi
^^^

Returns the number π.

.. code-block:: sql

  -- pi() → double precision
  VALUES PI();
  -- pi()
  VALUES PI();
  -- COL1: 3.14159265359e0

power
^^^^^

Raises a number to a power.

.. code-block:: sql

  -- power(a double precision, b double precision) → double precision
  VALUES POWER(/*a*/, /*b*/);
  -- power(9, 3)
  VALUES POWER(9, 3);
  -- COL1: 729e0

The result is always a ``DOUBLE PRECISION`` in vsql.

radians
^^^^^^^

Converts degrees to radians.

.. code-block:: sql

  -- radians(double precision) → double precision
  VALUES RADIANS(/*x*/);
  -- radians(45.0)
  VALUES RADIANS(45e0);
  -- COL1: 0.785398163397e0

random
^^^^^^

Returns a random number from 0 up to (but not including) 1, or a random integer between two numbers.

.. code-block:: sql

  -- random() → double precision
  VALUES RANDOM();
  -- random() < 1
  VALUES RANDOM() < 1;
  -- COL1: TRUE

  -- random(min integer, max integer) → integer
  VALUES /*min*/ + FLOOR(RANDOM() * (/*max*/ - /*min*/ + 1));
  -- random(1, 10) BETWEEN 1 AND 10
  VALUES 1 + FLOOR(RANDOM() * (10 - 1 + 1)) BETWEEN 1 AND 10;
  -- COL1: TRUE

random_normal
^^^^^^^^^^^^^

.. code-block:: text

  random_normal([mean double precision [, stddev double precision]]) → double precision

Returns a random number from a normal distribution with the given mean and standard deviation.

No equivalent.

round
^^^^^

Rounds a number to the nearest integer, or to a number of decimal places.

.. code-block:: sql

  -- round(numeric) → numeric
  VALUES ROUND(/*v*/);
  -- round(42.4)
  VALUES ROUND(42.4);
  -- COL1: 42

  -- round(v numeric, s integer) → numeric
  VALUES ROUND(/*v*/, /*s*/);
  -- round(42.4382, 2)
  VALUES ROUND(42.4382, 2);
  -- COL1: 42.44

scale
^^^^^

.. code-block:: text

  scale(numeric) → integer

Returns the number of decimal places of a numeric value.

No equivalent.

setseed
^^^^^^^

.. code-block:: text

  setseed(double precision) → void

Sets the seed of the random numbers that random() returns.

No equivalent.

sign
^^^^

Returns -1, 0 or 1 for a negative, zero or positive number.

.. code-block:: sql

  -- sign(numeric) → numeric
  VALUES SIGN(/*x*/);
  -- sign(-8.4)
  VALUES SIGN(-8.4);
  -- COL1: -1

sin
^^^

Returns the sine of an angle in radians.

.. code-block:: sql

  -- sin(double precision) → double precision
  VALUES SIN(/*x*/);
  -- sin(1)
  VALUES SIN(1e0);
  -- COL1: 0.841470984808e0

sind
^^^^

Returns the sine of an angle in degrees.

.. code-block:: sql

  -- sind(double precision) → double precision
  VALUES SIN(RADIANS(/*x*/));
  -- sind(30)
  VALUES SIN(RADIANS(30e0));
  -- COL1: 0.5e0

sinh
^^^^

Returns the hyperbolic sine of a number.

.. code-block:: sql

  -- sinh(double precision) → double precision
  VALUES SINH(/*x*/);
  -- sinh(1)
  VALUES SINH(1e0);
  -- COL1: 1.175201193644e0

sqrt
^^^^

Returns the square root of a number.

.. code-block:: sql

  -- sqrt(numeric) → numeric
  VALUES SQRT(/*x*/);
  -- sqrt(2)
  VALUES SQRT(2e0);
  -- COL1: 1.414213562373e0

tan
^^^

Returns the tangent of an angle in radians.

.. code-block:: sql

  -- tan(double precision) → double precision
  VALUES TAN(/*x*/);
  -- tan(1)
  VALUES TAN(1e0);
  -- COL1: 1.557407724655e0

tand
^^^^

Returns the tangent of an angle in degrees.

.. code-block:: sql

  -- tand(double precision) → double precision
  VALUES TAN(RADIANS(/*x*/));
  -- tand(45)
  VALUES TAN(RADIANS(45e0));
  -- COL1: 1e0

tanh
^^^^

Returns the hyperbolic tangent of a number.

.. code-block:: sql

  -- tanh(double precision) → double precision
  VALUES TANH(/*x*/);
  -- tanh(1)
  VALUES TANH(1e0);
  -- COL1: 0.761594155956e0

trim_scale
^^^^^^^^^^

.. code-block:: text

  trim_scale(numeric) → numeric

Removes the trailing zeros after the decimal point of a numeric value.

No equivalent.

trunc
^^^^^

Drops the fraction of a number, or the decimal places after a number of them.

.. code-block:: sql

  -- trunc(numeric) → numeric
  VALUES TRUNC(/*v*/);
  -- trunc(42.8)
  VALUES TRUNC(42.8);
  -- COL1: 42

  -- trunc(v numeric, s integer) → numeric
  VALUES TRUNC(/*v*/, /*s*/);
  -- trunc(42.4382, 2)
  VALUES TRUNC(42.4382, 2);
  -- COL1: 42.43

PostgreSQL also has ``trunc(macaddr)`` (see Network Address Functions), which sets the last three bytes of a MAC address to zero. It has no equivalent.

width_bucket
^^^^^^^^^^^^

Returns the number of the bucket a value falls in, when a range is split into equal buckets.

.. code-block:: sql

  -- width_bucket(operand numeric, low numeric, high numeric, count integer) → integer
  VALUES WIDTH_BUCKET(/*operand*/, /*low*/, /*high*/, /*count*/);
  -- width_bucket(5.35, 0.024, 10.06, 5)
  VALUES WIDTH_BUCKET(5.35, 0.024, 10.06, 5);
  -- COL1: 3

The form that takes an array of thresholds has no equivalent.

String Functions
----------------

ascii
^^^^^

Returns the code point of the first character of a string.

.. code-block:: sql

  -- ascii(text) → integer
  VALUES UNICODE(/*text*/);
  -- ascii('x')
  VALUES UNICODE('x');
  -- COL1: 120

bit_length
^^^^^^^^^^

Returns the number of bits in a string.

.. code-block:: sql

  -- bit_length(text) → integer
  VALUES OCTET_LENGTH(/*text*/) * 8;
  -- bit_length('jose')
  VALUES OCTET_LENGTH('jose') * 8;
  -- COL1: 32

The ``bytea`` and ``bit`` forms have no equivalent.

btrim
^^^^^

Removes the longest string of the given characters from both ends of a string.

.. code-block:: sql

  -- btrim(string text [, characters text]) → text
  VALUES BTRIM(/*string*/, /*characters*/);
  -- btrim('xyxtrimyyx', 'xy')
  VALUES BTRIM('xyxtrimyyx', 'xy');
  -- COL1: trim

The ``bytea`` form has no equivalent.

casefold
^^^^^^^^

Folds the case of a string for case-insensitive comparisons.

.. code-block:: sql

  -- casefold(text) → text
  VALUES LOWER(/*text*/);
  -- casefold('HELLO')
  VALUES LOWER('HELLO');
  -- COL1: hello

``LOWER`` is the same for most characters, but with a collation that folds ``ß`` to ``ss`` ``casefold`` changes the length of a string, and ``LOWER`` doesn't.

char_length
^^^^^^^^^^^

Returns the number of characters in a string.

.. code-block:: sql

  -- char_length(text) → integer
  VALUES CHAR_LENGTH(/*text*/);
  -- char_length('josé')
  VALUES CHAR_LENGTH('josé');
  -- COL1: 4

character_length
^^^^^^^^^^^^^^^^

Returns the number of characters in a string, the same as char_length.

.. code-block:: sql

  -- character_length(text) → integer
  VALUES CHARACTER_LENGTH(/*text*/);
  -- character_length('josé')
  VALUES CHARACTER_LENGTH('josé');
  -- COL1: 4

chr
^^^

Returns the character with a code point.

.. code-block:: sql

  -- chr(integer) → text
  VALUES CHR(/*integer*/);
  -- chr(65)
  VALUES CHR(65);
  -- COL1: A

concat
^^^^^^

Joins the text of its arguments, skipping any that are null.

.. code-block:: sql

  -- concat(val1 "any" [, val2 "any" [, ...]]) → text
  VALUES CONCAT(/*val1*/, /*val2*/, ...);
  -- concat('abcde', NULL, 'xy')
  VALUES CONCAT('abcde', CAST(NULL AS VARCHAR(10)), 'xy');
  -- COL1: abcdexy

A number has to be cast to a string first, and so does a ``NULL``.

concat_ws
^^^^^^^^^

Joins the text of its arguments with a separator between them, skipping any that are null.

.. code-block:: sql

  -- concat_ws(sep text, val1 "any" [, val2 "any" [, ...]]) → text
  VALUES CONCAT_WS(/*sep*/, /*val1*/, /*val2*/, ...);
  -- concat_ws(',', 'abcde', 'xy')
  VALUES CONCAT_WS(',', 'abcde', 'xy');
  -- COL1: abcde,xy

format
^^^^^^

Builds a string from a template, putting each argument in place of a %s, %I or %L.

.. code-block:: sql

  -- format(formatstr text [, formatarg "any" [, ...]]) → text
  VALUES /*text before %s*/ || /*formatarg*/ || /*text after %s*/;
  -- format('Hello %s!', 'World')
  VALUES 'Hello ' || 'World' || '!';
  -- COL1: Hello World!

``%I`` and ``%L`` quote the argument as a name or a literal, see quote_ident and quote_literal. Widths and argument positions have no equivalent.

initcap
^^^^^^^

Converts the first letter of each word to upper case and the rest to lower case.

.. code-block:: sql

  -- initcap(text) → text
  VALUES INITCAP(/*text*/);
  -- initcap('hi THOMAS')
  VALUES INITCAP('hi THOMAS');
  -- COL1: Hi Thomas

left
^^^^

Returns the first n characters of a string.

.. code-block:: sql

  -- left(string text, n integer) → text
  VALUES SUBSTRING(/*string*/ FROM 1 FOR /*n*/);
  -- left('abcde', 2)
  VALUES SUBSTRING('abcde' FROM 1 FOR 2);
  -- COL1: ab

When n is negative, PostgreSQL returns all but the last -n characters, which is ``SUBSTRING(string FROM 1 FOR CHAR_LENGTH(string) + n)``.

length
^^^^^^

Returns the number of characters in a string.

.. code-block:: sql

  -- length(text) → integer
  VALUES CHAR_LENGTH(/*text*/);
  -- length('jose')
  VALUES CHAR_LENGTH('jose');
  -- COL1: 4

The forms of ``length`` for ``bytea``, ``bit``, geometric paths and ``tsvector`` have no equivalent.

lower
^^^^^

Converts a string to lower case.

.. code-block:: sql

  -- lower(text) → text
  VALUES LOWER(/*text*/);
  -- lower('TOM')
  VALUES LOWER('TOM');
  -- COL1: tom

The ``lower`` of a range or multirange (its lower bound) has no equivalent.

lpad
^^^^

Pads a string on the left to a length, with spaces or the given characters, and cuts it to that length if it's longer.

.. code-block:: sql

  -- lpad(string text, length integer [, fill text]) → text
  VALUES LPAD(/*string*/, /*length*/, /*fill*/);
  -- lpad('hi', 5, 'xy')
  VALUES LPAD('hi', 5, 'xy');
  -- COL1: xyxhi

ltrim
^^^^^

Removes the longest string of the given characters from the start of a string.

.. code-block:: sql

  -- ltrim(string text [, characters text]) → text
  VALUES LTRIM(/*string*/, /*characters*/);
  -- ltrim('zzzytest', 'xyz')
  VALUES LTRIM('zzzytest', 'xyz');
  -- COL1: test

The ``bytea`` form has no equivalent.

md5
^^^

.. code-block:: text

  md5(text) → text
  md5(bytea) → text

Returns the MD5 hash of a string as hexadecimal.

No equivalent.

normalize
^^^^^^^^^

.. code-block:: text

  normalize(text [, form]) → text

Converts a string to a Unicode normalization form (NFC by default).

No equivalent.

octet_length
^^^^^^^^^^^^

Returns the number of bytes in a string.

.. code-block:: sql

  -- octet_length(text) → integer
  VALUES OCTET_LENGTH(/*text*/);
  -- octet_length('josé')
  VALUES OCTET_LENGTH('josé');
  -- COL1: 5

The ``bytea`` and ``bit`` forms have no equivalent.

overlay
^^^^^^^

Replaces part of a string, from a position and for a number of characters, with another string.

.. code-block:: sql

  -- overlay(string text PLACING newsubstring text FROM start integer [FOR count integer]) → text
  VALUES OVERLAY(/*string*/ PLACING /*newsubstring*/ FROM /*start*/ FOR /*count*/);
  -- overlay('Txxxxas' placing 'hom' from 2 for 4)
  VALUES OVERLAY('Txxxxas' PLACING 'hom' FROM 2 FOR 4);
  -- COL1: Thomas

The ``bytea`` and ``bit`` forms have no equivalent.

parse_ident
^^^^^^^^^^^

.. code-block:: text

  parse_ident(str text [, strict boolean DEFAULT true]) → text[]

Splits a qualified name, such as a schema and table, into an array of its parts.

No equivalent.

pg_client_encoding
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_client_encoding() → name

Returns the name of the character encoding of the client.

No equivalent.

vsql always uses UTF-8.

position
^^^^^^^^

Returns the position of the first occurrence of a substring, or 0 if it isn't there.

.. code-block:: sql

  -- position(substring text IN string text) → integer
  VALUES POSITION(/*substring*/ IN /*string*/);
  -- position('om' in 'Thomas')
  VALUES POSITION('om' IN 'Thomas');
  -- COL1: 3

The ``bytea`` and ``bit`` forms have no equivalent.

quote_ident
^^^^^^^^^^^

Quotes a string so that it can be used as a name in a statement.

.. code-block:: sql

  -- quote_ident(text) → text
  VALUES '"' || REPLACE(/*text*/, '"', '""') || '"';
  -- quote_ident('Foo bar')
  VALUES '"' || REPLACE('Foo bar', '"', '""') || '"';
  -- COL1: "Foo bar"

PostgreSQL only adds the quotes when the name needs them, so ``quote_ident('foo')`` is ``foo``. A name in quotes always works.

quote_literal
^^^^^^^^^^^^^

Quotes a string so that it can be used as a string literal in a statement.

.. code-block:: sql

  -- quote_literal(text) → text
  VALUES '''' || REPLACE(/*text*/, '''', '''''') || '''';
  -- quote_literal('O''Reilly')
  VALUES '''' || REPLACE('O''Reilly', '''', '''''') || '''';
  -- COL1: 'O''Reilly'

PostgreSQL also accepts any type and returns ``NULL`` for ``NULL``. A string with a backslash becomes an ``E'...'`` string in PostgreSQL.

quote_nullable
^^^^^^^^^^^^^^

Quotes a string so that it can be used as a string literal in a statement, or returns NULL (unquoted) for null.

.. code-block:: sql

  -- quote_nullable(text) → text
  VALUES COALESCE('''' || REPLACE(/*text*/, '''', '''''') || '''', 'NULL');
  -- quote_nullable(NULL)
  VALUES COALESCE('''' || REPLACE(CAST(NULL AS VARCHAR(10)), '''', '''''') || '''', 'NULL');
  -- COL1: NULL

repeat
^^^^^^

Repeats a string a number of times.

.. code-block:: sql

  -- repeat(string text, number integer) → text
  VALUES REPEAT(/*string*/, /*number*/);
  -- repeat('Pg', 4)
  VALUES REPEAT('Pg', 4);
  -- COL1: PgPgPgPg

replace
^^^^^^^

Replaces every occurrence of a substring with another string.

.. code-block:: sql

  -- replace(string text, from text, to text) → text
  VALUES REPLACE(/*string*/, /*from*/, /*to*/);
  -- replace('abcdefabcdef', 'cd', 'XX')
  VALUES REPLACE('abcdefabcdef', 'cd', 'XX');
  -- COL1: abXXefabXXef

reverse
^^^^^^^

.. code-block:: text

  reverse(text) → text
  reverse(bytea) → bytea

Reverses the order of the characters (or bytes) of a string.

No equivalent.

right
^^^^^

Returns the last n characters of a string.

.. code-block:: sql

  -- right(string text, n integer) → text
  VALUES SUBSTRING(/*string*/ FROM CHAR_LENGTH(/*string*/) - /*n*/ + 1);
  -- right('abcde', 2)
  VALUES SUBSTRING('abcde' FROM CHAR_LENGTH('abcde') - 2 + 1);
  -- COL1: de

When n is negative, PostgreSQL returns all but the first -n characters, which is ``SUBSTRING(string FROM 1 - n)``.

rpad
^^^^

Pads a string on the right to a length, with spaces or the given characters, and cuts it to that length if it's longer.

.. code-block:: sql

  -- rpad(string text, length integer [, fill text]) → text
  VALUES RPAD(/*string*/, /*length*/, /*fill*/);
  -- rpad('hi', 5, 'xy')
  VALUES RPAD('hi', 5, 'xy');
  -- COL1: hixyx

rtrim
^^^^^

Removes the longest string of the given characters from the end of a string.

.. code-block:: sql

  -- rtrim(string text [, characters text]) → text
  VALUES RTRIM(/*string*/, /*characters*/);
  -- rtrim('testxxzx', 'xyz')
  VALUES RTRIM('testxxzx', 'xyz');
  -- COL1: test

The ``bytea`` form has no equivalent.

split_part
^^^^^^^^^^

Splits a string on a delimiter and returns the nth field, counting from the end when n is negative.

.. code-block:: sql

  -- split_part(string text, delimiter text, n integer) → text
  VALUES SPLIT_PART(/*string*/, /*delimiter*/, /*n*/);
  -- split_part('abc~@~def~@~ghi', '~@~', 2)
  VALUES SPLIT_PART('abc~@~def~@~ghi', '~@~', 2);
  -- COL1: def

starts_with
^^^^^^^^^^^

Tests if a string starts with a prefix.

.. code-block:: sql

  -- starts_with(string text, prefix text) → boolean
  VALUES SUBSTRING(/*string*/ FROM 1 FOR CHAR_LENGTH(/*prefix*/)) = /*prefix*/;
  -- starts_with('alphabet', 'alph')
  VALUES SUBSTRING('alphabet' FROM 1 FOR CHAR_LENGTH('alph')) = 'alph';
  -- COL1: TRUE

When the prefix is a literal without ``%`` or ``_``, ``'alphabet' LIKE 'alph%'`` is shorter.

string_to_array
^^^^^^^^^^^^^^^

.. code-block:: text

  string_to_array(string text, delimiter text [, null_string text]) → text[]

Splits a string on a delimiter into an array.

No equivalent.

``SPLIT_PART`` returns one of the fields.

string_to_table
^^^^^^^^^^^^^^^

.. code-block:: text

  string_to_table(string text, delimiter text [, null_string text]) → setof text

Splits a string on a delimiter into a row for each field.

No equivalent.

``SPLIT_PART`` returns one of the fields.

strpos
^^^^^^

Returns the position of the first occurrence of a substring, or 0 if it isn't there.

.. code-block:: sql

  -- strpos(string text, substring text) → integer
  VALUES POSITION(/*substring*/ IN /*string*/);
  -- strpos('high', 'ig')
  VALUES POSITION('ig' IN 'high');
  -- COL1: 2

substr
^^^^^^

Returns the part of a string from a position, for a number of characters or to the end.

.. code-block:: sql

  -- substr(string text, start integer [, count integer]) → text
  VALUES SUBSTRING(/*string*/ FROM /*start*/ FOR /*count*/);
  -- substr('alphabet', 3, 2)
  VALUES SUBSTRING('alphabet' FROM 3 FOR 2);
  -- COL1: ph

The ``bytea`` form has no equivalent.

substring
^^^^^^^^^

Returns the part of a string from a position for a number of characters, or the part that matches a pattern.

.. code-block:: sql

  -- substring(string text [FROM start integer] [FOR count integer]) → text
  VALUES SUBSTRING(/*string*/ FROM /*start*/ FOR /*count*/);
  -- substring('Thomas' from 2 for 3)
  VALUES SUBSTRING('Thomas' FROM 2 FOR 3);
  -- COL1: hom

  -- substring(string text SIMILAR pattern text ESCAPE escape text) → text
  VALUES SUBSTRING(/*string*/ SIMILAR /*pattern*/ ESCAPE /*escape*/);
  -- substring('Thomas' similar '%#"o_a#"_' escape '#')
  VALUES SUBSTRING('Thomas' SIMILAR '%#"o_a#"_' ESCAPE '#');
  -- COL1: oma

The form with a POSIX regular expression (``substring('Thomas' from '...$')``) has no equivalent, nor do the ``bytea`` and ``bit`` forms.

to_ascii
^^^^^^^^

.. code-block:: text

  to_ascii(string text [, encoding name]) → text

Converts a string from another encoding to ASCII, dropping accents.

No equivalent.

to_bin
^^^^^^

.. code-block:: text

  to_bin(integer) → text
  to_bin(bigint) → text

Converts a number to its binary digits (two's complement for negative numbers).

No equivalent.

to_hex
^^^^^^

.. code-block:: text

  to_hex(integer) → text
  to_hex(bigint) → text

Converts a number to its hexadecimal digits (two's complement for negative numbers).

No equivalent.

to_oct
^^^^^^

.. code-block:: text

  to_oct(integer) → text
  to_oct(bigint) → text

Converts a number to its octal digits (two's complement for negative numbers).

No equivalent.

translate
^^^^^^^^^

Replaces each character of a string that is in one set with the character at the same position in another set, or removes it if there's none.

.. code-block:: sql

  -- translate(string text, from text, to text) → text
  VALUES REPLACE(REPLACE(/*string*/, /*from char 1*/, /*to char 1*/), /*from char 2*/, /*to char 2*/);
  -- translate('12345', '143', 'ax')
  VALUES REPLACE(REPLACE(REPLACE('12345', '1', 'a'), '4', 'x'), '3', '');
  -- COL1: a2x5

Each character needs its own ``REPLACE``, and this only works when a replacement character isn't also one to be replaced.

trim
^^^^

Removes the longest string of the given characters (spaces by default) from the start, the end or both ends of a string.

.. code-block:: sql

  -- trim([LEADING | TRAILING | BOTH] [characters text] FROM string text) → text
  VALUES TRIM(BOTH /*characters*/ FROM /*string*/);
  -- trim(both 'x' from 'xTomxx')
  VALUES TRIM(BOTH 'x' FROM 'xTomxx');
  -- COL1: Tom

  -- trim([LEADING | TRAILING | BOTH] [characters text] FROM string text) → text
  VALUES BTRIM(/*string*/, /*characters*/);
  -- trim(both 'xyz' from 'yxTomxx')
  VALUES BTRIM('yxTomxx', 'xyz');
  -- COL1: Tom

vsql's ``TRIM`` only removes one character (an error ``22027`` for more), so several characters need ``BTRIM``, ``LTRIM`` or ``RTRIM``. The ``bytea`` form has no equivalent.

unicode_assigned
^^^^^^^^^^^^^^^^

.. code-block:: text

  unicode_assigned(text) → boolean

Tests if every character of a string is assigned in the Unicode version of the database.

No equivalent.

unistr
^^^^^^

.. code-block:: text

  unistr(text) → text

Converts Unicode escapes such as \0041 or A in a string to their characters.

No equivalent.

upper
^^^^^

Converts a string to upper case.

.. code-block:: sql

  -- upper(text) → text
  VALUES UPPER(/*text*/);
  -- upper('tom')
  VALUES UPPER('tom');
  -- COL1: TOM

The ``upper`` of a range or multirange (its upper bound) has no equivalent.

Binary String Functions
-----------------------

These are for the ``bytea`` type, which vsql doesn't have. The functions that
are also for text, such as ``substring`` and ``position``, are in `String
Functions`_.

bit_count
^^^^^^^^^

.. code-block:: text

  bit_count(bytes bytea) → bigint
  bit_count(bit) → bigint

Counts how many bits of a binary or bit string are set.

No equivalent.

convert
^^^^^^^

.. code-block:: text

  convert(bytes bytea, src_encoding name, dest_encoding name) → bytea

Converts bytes from one character encoding to another.

No equivalent.

convert_from
^^^^^^^^^^^^

.. code-block:: text

  convert_from(bytes bytea, src_encoding name) → text

Converts bytes in a character encoding to text in the database encoding.

No equivalent.

convert_to
^^^^^^^^^^

.. code-block:: text

  convert_to(string text, dest_encoding name) → bytea

Converts text to bytes in a character encoding.

No equivalent.

crc32
^^^^^

.. code-block:: text

  crc32(bytea) → bigint

Returns the CRC-32 checksum of bytes.

No equivalent.

crc32c
^^^^^^

.. code-block:: text

  crc32c(bytea) → bigint

Returns the CRC-32C checksum of bytes.

No equivalent.

decode
^^^^^^

.. code-block:: text

  decode(string text, format text) → bytea

Converts text in base64, base64url, escape or hex format to bytes.

No equivalent.

encode
^^^^^^

.. code-block:: text

  encode(bytes bytea, format text) → text

Converts bytes to text in base64, base64url, escape or hex format.

No equivalent.

get_bit
^^^^^^^

.. code-block:: text

  get_bit(bytes bytea, n bigint) → integer
  get_bit(bits bit, n integer) → integer

Returns the nth bit of a binary or bit string.

No equivalent.

get_byte
^^^^^^^^

.. code-block:: text

  get_byte(bytes bytea, n integer) → integer

Returns the nth byte of a binary string.

No equivalent.

set_bit
^^^^^^^

.. code-block:: text

  set_bit(bytes bytea, n bigint, newvalue integer) → bytea
  set_bit(bits bit, n integer, newvalue integer) → bit

Returns a binary or bit string with its nth bit set to a value.

No equivalent.

set_byte
^^^^^^^^

.. code-block:: text

  set_byte(bytes bytea, n integer, newvalue integer) → bytea

Returns a binary string with its nth byte set to a value.

No equivalent.

sha224
^^^^^^

.. code-block:: text

  sha224(bytea) → bytea

Returns the SHA-224 hash of bytes.

No equivalent.

sha256
^^^^^^

.. code-block:: text

  sha256(bytea) → bytea

Returns the SHA-256 hash of bytes.

No equivalent.

sha384
^^^^^^

.. code-block:: text

  sha384(bytea) → bytea

Returns the SHA-384 hash of bytes.

No equivalent.

sha512
^^^^^^

.. code-block:: text

  sha512(bytea) → bytea

Returns the SHA-512 hash of bytes.

No equivalent.

Bit String Functions
--------------------

The functions for the ``bit`` and ``bit varying`` types, which vsql doesn't
have, share their names with ones for text and ``bytea``: ``bit_count``,
``get_bit`` and ``set_bit`` are in `Binary String Functions`_, and
``bit_length``, ``length``, ``octet_length``, ``overlay``, ``position`` and
``substring`` are in `String Functions`_.

Pattern Matching Functions
--------------------------

``LIKE``, ``ILIKE``, ``SIMILAR TO`` and ``SUBSTRING ... SIMILAR`` work in vsql
as they do in PostgreSQL. POSIX regular expressions (``~`` and the
``regexp_`` functions) have no equivalent.

regexp_count
^^^^^^^^^^^^

.. code-block:: text

  regexp_count(string text, pattern text [, start integer [, flags text]]) → integer

Counts how many times a POSIX regular expression matches a string.

No equivalent.

regexp_instr
^^^^^^^^^^^^

.. code-block:: text

  regexp_instr(string text, pattern text [, start integer [, N integer [, endoption integer [, flags text [, subexpr integer]]]]]) → integer

Returns the position of the Nth match of a POSIX regular expression in a string, or 0 if there's none.

No equivalent.

regexp_like
^^^^^^^^^^^

Tests if a POSIX regular expression matches anywhere in a string.

.. code-block:: sql

  -- regexp_like(string text, pattern text [, flags text]) → boolean
  VALUES /*string*/ SIMILAR TO '%' || /*pattern*/ || '%';
  -- regexp_like('Hello World', 'o W')
  VALUES 'Hello World' SIMILAR TO '%' || 'o W' || '%';
  -- COL1: TRUE

``SIMILAR TO`` must match the whole string, hence the ``%`` on each side, and its patterns use ``%`` and ``_`` rather than ``.*`` and ``.``. Flags such as ``i`` have no equivalent, but ``LOWER`` on both sides makes the match case insensitive.

regexp_match
^^^^^^^^^^^^

.. code-block:: text

  regexp_match(string text, pattern text [, flags text]) → text[]

Returns an array of the substrings captured by the first match of a POSIX regular expression.

No equivalent.

``SUBSTRING(string SIMILAR pattern ESCAPE '#')`` returns the part of a ``SIMILAR TO`` match between ``#"`` and ``#"``.

regexp_matches
^^^^^^^^^^^^^^

.. code-block:: text

  regexp_matches(string text, pattern text [, flags text]) → setof text[]

Returns a row with an array of the captured substrings for each match of a POSIX regular expression.

No equivalent.

regexp_replace
^^^^^^^^^^^^^^

.. code-block:: text

  regexp_replace(string text, pattern text, replacement text [, start integer [, N integer]] [, flags text]) → text

Replaces the first (or Nth, or every) match of a POSIX regular expression in a string.

No equivalent.

``REPLACE`` replaces every occurrence of a fixed string.

regexp_split_to_array
^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  regexp_split_to_array(string text, pattern text [, flags text]) → text[]

Splits a string into an array, using a POSIX regular expression as the delimiter.

No equivalent.

regexp_split_to_table
^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  regexp_split_to_table(string text, pattern text [, flags text]) → setof text

Splits a string into rows, using a POSIX regular expression as the delimiter.

No equivalent.

regexp_substr
^^^^^^^^^^^^^

.. code-block:: text

  regexp_substr(string text, pattern text [, start integer [, N integer [, flags text [, subexpr integer]]]]) → text

Returns the substring of the Nth match of a POSIX regular expression in a string.

No equivalent.

Data Type Formatting Functions
------------------------------

vsql has no format patterns, but ``CAST`` converts between strings and numbers,
dates and times in their standard forms.

to_char
^^^^^^^

Converts a number, date, time or interval to a string, using a format pattern.

.. code-block:: sql

  -- to_char(numeric_type, text) → text
  VALUES CAST(/*numeric_type*/ AS VARCHAR(/*length*/));
  -- to_char(125.8, 'FM999.9')
  VALUES CAST(125.8 AS VARCHAR(10));
  -- COL1: 125.8

A ``DATE`` or ``TIMESTAMP`` cast to a string includes its type, such as ``DATE '2024-03-15'``. Other formats have no equivalent.

to_date
^^^^^^^

Converts a string to a date, using a format pattern.

.. code-block:: sql

  -- to_date(text, text) → date
  VALUES CAST(/*text*/ AS DATE);
  -- to_date('2024-03-15', 'YYYY-MM-DD')
  VALUES CAST('2024-03-15' AS DATE);
  -- COL1: 2024-03-15

Only strings in the ``YYYY-MM-DD`` form can be cast.

to_number
^^^^^^^^^

Converts a string to a number, using a format pattern.

.. code-block:: sql

  -- to_number(text, text) → numeric
  VALUES CAST(/*text*/ AS DECIMAL(/*precision*/, /*scale*/));
  -- to_number('125.8', '999.9')
  VALUES CAST('125.8' AS DECIMAL(10, 1));
  -- COL1: 125.8

Group separators, currency symbols and other formats have no equivalent.

to_timestamp
^^^^^^^^^^^^

Converts a string to a timestamp with time zone, using a format pattern, or converts the number of seconds since 1970-01-01 to one.

.. code-block:: sql

  -- to_timestamp(text, text) → timestamp with time zone
  VALUES CAST(/*text*/ AS TIMESTAMP(0));
  -- to_timestamp('2024-03-15 10:30:00', 'YYYY-MM-DD HH24:MI:SS')
  VALUES CAST('2024-03-15 10:30:00' AS TIMESTAMP(0));
  -- COL1: 2024-03-15T10:30:00

The result is a ``TIMESTAMP`` without a time zone. Only strings in the ``YYYY-MM-DD HH:MM:SS`` form can be cast. ``to_timestamp(double precision)``, from the seconds since 1970, has no equivalent.

Date/Time Functions
-------------------

vsql has no ``interval`` type, so the functions that take or return one have
no equivalent, and neither does adding a number of days to a ``DATE``.

age
^^^

.. code-block:: text

  age(timestamp, timestamp) → interval
  age(timestamp) → interval

Returns the interval between two timestamps (or from a timestamp to midnight today) in years, months and days.

No equivalent.

``age(xid)`` (see System Information Functions) has no equivalent either.

clock_timestamp
^^^^^^^^^^^^^^^

Returns the time now, read from the clock each time it's called, even within one statement.

.. code-block:: sql

  -- clock_timestamp() → timestamp with time zone
  VALUES NOW();
  -- clock_timestamp() > '2020-01-01'
  VALUES NOW() > TIMESTAMP '2020-01-01 00:00:00+00:00';
  -- COL1: TRUE

``NOW()`` in vsql reads the clock like ``clock_timestamp()``, where PostgreSQL's ``now()`` is the time the transaction started.

current_date
^^^^^^^^^^^^

Returns the current date.

.. code-block:: sql

  -- current_date → date
  VALUES CURRENT_DATE;
  -- current_date = CAST(current_timestamp AS date)
  VALUES CURRENT_DATE = CAST(CURRENT_TIMESTAMP AS DATE);
  -- COL1: TRUE

current_time
^^^^^^^^^^^^

Returns the current time of day with the time zone, optionally with a precision.

.. code-block:: sql

  -- current_time → time with time zone
  VALUES CURRENT_TIME;
  -- current_time(0) IS NOT NULL
  VALUES CURRENT_TIME(0) IS NOT NULL;
  -- COL1: TRUE

Without a precision, vsql's ``CURRENT_TIME`` has whole seconds (``TIME(0)``), where PostgreSQL's has microseconds.

current_timestamp
^^^^^^^^^^^^^^^^^

Returns the current date and time with the time zone, optionally with a precision.

.. code-block:: sql

  -- current_timestamp → timestamp with time zone
  VALUES CURRENT_TIMESTAMP;
  -- current_timestamp > '2020-01-01'
  VALUES CURRENT_TIMESTAMP > TIMESTAMP '2020-01-01 00:00:00+00:00';
  -- COL1: TRUE

In vsql it's the time the statement started, in PostgreSQL the time the transaction started.

date_add
^^^^^^^^

.. code-block:: text

  date_add(timestamp with time zone, interval [, text]) → timestamp with time zone

Adds an interval to a timestamp with time zone, in a time zone.

No equivalent.

date_bin
^^^^^^^^

.. code-block:: text

  date_bin(interval, timestamp, timestamp) → timestamp

Rounds a timestamp down to the start of the bucket of a given width it falls in, counting from an origin.

No equivalent.

date_part
^^^^^^^^^

Returns a field of a timestamp or interval, such as the year or the hour.

.. code-block:: sql

  -- date_part(text, timestamp) → double precision
  VALUES EXTRACT(/*field*/ FROM /*timestamp*/);
  -- date_part('year', timestamp '2024-03-15 10:30:00')
  VALUES EXTRACT(YEAR FROM TIMESTAMP '2024-03-15 10:30:00');
  -- COL1: 2024

The field is a keyword, not a string, and the result is an ``INTEGER`` (a ``NUMERIC`` for ``SECOND`` and ``EPOCH``), not a ``double precision``. See extract_ for the fields vsql has. ``date_part`` of an interval has no equivalent.

date_subtract
^^^^^^^^^^^^^

.. code-block:: text

  date_subtract(timestamp with time zone, interval [, text]) → timestamp with time zone

Subtracts an interval from a timestamp with time zone, in a time zone.

No equivalent.

date_trunc
^^^^^^^^^^

Truncates a timestamp to the start of a unit, such as the day or the month.

.. code-block:: sql

  -- date_trunc(text, timestamp) → timestamp
  VALUES CAST(CAST(/*timestamp*/ AS DATE) AS TIMESTAMP(0));
  -- date_trunc('day', timestamp '2024-03-15 10:30:00')
  VALUES CAST(CAST(TIMESTAMP '2024-03-15 10:30:00' AS DATE) AS TIMESTAMP(0));
  -- COL1: 2024-03-15T00:00:00

This is for ``'day'``. The larger units can be built from the fields that are kept, such as ``MAKE_TIMESTAMP(EXTRACT(YEAR FROM ts), EXTRACT(MONTH FROM ts), 1, 0, 0, 0)`` for ``'month'``. The other units, and ``date_trunc`` of an interval, have no equivalent.

extract
^^^^^^^

Returns a field of a date, time, timestamp or interval, such as the year or the hour.

.. code-block:: sql

  -- extract(field FROM timestamp) → numeric
  VALUES EXTRACT(/*field*/ FROM /*timestamp*/);
  -- extract(hour FROM timestamp '2024-03-15 10:30:00')
  VALUES EXTRACT(HOUR FROM TIMESTAMP '2024-03-15 10:30:00');
  -- COL1: 10

The result is an ``INTEGER``, or a ``NUMERIC`` with the precision of the value for ``SECOND`` and ``EPOCH``, where PostgreSQL always returns a ``numeric``. The fields are ``YEAR``, ``MONTH``, ``DAY``, ``HOUR``, ``MINUTE``, ``SECOND``, ``TIMEZONE_HOUR``, ``TIMEZONE_MINUTE``, ``DOW``, ``ISODOW``, ``DOY``, ``WEEK``, ``ISOYEAR``, ``QUARTER`` and ``EPOCH``, with the same meaning as in PostgreSQL. ``CENTURY``, ``DECADE``, ``MILLENNIUM``, ``MILLISECONDS``, ``MICROSECONDS``, ``JULIAN`` and ``TIMEZONE`` have no equivalent. The fields of a timestamp with time zone are in its own time zone, where PostgreSQL first converts it to the time zone of the session, so ``extract(hour FROM timestamptz '2024-03-15 10:30:00-05')`` is ``15`` in a UTC session and ``10`` in vsql. ``extract`` of an interval has no equivalent.

isfinite
^^^^^^^^

.. code-block:: text

  isfinite(date) → boolean
  isfinite(timestamp) → boolean
  isfinite(interval) → boolean

Tests if a date, timestamp or interval is not infinity.

No equivalent.

vsql has no infinite dates, so every date is finite.

justify_days
^^^^^^^^^^^^

.. code-block:: text

  justify_days(interval) → interval

Converts each 30 days of an interval to a month.

No equivalent.

justify_hours
^^^^^^^^^^^^^

.. code-block:: text

  justify_hours(interval) → interval

Converts each 24 hours of an interval to a day.

No equivalent.

justify_interval
^^^^^^^^^^^^^^^^

.. code-block:: text

  justify_interval(interval) → interval

Converts the days and hours of an interval to months and days, with the signs made consistent.

No equivalent.

localtime
^^^^^^^^^

Returns the current time of day without a time zone, optionally with a precision.

.. code-block:: sql

  -- localtime → time
  VALUES LOCALTIME;
  -- localtime(0) IS NOT NULL
  VALUES LOCALTIME(0) IS NOT NULL;
  -- COL1: TRUE

Without a precision, vsql's ``LOCALTIME`` has whole seconds (``TIME(0)``), where PostgreSQL's has microseconds.

localtimestamp
^^^^^^^^^^^^^^

Returns the current date and time without a time zone, optionally with a precision.

.. code-block:: sql

  -- localtimestamp → timestamp
  VALUES LOCALTIMESTAMP;
  -- localtimestamp > '2020-01-01'
  VALUES LOCALTIMESTAMP > TIMESTAMP '2020-01-01 00:00:00';
  -- COL1: TRUE

make_date
^^^^^^^^^

Builds a date from a year, month and day.

.. code-block:: sql

  -- make_date(year int, month int, day int) → date
  VALUES MAKE_DATE(/*year*/, /*month*/, /*day*/);
  -- make_date(2013, 7, 15)
  VALUES MAKE_DATE(2013, 7, 15);
  -- COL1: 2013-07-15

The year must be from 1 to 9999. A negative year (BC in PostgreSQL) is a ``22007`` error.

make_interval
^^^^^^^^^^^^^

.. code-block:: text

  make_interval([years int [, months int [, weeks int [, days int [, hours int [, mins int [, secs double precision]]]]]]]) → interval

Builds an interval from years, months, weeks, days, hours, minutes and seconds.

No equivalent.

make_time
^^^^^^^^^

Builds a time from an hour, minute and second.

.. code-block:: sql

  -- make_time(hour int, min int, sec double precision) → time
  VALUES MAKE_TIME(/*hour*/, /*min*/, /*sec*/);
  -- make_time(8, 15, 23)
  VALUES MAKE_TIME(8, 15, 23);
  -- COL1: 08:15:23.000000

The result is a ``TIME(6)``, so it's printed with 6 decimal places. PostgreSQL allows ``make_time(24, 0, 0)``, which is a ``22007`` error in vsql.

make_timestamp
^^^^^^^^^^^^^^

Builds a timestamp from a year, month, day, hour, minute and second.

.. code-block:: sql

  -- make_timestamp(year int, month int, mday int, hour int, min int, sec double precision) → timestamp
  VALUES MAKE_TIMESTAMP(/*year*/, /*month*/, /*mday*/, /*hour*/, /*min*/, /*sec*/);
  -- make_timestamp(2013, 7, 15, 8, 15, 23.5)
  VALUES MAKE_TIMESTAMP(2013, 7, 15, 8, 15, 23.5);
  -- COL1: 2013-07-15T08:15:23.500000

The result is a ``TIMESTAMP(6)``. A negative (BC) year is a ``22007`` error.

make_timestamptz
^^^^^^^^^^^^^^^^

Builds a timestamp with time zone from a year, month, day, hour, minute, second and time zone.

.. code-block:: sql

  -- make_timestamptz(year int, month int, mday int, hour int, min int, sec double precision [, timezone text]) → timestamp with time zone
  VALUES MAKE_TIMESTAMPTZ(/*year*/, /*month*/, /*mday*/, /*hour*/, /*min*/, /*sec*/, /*timezone*/);
  -- make_timestamptz(2013, 7, 15, 8, 15, 23.5, '-08:00')
  VALUES MAKE_TIMESTAMPTZ(2013, 7, 15, 8, 15, 23.5, '-08:00');
  -- COL1: 2013-07-15T08:15:23.500000-0800

The time zone must be an offset such as ``'-08:00'``. Names such as ``'America/New_York'`` have no equivalent. Without a time zone, both use the time zone of the session. PostgreSQL prints the result in the time zone of the session (``2013-07-15 16:15:23.5+00`` in UTC), vsql keeps the offset it was given.

now
^^^

Returns the time the current transaction started.

.. code-block:: sql

  -- now() → timestamp with time zone
  VALUES CURRENT_TIMESTAMP;
  -- now() > '2020-01-01'
  VALUES CURRENT_TIMESTAMP > TIMESTAMP '2020-01-01 00:00:00+00:00';
  -- COL1: TRUE

vsql's ``CURRENT_TIMESTAMP`` is the time the statement started. vsql's ``NOW()`` is a different function that reads the clock each time, like ``clock_timestamp()``.

pg_sleep
^^^^^^^^

.. code-block:: text

  pg_sleep(double precision) → void

Waits for a number of seconds.

No equivalent.

pg_sleep_for
^^^^^^^^^^^^

.. code-block:: text

  pg_sleep_for(interval) → void

Waits for an interval.

No equivalent.

pg_sleep_until
^^^^^^^^^^^^^^

.. code-block:: text

  pg_sleep_until(timestamp with time zone) → void

Waits until a time.

No equivalent.

statement_timestamp
^^^^^^^^^^^^^^^^^^^

Returns the time the current statement started.

.. code-block:: sql

  -- statement_timestamp() → timestamp with time zone
  VALUES CURRENT_TIMESTAMP;
  -- statement_timestamp() > '2020-01-01'
  VALUES CURRENT_TIMESTAMP > TIMESTAMP '2020-01-01 00:00:00+00:00';
  -- COL1: TRUE

timeofday
^^^^^^^^^

Returns the time now as a string, read from the clock each time it's called.

.. code-block:: sql

  -- timeofday() → text
  VALUES NOW();
  -- timeofday() IS NOT NULL
  VALUES NOW() IS NOT NULL;
  -- COL1: TRUE

``NOW()`` returns a ``TIMESTAMP WITH TIME ZONE`` rather than a string.

timezone
^^^^^^^^

.. code-block:: text

  timezone(zone text, timestamp) → timestamp with time zone
  timezone(zone text, time) → time with time zone

Converts a timestamp or time to another time zone, the same as AT TIME ZONE. No equivalent.

.. code-block:: sql

  -- timezone(timestamp) → timestamp with time zone
  VALUES /*timestamp*/ AT LOCAL;
  -- timezone(timestamptz '2022-07-04 12:00:00+00') = timestamptz '2022-07-04 12:00:00+00'
  VALUES (TIMESTAMP '2022-07-04 12:00:00+00:00' AT LOCAL) = TIMESTAMP '2022-07-04 12:00:00+00:00';
  -- COL1: TRUE

With one argument, it converts to the time zone of the session, which is ``AT LOCAL``: the same instant, shown in the session's time zone. PostgreSQL returns a ``timestamp`` without a time zone for a ``timestamptz``, and the other way around. ``AT LOCAL`` always gives a ``TIMESTAMP WITH TIME ZONE`` (or ``TIME WITH TIME ZONE``), and a value without a time zone just gets the session's.

transaction_timestamp
^^^^^^^^^^^^^^^^^^^^^

Returns the time the current transaction started.

.. code-block:: sql

  -- transaction_timestamp() → timestamp with time zone
  VALUES CURRENT_TIMESTAMP;
  -- transaction_timestamp() > '2020-01-01'
  VALUES CURRENT_TIMESTAMP > TIMESTAMP '2020-01-01 00:00:00+00:00';
  -- COL1: TRUE

vsql's ``CURRENT_TIMESTAMP`` is the time the statement started, so it's only the same in the first statement of a transaction.

Enum Support Functions
----------------------

vsql has no enum types.

enum_first
^^^^^^^^^^

.. code-block:: text

  enum_first(anyenum) → anyenum

Returns the first value of an enum type.

No equivalent.

enum_last
^^^^^^^^^

.. code-block:: text

  enum_last(anyenum) → anyenum

Returns the last value of an enum type.

No equivalent.

enum_range
^^^^^^^^^^

.. code-block:: text

  enum_range(anyenum [, anyenum]) → anyarray

Returns the values of an enum type, or the ones between two values, as an array.

No equivalent.

Geometric Functions
-------------------

vsql has no geometric types. A point can be kept as two ``DOUBLE PRECISION``
columns, and calculated on with the mathematical functions, such as
``SQRT(POWER(x2 - x1, 2) + POWER(y2 - y1, 2))`` for a distance.

area
^^^^

.. code-block:: text

  area(geometric_type) → double precision

Returns the area of a box, circle or closed path.

No equivalent.

bound_box
^^^^^^^^^

.. code-block:: text

  bound_box(box, box) → box

Returns the smallest box that holds two boxes.

No equivalent.

box
^^^

.. code-block:: text

  box(circle) → box
  box(point [, point]) → box
  box(polygon) → box

Builds a box from a circle, one or two points, or a polygon.

No equivalent.

center
^^^^^^

.. code-block:: text

  center(geometric_type) → point

Returns the center point of a shape.

No equivalent.

circle
^^^^^^

.. code-block:: text

  circle(box) → circle
  circle(point, double precision) → circle
  circle(polygon) → circle

Builds a circle from a box, a center and radius, or a polygon.

No equivalent.

diagonal
^^^^^^^^

.. code-block:: text

  diagonal(box) → lseg

Returns the diagonal of a box as a line segment.

No equivalent.

diameter
^^^^^^^^

.. code-block:: text

  diameter(circle) → double precision

Returns the diameter of a circle.

No equivalent.

height
^^^^^^

.. code-block:: text

  height(box) → double precision

Returns the vertical size of a box.

No equivalent.

isclosed
^^^^^^^^

.. code-block:: text

  isclosed(path) → boolean

Tests if a path is closed.

No equivalent.

isopen
^^^^^^

.. code-block:: text

  isopen(path) → boolean

Tests if a path is open.

No equivalent.

line
^^^^

.. code-block:: text

  line(point, point) → line

Builds the infinite line through two points.

No equivalent.

lseg
^^^^

.. code-block:: text

  lseg(box) → lseg
  lseg(point, point) → lseg

Builds a line segment from the diagonal of a box or from two points.

No equivalent.

npoints
^^^^^^^

.. code-block:: text

  npoints(geometric_type) → integer

Returns the number of points of a path or polygon.

No equivalent.

path
^^^^

.. code-block:: text

  path(polygon) → path

Converts a polygon to a closed path.

No equivalent.

pclose
^^^^^^

.. code-block:: text

  pclose(path) → path

Converts a path to a closed one.

No equivalent.

point
^^^^^

.. code-block:: text

  point(double precision, double precision) → point
  point(geometric_type) → point

Builds a point from two coordinates, or returns the center of a shape.

No equivalent.

polygon
^^^^^^^

.. code-block:: text

  polygon(box) → polygon
  polygon([integer,] circle) → polygon
  polygon(path) → polygon

Builds a polygon from a box, a circle (with a number of points) or a closed path.

No equivalent.

popen
^^^^^

.. code-block:: text

  popen(path) → path

Converts a path to an open one.

No equivalent.

radius
^^^^^^

.. code-block:: text

  radius(circle) → double precision

Returns the radius of a circle.

No equivalent.

slope
^^^^^

.. code-block:: text

  slope(point, point) → double precision

Returns the slope of the line through two points.

No equivalent.

width
^^^^^

.. code-block:: text

  width(box) → double precision

Returns the horizontal size of a box.

No equivalent.

Network Address Functions
-------------------------

vsql has no ``inet``, ``cidr`` or ``macaddr`` types. ``trunc(macaddr)`` is
with ``trunc`` in `Mathematical Functions`_.

abbrev
^^^^^^

.. code-block:: text

  abbrev(inet) → text
  abbrev(cidr) → text

Returns the short form of a network address as text.

No equivalent.

broadcast
^^^^^^^^^

.. code-block:: text

  broadcast(inet) → inet

Returns the broadcast address of a network.

No equivalent.

family
^^^^^^

.. code-block:: text

  family(inet) → integer

Returns 4 or 6 for an IPv4 or IPv6 address.

No equivalent.

host
^^^^

.. code-block:: text

  host(inet) → text

Returns the IP address as text, without the netmask.

No equivalent.

hostmask
^^^^^^^^

.. code-block:: text

  hostmask(inet) → inet

Returns the host mask of a network.

No equivalent.

inet_merge
^^^^^^^^^^

.. code-block:: text

  inet_merge(inet, inet) → cidr

Returns the smallest network that holds both addresses.

No equivalent.

inet_same_family
^^^^^^^^^^^^^^^^

.. code-block:: text

  inet_same_family(inet, inet) → boolean

Tests if two addresses are both IPv4 or both IPv6.

No equivalent.

macaddr8_set7bit
^^^^^^^^^^^^^^^^

.. code-block:: text

  macaddr8_set7bit(macaddr8) → macaddr8

Sets the 7th bit of an 8-byte MAC address, to make a modified EUI-64 for an IPv6 address.

No equivalent.

masklen
^^^^^^^

.. code-block:: text

  masklen(inet) → integer

Returns the length of the netmask in bits.

No equivalent.

netmask
^^^^^^^

.. code-block:: text

  netmask(inet) → inet

Returns the netmask of a network.

No equivalent.

network
^^^^^^^

.. code-block:: text

  network(inet) → cidr

Returns the network part of an address.

No equivalent.

set_masklen
^^^^^^^^^^^

.. code-block:: text

  set_masklen(inet, integer) → inet
  set_masklen(cidr, integer) → cidr

Returns an address with a different netmask length.

No equivalent.

text
^^^^

.. code-block:: text

  text(inet) → text

Returns the IP address and netmask length as text.

No equivalent.

Text Search Functions
---------------------

vsql has no full text search, nor the ``tsvector`` and ``tsquery`` types.
``LIKE``, ``ILIKE`` and ``POSITION`` can search for a word in a string.

array_to_tsvector
^^^^^^^^^^^^^^^^^

.. code-block:: text

  array_to_tsvector(text[]) → tsvector

Converts an array of lexemes to a tsvector.

No equivalent.

get_current_ts_config
^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  get_current_ts_config() → regconfig

Returns the default text search configuration.

No equivalent.

json_to_tsvector
^^^^^^^^^^^^^^^^

.. code-block:: text

  json_to_tsvector([config regconfig,] document json, filter jsonb) → tsvector

Reduces the chosen kinds of values in a JSON document to a tsvector.

No equivalent.

jsonb_to_tsvector
^^^^^^^^^^^^^^^^^

.. code-block:: text

  jsonb_to_tsvector([config regconfig,] document jsonb, filter jsonb) → tsvector

Reduces the chosen kinds of values in a jsonb document to a tsvector.

No equivalent.

numnode
^^^^^^^

.. code-block:: text

  numnode(tsquery) → integer

Counts the lexemes and operators in a tsquery.

No equivalent.

phraseto_tsquery
^^^^^^^^^^^^^^^^

.. code-block:: text

  phraseto_tsquery([config regconfig,] query text) → tsquery

Converts text to a tsquery that matches its words as a phrase.

No equivalent.

plainto_tsquery
^^^^^^^^^^^^^^^

.. code-block:: text

  plainto_tsquery([config regconfig,] query text) → tsquery

Converts text to a tsquery that matches all of its words.

No equivalent.

querytree
^^^^^^^^^

.. code-block:: text

  querytree(tsquery) → text

Returns the part of a tsquery that can use an index.

No equivalent.

setweight
^^^^^^^^^

.. code-block:: text

  setweight(vector tsvector, weight "char" [, lexemes text[]]) → tsvector

Sets the weight of the lexemes (or some of them) in a tsvector.

No equivalent.

strip
^^^^^

.. code-block:: text

  strip(tsvector) → tsvector

Removes the positions and weights from a tsvector.

No equivalent.

to_tsquery
^^^^^^^^^^

.. code-block:: text

  to_tsquery([config regconfig,] query text) → tsquery

Converts a query with operators to a tsquery.

No equivalent.

to_tsvector
^^^^^^^^^^^

.. code-block:: text

  to_tsvector([config regconfig,] document text) → tsvector
  to_tsvector([config regconfig,] document json) → tsvector
  to_tsvector([config regconfig,] document jsonb) → tsvector

Converts a document to a tsvector of normalized lexemes.

No equivalent.

ts_debug
^^^^^^^^

.. code-block:: text

  ts_debug([config regconfig,] document text) → setof record

Shows how each token of a document is parsed and normalized.

No equivalent.

ts_delete
^^^^^^^^^

.. code-block:: text

  ts_delete(vector tsvector, lexeme text) → tsvector
  ts_delete(vector tsvector, lexemes text[]) → tsvector

Removes lexemes from a tsvector.

No equivalent.

ts_filter
^^^^^^^^^

.. code-block:: text

  ts_filter(vector tsvector, weights "char"[]) → tsvector

Keeps only the lexemes with the given weights.

No equivalent.

ts_headline
^^^^^^^^^^^

.. code-block:: text

  ts_headline([config regconfig,] document text, query tsquery [, options text]) → text

Returns an excerpt of a document with the words of a query highlighted.

No equivalent.

ts_lexize
^^^^^^^^^

.. code-block:: text

  ts_lexize(dict regdictionary, token text) → text[]

Returns the lexemes a dictionary gives for a token.

No equivalent.

ts_parse
^^^^^^^^

.. code-block:: text

  ts_parse(parser_name text, txt text) → setof record
  ts_parse(parser_oid oid, txt text) → setof record

Splits a document into tokens with a parser.

No equivalent.

ts_rank
^^^^^^^

.. code-block:: text

  ts_rank([weights real[],] vector tsvector, query tsquery [, normalization integer]) → real

Ranks how well a document matches a query, by how often its lexemes appear.

No equivalent.

ts_rank_cd
^^^^^^^^^^

.. code-block:: text

  ts_rank_cd([weights real[],] vector tsvector, query tsquery [, normalization integer]) → real

Ranks how well a document matches a query, by how close together its lexemes are.

No equivalent.

ts_rewrite
^^^^^^^^^^

.. code-block:: text

  ts_rewrite(query tsquery, target tsquery, substitute tsquery) → tsquery
  ts_rewrite(query tsquery, select text) → tsquery

Replaces parts of a tsquery with others.

No equivalent.

ts_stat
^^^^^^^

.. code-block:: text

  ts_stat(query text [, weights text]) → setof record

Returns statistics about the lexemes of the tsvectors that a query returns.

No equivalent.

ts_token_type
^^^^^^^^^^^^^

.. code-block:: text

  ts_token_type(parser_name text) → setof record
  ts_token_type(parser_oid oid) → setof record

Lists the kinds of tokens a parser knows.

No equivalent.

tsquery_phrase
^^^^^^^^^^^^^^

.. code-block:: text

  tsquery_phrase(query1 tsquery, query2 tsquery [, distance integer]) → tsquery

Builds a tsquery that matches one query followed by another.

No equivalent.

tsvector_to_array
^^^^^^^^^^^^^^^^^

.. code-block:: text

  tsvector_to_array(tsvector) → text[]

Converts a tsvector to an array of its lexemes.

No equivalent.

UUID Functions
--------------

vsql has no ``uuid`` type.

gen_random_uuid
^^^^^^^^^^^^^^^

.. code-block:: text

  gen_random_uuid() → uuid

Returns a random (version 4) UUID.

No equivalent.

uuid_extract_timestamp
^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  uuid_extract_timestamp(uuid) → timestamp with time zone

Returns the time a version 1 or 7 UUID was made.

No equivalent.

uuid_extract_version
^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  uuid_extract_version(uuid) → smallint

Returns the version of a UUID.

No equivalent.

uuidv4
^^^^^^

.. code-block:: text

  uuidv4() → uuid

Returns a random (version 4) UUID, the same as gen_random_uuid.

No equivalent.

uuidv7
^^^^^^

.. code-block:: text

  uuidv7([shift interval]) → uuid

Returns a UUID made from the current time (version 7), so they sort in the order they were made.

No equivalent.

XML Functions
-------------

vsql has no ``xml`` type.

cursor_to_xml
^^^^^^^^^^^^^

.. code-block:: text

  cursor_to_xml(cursor refcursor, count int, nulls boolean, tableforest boolean, targetns text) → xml

Returns the next rows of a cursor as XML.

No equivalent.

cursor_to_xmlschema
^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  cursor_to_xmlschema(cursor refcursor, nulls boolean, tableforest boolean, targetns text) → xml

Returns an XML schema of the rows of a cursor.

No equivalent.

database_to_xml
^^^^^^^^^^^^^^^

.. code-block:: text

  database_to_xml(nulls boolean, tableforest boolean, targetns text) → xml

Returns the tables of the current database as XML.

No equivalent.

database_to_xml_and_xmlschema
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  database_to_xml_and_xmlschema(nulls boolean, tableforest boolean, targetns text) → xml

Returns the tables of the current database as XML, with its XML schema.

No equivalent.

database_to_xmlschema
^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  database_to_xmlschema(nulls boolean, tableforest boolean, targetns text) → xml

Returns an XML schema of the tables of the current database.

No equivalent.

query_to_xml
^^^^^^^^^^^^

.. code-block:: text

  query_to_xml(query text, nulls boolean, tableforest boolean, targetns text) → xml

Returns the result of a query as XML.

No equivalent.

query_to_xml_and_xmlschema
^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  query_to_xml_and_xmlschema(query text, nulls boolean, tableforest boolean, targetns text) → xml

Returns the result of a query as XML, with its XML schema.

No equivalent.

query_to_xmlschema
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  query_to_xmlschema(query text, nulls boolean, tableforest boolean, targetns text) → xml

Returns an XML schema of the result of a query.

No equivalent.

schema_to_xml
^^^^^^^^^^^^^

.. code-block:: text

  schema_to_xml(schema name, nulls boolean, tableforest boolean, targetns text) → xml

Returns the tables of a schema as XML.

No equivalent.

schema_to_xml_and_xmlschema
^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  schema_to_xml_and_xmlschema(schema name, nulls boolean, tableforest boolean, targetns text) → xml

Returns the tables of a schema as XML, with its XML schema.

No equivalent.

schema_to_xmlschema
^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  schema_to_xmlschema(schema name, nulls boolean, tableforest boolean, targetns text) → xml

Returns an XML schema of the tables of a schema.

No equivalent.

table_to_xml
^^^^^^^^^^^^

.. code-block:: text

  table_to_xml(table regclass, nulls boolean, tableforest boolean, targetns text) → xml

Returns the rows of a table as XML.

No equivalent.

table_to_xml_and_xmlschema
^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  table_to_xml_and_xmlschema(table regclass, nulls boolean, tableforest boolean, targetns text) → xml

Returns the rows of a table as XML, with its XML schema.

No equivalent.

table_to_xmlschema
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  table_to_xmlschema(table regclass, nulls boolean, tableforest boolean, targetns text) → xml

Returns an XML schema of a table.

No equivalent.

websearch_to_tsquery
^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  websearch_to_tsquery([config regconfig,] query text) → tsquery

Converts a query written like one for a web search engine (with quotes, or and -) to a tsquery.

No equivalent.

xml_is_well_formed
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  xml_is_well_formed(text) → boolean

Tests if a string is well-formed XML, as a document or content depending on the xmloption setting.

No equivalent.

xml_is_well_formed_content
^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  xml_is_well_formed_content(text) → boolean

Tests if a string is well-formed XML content.

No equivalent.

xml_is_well_formed_document
^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  xml_is_well_formed_document(text) → boolean

Tests if a string is a well-formed XML document.

No equivalent.

xmlcomment
^^^^^^^^^^

.. code-block:: text

  xmlcomment(text) → xml

Builds an XML comment.

No equivalent.

xmlconcat
^^^^^^^^^

.. code-block:: text

  xmlconcat(xml [, ...]) → xml

Joins XML values together.

No equivalent.

xmlelement
^^^^^^^^^^

.. code-block:: text

  xmlelement(NAME name [, XMLATTRIBUTES(value [AS attname] [, ...])] [, content [, ...]]) → xml

Builds an XML element with attributes and content.

No equivalent.

XMLEXISTS
^^^^^^^^^

.. code-block:: text

  XMLEXISTS(text PASSING [BY {REF | VALUE}] xml [BY {REF | VALUE}]) → boolean

Tests if an XPath expression matches anything in an XML value.

No equivalent.

xmlforest
^^^^^^^^^

.. code-block:: text

  xmlforest(content [AS name] [, ...]) → xml

Builds a sequence of XML elements, one for each value.

No equivalent.

XMLPARSE
^^^^^^^^

.. code-block:: text

  XMLPARSE({DOCUMENT | CONTENT} value) → xml

Converts a string to an XML document or content.

No equivalent.

xmlpi
^^^^^

.. code-block:: text

  xmlpi(NAME name [, content]) → xml

Builds an XML processing instruction.

No equivalent.

xmlroot
^^^^^^^

.. code-block:: text

  xmlroot(xml, VERSION {text | NO VALUE} [, STANDALONE {YES | NO | NO VALUE}]) → xml

Changes the version and standalone properties of the root of an XML value.

No equivalent.

xmlserialize
^^^^^^^^^^^^

.. code-block:: text

  XMLSERIALIZE({DOCUMENT | CONTENT} value AS type [[NO] INDENT]) → type

Converts an XML value to a string.

No equivalent.

XMLTABLE
^^^^^^^^

.. code-block:: text

  XMLTABLE([XMLNAMESPACES(...),] row_expression PASSING document_expression COLUMNS name type [PATH column_expression] [DEFAULT default_expression] [NOT NULL | NULL] [, ...]) → setof record

Turns the nodes of an XML document into rows and columns.

No equivalent.

xmltext
^^^^^^^

.. code-block:: text

  xmltext(text) → xml

Builds an XML text node from a string, escaping its special characters.

No equivalent.

xpath
^^^^^

.. code-block:: text

  xpath(xpath text, xml xml [, nsarray text[]]) → xml[]

Returns the nodes of an XML value that an XPath expression matches, as an array.

No equivalent.

xpath_exists
^^^^^^^^^^^^

.. code-block:: text

  xpath_exists(xpath text, xml xml [, nsarray text[]]) → boolean

Tests if an XPath expression matches anything in an XML value.

No equivalent.

JSON Functions
--------------

vsql has no ``json`` or ``jsonb`` types, nor the SQL/JSON functions.

array_to_json
^^^^^^^^^^^^^

.. code-block:: text

  array_to_json(anyarray [, boolean]) → json

Converts an array to a JSON array, optionally with line breaks.

No equivalent.

json
^^^^

.. code-block:: text

  json(expression [FORMAT JSON [ENCODING UTF8]] [{WITH | WITHOUT} UNIQUE [KEYS]]) → json

Converts a string to a JSON value, optionally checking that keys are unique.

No equivalent.

json_array
^^^^^^^^^^

.. code-block:: text

  json_array([{value_expression [FORMAT JSON]} [, ...]] [{NULL | ABSENT} ON NULL] [RETURNING data_type]) → json

Builds a JSON array from values or from the rows of a query.

No equivalent.

json_array_elements
^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  json_array_elements(json) → setof json

Returns a row for each element of a JSON array.

No equivalent.

json_array_elements_text
^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  json_array_elements_text(json) → setof text

Returns a row for each element of a JSON array, as text.

No equivalent.

json_array_length
^^^^^^^^^^^^^^^^^

.. code-block:: text

  json_array_length(json) → integer

Returns the number of elements of a JSON array.

No equivalent.

json_build_array
^^^^^^^^^^^^^^^^

.. code-block:: text

  json_build_array(VARIADIC "any") → json

Builds a JSON array from its arguments.

No equivalent.

json_build_object
^^^^^^^^^^^^^^^^^

.. code-block:: text

  json_build_object(VARIADIC "any") → json

Builds a JSON object from alternating keys and values.

No equivalent.

json_each
^^^^^^^^^

.. code-block:: text

  json_each(json) → setof record(key text, value json)

Returns a row for each key and value of a JSON object.

No equivalent.

json_each_text
^^^^^^^^^^^^^^

.. code-block:: text

  json_each_text(json) → setof record(key text, value text)

Returns a row for each key and value (as text) of a JSON object.

No equivalent.

JSON_EXISTS
^^^^^^^^^^^

.. code-block:: text

  JSON_EXISTS(context_item, path_expression [PASSING {value AS varname} [, ...]] [{TRUE | FALSE | UNKNOWN | ERROR} ON ERROR]) → boolean

Tests if an SQL/JSON path returns anything for a JSON value.

No equivalent.

json_extract_path
^^^^^^^^^^^^^^^^^

.. code-block:: text

  json_extract_path(from_json json, VARIADIC path_elems text[]) → json

Returns the JSON value at a path of keys and indexes.

No equivalent.

json_extract_path_text
^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  json_extract_path_text(from_json json, VARIADIC path_elems text[]) → text

Returns the JSON value at a path of keys and indexes, as text.

No equivalent.

json_object
^^^^^^^^^^^

.. code-block:: text

  json_object([{key_expression {VALUE | ':'} value_expression [FORMAT JSON]} [, ...]] [{NULL | ABSENT} ON NULL] [{WITH | WITHOUT} UNIQUE [KEYS]] [RETURNING data_type]) → json
  json_object(text[]) → json
  json_object(keys text[], values text[]) → json

Builds a JSON object from keys and values, or from a text array of them.

No equivalent.

json_object_keys
^^^^^^^^^^^^^^^^

.. code-block:: text

  json_object_keys(json) → setof text

Returns a row for each key of a JSON object.

No equivalent.

json_populate_record
^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  json_populate_record(base anyelement, from_json json) → anyelement

Fills the columns of a row type from the keys of a JSON object.

No equivalent.

json_populate_recordset
^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  json_populate_recordset(base anyelement, from_json json) → setof anyelement

Fills a row of a row type from each object of a JSON array.

No equivalent.

JSON_QUERY
^^^^^^^^^^

.. code-block:: text

  JSON_QUERY(context_item, path_expression [PASSING {value AS varname} [, ...]] [RETURNING data_type [FORMAT JSON]] [wrapper] [quotes] [behavior ON EMPTY] [behavior ON ERROR]) → jsonb

Returns the JSON that an SQL/JSON path returns for a JSON value.

No equivalent.

json_scalar
^^^^^^^^^^^

.. code-block:: text

  json_scalar(expression) → json

Converts an SQL value to a JSON scalar.

No equivalent.

json_serialize
^^^^^^^^^^^^^^

.. code-block:: text

  json_serialize(expression [FORMAT JSON [ENCODING UTF8]] [RETURNING data_type [FORMAT JSON [ENCODING UTF8]]]) → text

Converts a JSON value to a string or bytes.

No equivalent.

json_strip_nulls
^^^^^^^^^^^^^^^^

.. code-block:: text

  json_strip_nulls(target json [, strip_in_arrays boolean]) → json

Removes the object fields (and optionally array elements) that are null from a JSON value.

No equivalent.

JSON_TABLE
^^^^^^^^^^

.. code-block:: text

  JSON_TABLE(context_item, path_expression [AS json_path_name] [PASSING {value AS varname} [, ...]] COLUMNS (json_table_column [, ...]) [{ERROR | EMPTY [ARRAY]} ON ERROR]) → setof record

Turns the items an SQL/JSON path returns for a JSON value into rows and columns.

No equivalent.

json_to_record
^^^^^^^^^^^^^^

.. code-block:: text

  json_to_record(json) → record

Converts a JSON object to a row, with the columns given in the AS clause.

No equivalent.

json_to_recordset
^^^^^^^^^^^^^^^^^

.. code-block:: text

  json_to_recordset(json) → setof record

Converts each object of a JSON array to a row, with the columns given in the AS clause.

No equivalent.

json_typeof
^^^^^^^^^^^

.. code-block:: text

  json_typeof(json) → text

Returns the type of the top-level JSON value, such as object, array or string.

No equivalent.

JSON_VALUE
^^^^^^^^^^

.. code-block:: text

  JSON_VALUE(context_item, path_expression [PASSING {value AS varname} [, ...]] [RETURNING data_type] [behavior ON EMPTY] [behavior ON ERROR]) → text

Returns the scalar that an SQL/JSON path returns for a JSON value, as an SQL value.

No equivalent.

jsonb_array_elements
^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  jsonb_array_elements(jsonb) → setof jsonb

Returns a row for each element of a jsonb array.

No equivalent.

jsonb_array_elements_text
^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  jsonb_array_elements_text(jsonb) → setof text

Returns a row for each element of a jsonb array, as text.

No equivalent.

jsonb_array_length
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  jsonb_array_length(jsonb) → integer

Returns the number of elements of a jsonb array.

No equivalent.

jsonb_build_array
^^^^^^^^^^^^^^^^^

.. code-block:: text

  jsonb_build_array(VARIADIC "any") → jsonb

Builds a jsonb array from its arguments.

No equivalent.

jsonb_build_object
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  jsonb_build_object(VARIADIC "any") → jsonb

Builds a jsonb object from alternating keys and values.

No equivalent.

jsonb_each
^^^^^^^^^^

.. code-block:: text

  jsonb_each(jsonb) → setof record(key text, value jsonb)

Returns a row for each key and value of a jsonb object.

No equivalent.

jsonb_each_text
^^^^^^^^^^^^^^^

.. code-block:: text

  jsonb_each_text(jsonb) → setof record(key text, value text)

Returns a row for each key and value (as text) of a jsonb object.

No equivalent.

jsonb_extract_path
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  jsonb_extract_path(from_json jsonb, VARIADIC path_elems text[]) → jsonb

Returns the jsonb value at a path of keys and indexes.

No equivalent.

jsonb_extract_path_text
^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  jsonb_extract_path_text(from_json jsonb, VARIADIC path_elems text[]) → text

Returns the jsonb value at a path of keys and indexes, as text.

No equivalent.

jsonb_insert
^^^^^^^^^^^^

.. code-block:: text

  jsonb_insert(jsonb_in jsonb, path text[], replacement jsonb [, insert_after boolean]) → jsonb

Inserts a value at a path of a jsonb value, before or after an array element.

No equivalent.

jsonb_object
^^^^^^^^^^^^

.. code-block:: text

  jsonb_object(text[]) → jsonb
  jsonb_object(keys text[], values text[]) → jsonb

Builds a jsonb object from a text array of keys and values.

No equivalent.

jsonb_object_keys
^^^^^^^^^^^^^^^^^

.. code-block:: text

  jsonb_object_keys(jsonb) → setof text

Returns a row for each key of a jsonb object.

No equivalent.

jsonb_path_exists
^^^^^^^^^^^^^^^^^

.. code-block:: text

  jsonb_path_exists(target jsonb, path jsonpath [, vars jsonb [, silent boolean]]) → boolean

Tests if a JSON path returns anything for a jsonb value.

No equivalent.

jsonb_path_exists_tz
^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  jsonb_path_exists_tz(target jsonb, path jsonpath [, vars jsonb [, silent boolean]]) → boolean

Like jsonb_path_exists, but comparisons of dates and times can use the time zone setting.

No equivalent.

jsonb_path_match
^^^^^^^^^^^^^^^^

.. code-block:: text

  jsonb_path_match(target jsonb, path jsonpath [, vars jsonb [, silent boolean]]) → boolean

Returns the result of a JSON path predicate for a jsonb value.

No equivalent.

jsonb_path_match_tz
^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  jsonb_path_match_tz(target jsonb, path jsonpath [, vars jsonb [, silent boolean]]) → boolean

Like jsonb_path_match, but comparisons of dates and times can use the time zone setting.

No equivalent.

jsonb_path_query
^^^^^^^^^^^^^^^^

.. code-block:: text

  jsonb_path_query(target jsonb, path jsonpath [, vars jsonb [, silent boolean]]) → setof jsonb

Returns a row for each item a JSON path returns for a jsonb value.

No equivalent.

jsonb_path_query_array
^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  jsonb_path_query_array(target jsonb, path jsonpath [, vars jsonb [, silent boolean]]) → jsonb

Returns the items a JSON path returns for a jsonb value, as an array.

No equivalent.

jsonb_path_query_array_tz
^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  jsonb_path_query_array_tz(target jsonb, path jsonpath [, vars jsonb [, silent boolean]]) → jsonb

Like jsonb_path_query_array, but comparisons of dates and times can use the time zone setting.

No equivalent.

jsonb_path_query_first
^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  jsonb_path_query_first(target jsonb, path jsonpath [, vars jsonb [, silent boolean]]) → jsonb

Returns the first item a JSON path returns for a jsonb value.

No equivalent.

jsonb_path_query_first_tz
^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  jsonb_path_query_first_tz(target jsonb, path jsonpath [, vars jsonb [, silent boolean]]) → jsonb

Like jsonb_path_query_first, but comparisons of dates and times can use the time zone setting.

No equivalent.

jsonb_path_query_tz
^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  jsonb_path_query_tz(target jsonb, path jsonpath [, vars jsonb [, silent boolean]]) → setof jsonb

Like jsonb_path_query, but comparisons of dates and times can use the time zone setting.

No equivalent.

jsonb_populate_record
^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  jsonb_populate_record(base anyelement, from_json jsonb) → anyelement

Fills the columns of a row type from the keys of a jsonb object.

No equivalent.

jsonb_populate_record_valid
^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  jsonb_populate_record_valid(base anyelement, from_json json) → boolean

Tests if jsonb_populate_record would succeed without an error.

No equivalent.

jsonb_populate_recordset
^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  jsonb_populate_recordset(base anyelement, from_json jsonb) → setof anyelement

Fills a row of a row type from each object of a jsonb array.

No equivalent.

jsonb_pretty
^^^^^^^^^^^^

.. code-block:: text

  jsonb_pretty(jsonb) → text

Formats a jsonb value as indented text.

No equivalent.

jsonb_set
^^^^^^^^^

.. code-block:: text

  jsonb_set(jsonb_in jsonb, path text[], replacement jsonb [, create_if_missing boolean]) → jsonb

Replaces (or adds) the value at a path of a jsonb value.

No equivalent.

jsonb_set_lax
^^^^^^^^^^^^^

.. code-block:: text

  jsonb_set_lax(jsonb_in jsonb, path text[], replacement jsonb [, create_if_missing boolean [, null_value_treatment text]]) → jsonb

Like jsonb_set, but with a choice of what a NULL replacement does.

No equivalent.

jsonb_strip_nulls
^^^^^^^^^^^^^^^^^

.. code-block:: text

  jsonb_strip_nulls(target jsonb [, strip_in_arrays boolean]) → jsonb

Removes the object fields (and optionally array elements) that are null from a jsonb value.

No equivalent.

jsonb_to_record
^^^^^^^^^^^^^^^

.. code-block:: text

  jsonb_to_record(jsonb) → record

Converts a jsonb object to a row, with the columns given in the AS clause.

No equivalent.

jsonb_to_recordset
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  jsonb_to_recordset(jsonb) → setof record

Converts each object of a jsonb array to a row, with the columns given in the AS clause.

No equivalent.

jsonb_typeof
^^^^^^^^^^^^

.. code-block:: text

  jsonb_typeof(jsonb) → text

Returns the type of the top-level jsonb value, such as object, array or string.

No equivalent.

row_to_json
^^^^^^^^^^^

.. code-block:: text

  row_to_json(record [, boolean]) → json

Converts a row to a JSON object, optionally with line breaks.

No equivalent.

to_json
^^^^^^^

.. code-block:: text

  to_json(anyelement) → json

Converts any value to JSON.

No equivalent.

to_jsonb
^^^^^^^^

.. code-block:: text

  to_jsonb(anyelement) → jsonb

Converts any value to jsonb.

No equivalent.

Sequence Manipulation Functions
-------------------------------

A sequence is created with :doc:`create-sequence` in both.

currval
^^^^^^^

.. code-block:: text

  currval(regclass) → bigint

Returns the value that nextval last returned for a sequence in this session.

No equivalent.

lastval
^^^^^^^

.. code-block:: text

  lastval() → bigint

Returns the value that nextval last returned in this session, for any sequence.

No equivalent.

nextval
^^^^^^^

Advances a sequence and returns its new value.

.. code-block:: sql

  -- nextval(regclass) → bigint
  SELECT NEXT VALUE FOR /*regclass*/ FROM (VALUES 1) AS t;
  -- nextval('ids')
  SELECT NEXT VALUE FOR ids FROM (VALUES 1) AS t;
  -- COL1: 1

``NEXT VALUE FOR`` can't be used in a ``VALUES``, a ``WHERE`` or a few other places (see :doc:`create-sequence`).

setval
^^^^^^

Sets the value of a sequence, so that the next nextval returns the value after it, or the value itself when the third argument is false.

.. code-block:: sql

  -- setval(regclass, bigint) → bigint
  ALTER SEQUENCE /*regclass*/ RESTART WITH /*bigint + 1*/;
  -- setval('ids', 42)
  ALTER SEQUENCE ids RESTART WITH 43;
  -- msg: ALTER SEQUENCE 1

  -- setval(regclass, bigint, false) → bigint
  ALTER SEQUENCE /*regclass*/ RESTART WITH /*bigint*/;
  -- setval('ids', 42, false)
  ALTER SEQUENCE ids RESTART WITH 42;
  -- msg: ALTER SEQUENCE 1

``setval`` returns its second argument. ``RESTART WITH`` must be a literal number. The sequence must count up by 1 for the first form.

Conditional Expressions
-----------------------

COALESCE
^^^^^^^^

Returns the first of its arguments that isn't null.

.. code-block:: sql

  -- COALESCE(value [, ...])
  VALUES COALESCE(/*value*/, /*...*/);
  -- COALESCE(NULL, 2, 3)
  VALUES COALESCE(CAST(NULL AS INTEGER), 2, 3);
  -- COL1: 2

GREATEST
^^^^^^^^

Returns the largest of its arguments.

.. code-block:: sql

  -- GREATEST(value [, ...])
  VALUES GREATEST(/*value*/, /*...*/);
  -- GREATEST(1, 3, 2)
  VALUES GREATEST(1, 3, 2);
  -- COL1: 3

PostgreSQL skips ``NULL`` arguments (``GREATEST(1, NULL, 3)`` is 3), but in vsql any ``NULL`` argument makes the result ``NULL``. Use ``COALESCE`` on the arguments that may be ``NULL``.

LEAST
^^^^^

Returns the smallest of its arguments.

.. code-block:: sql

  -- LEAST(value [, ...])
  VALUES LEAST(/*value*/, /*...*/);
  -- LEAST(5, 2, 9)
  VALUES LEAST(5, 2, 9);
  -- COL1: 2

PostgreSQL skips ``NULL`` arguments (``LEAST(5, NULL, 2)`` is 2), but in vsql any ``NULL`` argument makes the result ``NULL``. Use ``COALESCE`` on the arguments that may be ``NULL``.

NULLIF
^^^^^^

Returns null if its two arguments are equal, otherwise the first one.

.. code-block:: sql

  -- NULLIF(value1, value2)
  VALUES NULLIF(/*value1*/, /*value2*/);
  -- NULLIF(5, 5)
  VALUES NULLIF(5, 5);
  -- COL1: NULL

Array Functions
---------------

vsql has no arrays.

array_append
^^^^^^^^^^^^

.. code-block:: text

  array_append(anycompatiblearray, anycompatible) → anycompatiblearray

Adds an element to the end of an array.

No equivalent.

array_cat
^^^^^^^^^

.. code-block:: text

  array_cat(anycompatiblearray, anycompatiblearray) → anycompatiblearray

Joins two arrays.

No equivalent.

array_dims
^^^^^^^^^^

.. code-block:: text

  array_dims(anyarray) → text

Returns the dimensions of an array as text.

No equivalent.

array_fill
^^^^^^^^^^

.. code-block:: text

  array_fill(anyelement, integer[] [, integer[]]) → anyarray

Builds an array of the given dimensions with every element set to a value.

No equivalent.

array_length
^^^^^^^^^^^^

.. code-block:: text

  array_length(anyarray, integer) → integer

Returns the length of a dimension of an array.

No equivalent.

array_lower
^^^^^^^^^^^

.. code-block:: text

  array_lower(anyarray, integer) → integer

Returns the lower bound of a dimension of an array.

No equivalent.

array_ndims
^^^^^^^^^^^

.. code-block:: text

  array_ndims(anyarray) → integer

Returns the number of dimensions of an array.

No equivalent.

array_position
^^^^^^^^^^^^^^

.. code-block:: text

  array_position(anycompatiblearray, anycompatible [, integer]) → integer

Returns the position of the first occurrence of a value in an array.

No equivalent.

array_positions
^^^^^^^^^^^^^^^

.. code-block:: text

  array_positions(anycompatiblearray, anycompatible) → integer[]

Returns the positions of every occurrence of a value in an array.

No equivalent.

array_prepend
^^^^^^^^^^^^^

.. code-block:: text

  array_prepend(anycompatible, anycompatiblearray) → anycompatiblearray

Adds an element to the start of an array.

No equivalent.

array_remove
^^^^^^^^^^^^

.. code-block:: text

  array_remove(anycompatiblearray, anycompatible) → anycompatiblearray

Removes every element equal to a value from an array.

No equivalent.

array_replace
^^^^^^^^^^^^^

.. code-block:: text

  array_replace(anycompatiblearray, anycompatible, anycompatible) → anycompatiblearray

Replaces every element equal to a value with another value.

No equivalent.

array_reverse
^^^^^^^^^^^^^

.. code-block:: text

  array_reverse(anyarray) → anyarray

Reverses the order of the elements of an array.

No equivalent.

array_sample
^^^^^^^^^^^^

.. code-block:: text

  array_sample(array anyarray, n integer) → anyarray

Returns n elements of an array chosen at random.

No equivalent.

array_shuffle
^^^^^^^^^^^^^

.. code-block:: text

  array_shuffle(anyarray) → anyarray

Returns the elements of an array in a random order.

No equivalent.

array_sort
^^^^^^^^^^

.. code-block:: text

  array_sort(array anyarray [, descending boolean [, nulls_first boolean]]) → anyarray

Sorts the elements of an array.

No equivalent.

array_to_string
^^^^^^^^^^^^^^^

.. code-block:: text

  array_to_string(array anyarray, delimiter text [, null_string text]) → text

Joins the elements of an array into a string with a delimiter.

No equivalent.

``LISTAGG`` (see string_agg) joins the values of a column.

array_upper
^^^^^^^^^^^

.. code-block:: text

  array_upper(anyarray, integer) → integer

Returns the upper bound of a dimension of an array.

No equivalent.

cardinality
^^^^^^^^^^^

.. code-block:: text

  cardinality(anyarray) → integer

Returns the total number of elements of an array.

No equivalent.

trim_array
^^^^^^^^^^

.. code-block:: text

  trim_array(array anyarray, n integer) → anyarray

Removes the last n elements of an array.

No equivalent.

unnest
^^^^^^

.. code-block:: text

  unnest(anyarray [, anyarray [, ...]]) → setof anyelement
  unnest(anymultirange) → setof anyrange
  unnest(tsvector) → setof record

Returns a row for each element of an array (or arrays, side by side), each range of a multirange, or each lexeme of a tsvector.

No equivalent.

Range/Multirange Functions
--------------------------

vsql has no range or multirange types. ``lower`` and ``upper`` are in
`String Functions`_, and ``unnest`` in `Array Functions`_.

isempty
^^^^^^^

.. code-block:: text

  isempty(anyrange) → boolean
  isempty(anymultirange) → boolean

Tests if a range or multirange is empty.

No equivalent.

lower_inc
^^^^^^^^^

.. code-block:: text

  lower_inc(anyrange) → boolean
  lower_inc(anymultirange) → boolean

Tests if the lower bound of a range is included in it.

No equivalent.

lower_inf
^^^^^^^^^

.. code-block:: text

  lower_inf(anyrange) → boolean
  lower_inf(anymultirange) → boolean

Tests if a range has no lower bound.

No equivalent.

multirange
^^^^^^^^^^

.. code-block:: text

  multirange(anyrange) → anymultirange

Builds a multirange that holds one range.

No equivalent.

range_merge
^^^^^^^^^^^

.. code-block:: text

  range_merge(anyrange, anyrange) → anyrange
  range_merge(anymultirange) → anyrange

Returns the smallest range that covers two ranges, or every range of a multirange.

No equivalent.

upper_inc
^^^^^^^^^

.. code-block:: text

  upper_inc(anyrange) → boolean
  upper_inc(anymultirange) → boolean

Tests if the upper bound of a range is included in it.

No equivalent.

upper_inf
^^^^^^^^^

.. code-block:: text

  upper_inf(anyrange) → boolean
  upper_inf(anymultirange) → boolean

Tests if a range has no upper bound.

No equivalent.

Aggregate Functions
-------------------

any_value
^^^^^^^^^

Returns any one of the values that aren't null.

.. code-block:: sql

  -- any_value(anyelement) → same as input type
  SELECT ANY_VALUE(/*anyelement*/) FROM /*table*/;
  -- SELECT any_value(sku) FROM products WHERE qty = 40
  SELECT ANY_VALUE(sku) FROM products WHERE qty = 40;
  -- COL1: B2

array_agg
^^^^^^^^^

.. code-block:: text

  array_agg(anynonarray ORDER BY input_sort_columns) → anyarray
  array_agg(anyarray ORDER BY input_sort_columns) → anyarray

Collects the values (including nulls) into an array.

No equivalent.

``LISTAGG`` (see string_agg) collects them into a string.

avg
^^^

Returns the average of the values that aren't null.

.. code-block:: sql

  -- avg(numeric_type) → numeric
  SELECT AVG(/*numeric_type*/) FROM /*table*/;
  -- SELECT avg(price) FROM products
  SELECT AVG(price) FROM products;
  -- COL1: 2.18

The average has the type of the column, so ``AVG`` of a ``DECIMAL(10, 2)`` is rounded to 2 decimal places (2.1875 is 2.18), and of an integer column it's an integer. Use ``AVG(CAST(price AS DOUBLE PRECISION))`` for more digits.

bit_and
^^^^^^^

.. code-block:: text

  bit_and(integral_type) → integral_type
  bit_and(bit) → bit

Returns the bitwise AND of the values that aren't null.

No equivalent.

bit_or
^^^^^^

.. code-block:: text

  bit_or(integral_type) → integral_type
  bit_or(bit) → bit

Returns the bitwise OR of the values that aren't null.

No equivalent.

bit_xor
^^^^^^^

.. code-block:: text

  bit_xor(integral_type) → integral_type
  bit_xor(bit) → bit

Returns the bitwise exclusive OR of the values that aren't null.

No equivalent.

bool_and
^^^^^^^^

Returns true if every value that isn't null is true.

.. code-block:: sql

  -- bool_and(boolean) → boolean
  SELECT EVERY(/*boolean*/) FROM /*table*/;
  -- SELECT bool_and(qty > 4) FROM products
  SELECT EVERY(qty > 4) FROM products;
  -- warning 01003: null value eliminated in set function
  -- COL1: TRUE

bool_or
^^^^^^^

Returns true if any value that isn't null is true.

.. code-block:: sql

  -- bool_or(boolean) → boolean
  SELECT SOME(/*boolean*/) FROM /*table*/;
  -- SELECT bool_or(qty > 30) FROM products
  SELECT SOME(qty > 30) FROM products;
  -- warning 01003: null value eliminated in set function
  -- COL1: TRUE

``ANY`` is the same as ``SOME``.

corr
^^^^

Returns the correlation coefficient of two sets of values.

.. code-block:: sql

  -- corr(Y double precision, X double precision) → double precision
  SELECT CORR(/*Y*/, /*X*/) FROM /*table*/;
  -- SELECT corr(price, qty) FROM products
  SELECT CORR(price, qty) FROM products;
  -- warning 01003: null value eliminated in set function
  -- COL1: -0.835766105671e0

count
^^^^^

Counts the rows, or the values that aren't null.

.. code-block:: sql

  -- count(*) → bigint
  SELECT COUNT(*) FROM /*table*/;
  -- SELECT count(*) FROM products
  SELECT COUNT(*) FROM products;
  -- COL1: 4

  -- count("any") → bigint
  SELECT COUNT(/*any*/) FROM /*table*/;
  -- SELECT count(qty) FROM products
  SELECT COUNT(qty) FROM products;
  -- warning 01003: null value eliminated in set function
  -- COL1: 3

vsql's ``COUNT`` returns an ``INTEGER``, PostgreSQL's a ``bigint``.

covar_pop
^^^^^^^^^

Returns the population covariance of two sets of values.

.. code-block:: sql

  -- covar_pop(Y double precision, X double precision) → double precision
  SELECT COVAR_POP(/*Y*/, /*X*/) FROM /*table*/;
  -- SELECT covar_pop(price, qty) FROM products
  SELECT COVAR_POP(price, qty) FROM products;
  -- warning 01003: null value eliminated in set function
  -- COL1: -20.138888888889e0

covar_samp
^^^^^^^^^^

Returns the sample covariance of two sets of values.

.. code-block:: sql

  -- covar_samp(Y double precision, X double precision) → double precision
  SELECT COVAR_SAMP(/*Y*/, /*X*/) FROM /*table*/;
  -- SELECT covar_samp(price, qty) FROM products
  SELECT COVAR_SAMP(price, qty) FROM products;
  -- warning 01003: null value eliminated in set function
  -- COL1: -30.208333333333e0

cume_dist
^^^^^^^^^

Returns the fraction of the rows that are before or equal to a hypothetical row with the given value, including the hypothetical row.

.. code-block:: sql

  -- cume_dist(args) WITHIN GROUP (ORDER BY sorted_args) → double precision
  SELECT CUME_DIST(/*args*/) WITHIN GROUP (ORDER BY /*sorted_args*/) FROM /*table*/;
  -- SELECT cume_dist(2.00) WITHIN GROUP (ORDER BY price) FROM products
  SELECT CUME_DIST(2.00) WITHIN GROUP (ORDER BY price) FROM products;
  -- COL1: 0.6e0

The window function ``cume_dist() OVER (ORDER BY price)`` has no equivalent.

dense_rank
^^^^^^^^^^

Returns the rank a hypothetical row with the given value would have, without gaps for ties.

.. code-block:: sql

  -- dense_rank(args) WITHIN GROUP (ORDER BY sorted_args) → bigint
  SELECT DENSE_RANK(/*args*/) WITHIN GROUP (ORDER BY /*sorted_args*/) FROM /*table*/;
  -- SELECT dense_rank(2.00) WITHIN GROUP (ORDER BY price) FROM products
  SELECT DENSE_RANK(2.00) WITHIN GROUP (ORDER BY price) FROM products;
  -- COL1: 3

The window function ``dense_rank() OVER (ORDER BY price)`` is ``(SELECT COUNT(DISTINCT q.price) FROM products q WHERE q.price <= p.price)`` in the select list of ``FROM products p``.

every
^^^^^

Returns true if every value that isn't null is true, the same as bool_and.

.. code-block:: sql

  -- every(boolean) → boolean
  SELECT EVERY(/*boolean*/) FROM /*table*/;
  -- SELECT every(qty > 4) FROM products
  SELECT EVERY(qty > 4) FROM products;
  -- warning 01003: null value eliminated in set function
  -- COL1: TRUE

GROUPING
^^^^^^^^

.. code-block:: text

  GROUPING(group_by_expression(s)) → integer

Returns a bit mask of which of the GROUP BY expressions aren't grouped in the current row of a grouping set.

No equivalent.

vsql has no ``GROUPING SETS``, ``ROLLUP`` or ``CUBE``.

json_agg
^^^^^^^^

.. code-block:: text

  json_agg(anyelement ORDER BY input_sort_columns) → json

Collects the values (including nulls) into a JSON array.

No equivalent.

json_agg_strict
^^^^^^^^^^^^^^^

.. code-block:: text

  json_agg_strict(anyelement ORDER BY input_sort_columns) → json

Collects the values that aren't null into a JSON array.

No equivalent.

json_arrayagg
^^^^^^^^^^^^^

.. code-block:: text

  json_arrayagg([value_expression] [ORDER BY sort_expression] [{NULL | ABSENT} ON NULL] [RETURNING data_type [FORMAT JSON [ENCODING UTF8]]]) → json

Collects the values into a JSON array, the SQL/JSON way.

No equivalent.

json_object_agg
^^^^^^^^^^^^^^^

.. code-block:: text

  json_object_agg(key "any", value "any" ORDER BY input_sort_columns) → json

Collects keys and values into a JSON object.

No equivalent.

json_object_agg_strict
^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  json_object_agg_strict(key "any", value "any") → json

Collects keys and values into a JSON object, skipping the null values.

No equivalent.

json_object_agg_unique
^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  json_object_agg_unique(key "any", value "any") → json

Collects keys and values into a JSON object, failing on a repeated key.

No equivalent.

json_object_agg_unique_strict
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  json_object_agg_unique_strict(key "any", value "any") → json

Collects keys and values into a JSON object, skipping the null values and failing on a repeated key.

No equivalent.

json_objectagg
^^^^^^^^^^^^^^

.. code-block:: text

  json_objectagg([{key_expression {VALUE | ':'} value_expression}] [{NULL | ABSENT} ON NULL] [{WITH | WITHOUT} UNIQUE [KEYS]] [RETURNING data_type [FORMAT JSON [ENCODING UTF8]]]) → json

Collects keys and values into a JSON object, the SQL/JSON way.

No equivalent.

jsonb_agg
^^^^^^^^^

.. code-block:: text

  jsonb_agg(anyelement ORDER BY input_sort_columns) → jsonb

Collects the values (including nulls) into a jsonb array.

No equivalent.

jsonb_agg_strict
^^^^^^^^^^^^^^^^

.. code-block:: text

  jsonb_agg_strict(anyelement ORDER BY input_sort_columns) → jsonb

Collects the values that aren't null into a jsonb array.

No equivalent.

jsonb_object_agg
^^^^^^^^^^^^^^^^

.. code-block:: text

  jsonb_object_agg(key "any", value "any" ORDER BY input_sort_columns) → jsonb

Collects keys and values into a jsonb object.

No equivalent.

jsonb_object_agg_strict
^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  jsonb_object_agg_strict(key "any", value "any") → jsonb

Collects keys and values into a jsonb object, skipping the null values.

No equivalent.

jsonb_object_agg_unique
^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  jsonb_object_agg_unique(key "any", value "any") → jsonb

Collects keys and values into a jsonb object, failing on a repeated key.

No equivalent.

jsonb_object_agg_unique_strict
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  jsonb_object_agg_unique_strict(key "any", value "any") → jsonb

Collects keys and values into a jsonb object, skipping the null values and failing on a repeated key.

No equivalent.

max
^^^

Returns the largest of the values that aren't null.

.. code-block:: sql

  -- max(see text) → same as input type
  SELECT MAX(/*value*/) FROM /*table*/;
  -- SELECT max(price) FROM products
  SELECT MAX(price) FROM products;
  -- COL1: 4.00

min
^^^

Returns the smallest of the values that aren't null.

.. code-block:: sql

  -- min(see text) → same as input type
  SELECT MIN(/*value*/) FROM /*table*/;
  -- SELECT min(price) FROM products
  SELECT MIN(price) FROM products;
  -- COL1: 0.25

mode
^^^^

Returns the most frequent value, the first in the sort order on a tie.

.. code-block:: sql

  -- mode() WITHIN GROUP (ORDER BY anyelement) → anyelement
  SELECT MODE() WITHIN GROUP (ORDER BY /*anyelement*/) FROM /*table*/;
  -- SELECT mode() WITHIN GROUP (ORDER BY v) FROM (VALUES (1), (2), (2), (3)) AS t (v)
  SELECT MODE() WITHIN GROUP (ORDER BY v) FROM (VALUES (1), (2), (2), (3)) AS t (v);
  -- COL1: 2

percent_rank
^^^^^^^^^^^^

Returns the relative rank (from 0 to 1) a hypothetical row with the given value would have.

.. code-block:: sql

  -- percent_rank(args) WITHIN GROUP (ORDER BY sorted_args) → double precision
  SELECT PERCENT_RANK(/*args*/) WITHIN GROUP (ORDER BY /*sorted_args*/) FROM /*table*/;
  -- SELECT percent_rank(2.00) WITHIN GROUP (ORDER BY price) FROM products
  SELECT PERCENT_RANK(2.00) WITHIN GROUP (ORDER BY price) FROM products;
  -- COL1: 0.5e0

The window function ``percent_rank() OVER (ORDER BY price)`` has no equivalent.

percentile_cont
^^^^^^^^^^^^^^^

Returns the value at a fraction of the sorted values, interpolating between the two nearest values.

.. code-block:: sql

  -- percentile_cont(fraction double precision) WITHIN GROUP (ORDER BY double precision) → double precision
  SELECT PERCENTILE_CONT(/*fraction*/) WITHIN GROUP (ORDER BY /*value*/) FROM /*table*/;
  -- SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY price) FROM products
  SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price) FROM products;
  -- COL1: 2.25e0

The form that takes an array of fractions has no equivalent.

percentile_disc
^^^^^^^^^^^^^^^

Returns the first of the sorted values whose position reaches a fraction of them.

.. code-block:: sql

  -- percentile_disc(fraction double precision) WITHIN GROUP (ORDER BY anyelement) → anyelement
  SELECT PERCENTILE_DISC(/*fraction*/) WITHIN GROUP (ORDER BY /*anyelement*/) FROM /*table*/;
  -- SELECT percentile_disc(0.5) WITHIN GROUP (ORDER BY price) FROM products
  SELECT PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY price) FROM products;
  -- COL1: 1.5e0

vsql returns a ``DOUBLE PRECISION``, where PostgreSQL returns the type of the values (1.50). The form that takes an array of fractions has no equivalent.

range_agg
^^^^^^^^^

.. code-block:: text

  range_agg(value anyrange) → anymultirange
  range_agg(value anymultirange) → anymultirange

Returns the union of the ranges that aren't null.

No equivalent.

range_intersect_agg
^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  range_intersect_agg(value anyrange) → anyrange
  range_intersect_agg(value anymultirange) → anymultirange

Returns the intersection of the ranges that aren't null.

No equivalent.

rank
^^^^

Returns the rank a hypothetical row with the given value would have, with gaps for ties.

.. code-block:: sql

  -- rank(args) WITHIN GROUP (ORDER BY sorted_args) → bigint
  SELECT RANK(/*args*/) WITHIN GROUP (ORDER BY /*sorted_args*/) FROM /*table*/;
  -- SELECT rank(2.00) WITHIN GROUP (ORDER BY price) FROM products
  SELECT RANK(2.00) WITHIN GROUP (ORDER BY price) FROM products;
  -- COL1: 3

The window function ``rank() OVER (ORDER BY price)`` is ``(SELECT COUNT(*) FROM products q WHERE q.price < p.price) + 1`` in the select list of ``FROM products p``.

regr_avgx
^^^^^^^^^

Returns the average of the independent variable, for the pairs where neither is null.

.. code-block:: sql

  -- regr_avgx(Y double precision, X double precision) → double precision
  SELECT REGR_AVGX(/*Y*/, /*X*/) FROM /*table*/;
  -- SELECT regr_avgx(qty, price) FROM products
  SELECT REGR_AVGX(qty, price) FROM products;
  -- warning 01003: null value eliminated in set function
  -- COL1: 1.916666666667e0

regr_avgy
^^^^^^^^^

Returns the average of the dependent variable, for the pairs where neither is null.

.. code-block:: sql

  -- regr_avgy(Y double precision, X double precision) → double precision
  SELECT REGR_AVGY(/*Y*/, /*X*/) FROM /*table*/;
  -- SELECT regr_avgy(qty, price) FROM products
  SELECT REGR_AVGY(qty, price) FROM products;
  -- warning 01003: null value eliminated in set function
  -- COL1: 18.333333333333e0

regr_count
^^^^^^^^^^

Counts the pairs where neither value is null.

.. code-block:: sql

  -- regr_count(Y double precision, X double precision) → bigint
  SELECT REGR_COUNT(/*Y*/, /*X*/) FROM /*table*/;
  -- SELECT regr_count(qty, price) FROM products
  SELECT REGR_COUNT(qty, price) FROM products;
  -- warning 01003: null value eliminated in set function
  -- COL1: 3

regr_intercept
^^^^^^^^^^^^^^

Returns the y-intercept of the least-squares line fitted to the pairs.

.. code-block:: sql

  -- regr_intercept(Y double precision, X double precision) → double precision
  SELECT REGR_INTERCEPT(/*Y*/, /*X*/) FROM /*table*/;
  -- SELECT regr_intercept(qty, price) FROM products
  SELECT REGR_INTERCEPT(qty, price) FROM products;
  -- warning 01003: null value eliminated in set function
  -- COL1: 34.214285714286e0

regr_r2
^^^^^^^

Returns the square of the correlation coefficient of the pairs.

.. code-block:: sql

  -- regr_r2(Y double precision, X double precision) → double precision
  SELECT REGR_R2(/*Y*/, /*X*/) FROM /*table*/;
  -- SELECT regr_r2(qty, price) FROM products
  SELECT REGR_R2(qty, price) FROM products;
  -- warning 01003: null value eliminated in set function
  -- COL1: 0.698504983389e0

regr_slope
^^^^^^^^^^

Returns the slope of the least-squares line fitted to the pairs.

.. code-block:: sql

  -- regr_slope(Y double precision, X double precision) → double precision
  SELECT REGR_SLOPE(/*Y*/, /*X*/) FROM /*table*/;
  -- SELECT regr_slope(qty, price) FROM products
  SELECT REGR_SLOPE(qty, price) FROM products;
  -- warning 01003: null value eliminated in set function
  -- COL1: -8.285714285714e0

regr_sxx
^^^^^^^^

Returns the sum of squares of the independent variable around its mean.

.. code-block:: sql

  -- regr_sxx(Y double precision, X double precision) → double precision
  SELECT REGR_SXX(/*Y*/, /*X*/) FROM /*table*/;
  -- SELECT regr_sxx(qty, price) FROM products
  SELECT REGR_SXX(qty, price) FROM products;
  -- warning 01003: null value eliminated in set function
  -- COL1: 7.291666666667e0

regr_sxy
^^^^^^^^

Returns the sum of products of the deviations of the two variables from their means.

.. code-block:: sql

  -- regr_sxy(Y double precision, X double precision) → double precision
  SELECT REGR_SXY(/*Y*/, /*X*/) FROM /*table*/;
  -- SELECT regr_sxy(qty, price) FROM products
  SELECT REGR_SXY(qty, price) FROM products;
  -- warning 01003: null value eliminated in set function
  -- COL1: -60.416666666667e0

regr_syy
^^^^^^^^

Returns the sum of squares of the dependent variable around its mean.

.. code-block:: sql

  -- regr_syy(Y double precision, X double precision) → double precision
  SELECT REGR_SYY(/*Y*/, /*X*/) FROM /*table*/;
  -- SELECT regr_syy(qty, price) FROM products
  SELECT REGR_SYY(qty, price) FROM products;
  -- warning 01003: null value eliminated in set function
  -- COL1: 716.666666666667e0

stddev
^^^^^^

Returns the sample standard deviation, the same as stddev_samp.

.. code-block:: sql

  -- stddev(numeric_type) → double precision
  SELECT STDDEV_SAMP(/*numeric_type*/) FROM /*table*/;
  -- SELECT stddev(qty) FROM products
  SELECT STDDEV_SAMP(qty) FROM products;
  -- warning 01003: null value eliminated in set function
  -- COL1: 18.929694486001e0

stddev_pop
^^^^^^^^^^

Returns the population standard deviation.

.. code-block:: sql

  -- stddev_pop(numeric_type) → double precision
  SELECT STDDEV_POP(/*numeric_type*/) FROM /*table*/;
  -- SELECT stddev_pop(qty) FROM products
  SELECT STDDEV_POP(qty) FROM products;
  -- warning 01003: null value eliminated in set function
  -- COL1: 15.456030825826e0

stddev_samp
^^^^^^^^^^^

Returns the sample standard deviation.

.. code-block:: sql

  -- stddev_samp(numeric_type) → double precision
  SELECT STDDEV_SAMP(/*numeric_type*/) FROM /*table*/;
  -- SELECT stddev_samp(qty) FROM products
  SELECT STDDEV_SAMP(qty) FROM products;
  -- warning 01003: null value eliminated in set function
  -- COL1: 18.929694486001e0

string_agg
^^^^^^^^^^

Joins the values that aren't null into a string, with a delimiter between them.

.. code-block:: sql

  -- string_agg(value text, delimiter text) → text
  SELECT LISTAGG(/*value*/, /*delimiter*/) WITHIN GROUP (ORDER BY /*sort*/) FROM /*table*/;
  -- SELECT string_agg(name, ', ' ORDER BY name) FROM products
  SELECT LISTAGG(name, ', ') WITHIN GROUP (ORDER BY name) FROM products;
  -- COL1: Apple, Banana, Cherry, Date

The ``bytea`` form has no equivalent.

sum
^^^

Returns the sum of the values that aren't null.

.. code-block:: sql

  -- sum(numeric_type) → numeric_type
  SELECT SUM(/*numeric_type*/) FROM /*table*/;
  -- SELECT sum(qty) FROM products
  SELECT SUM(qty) FROM products;
  -- warning 01003: null value eliminated in set function
  -- COL1: 55

var_pop
^^^^^^^

Returns the population variance.

.. code-block:: sql

  -- var_pop(numeric_type) → double precision
  SELECT VAR_POP(/*numeric_type*/) FROM /*table*/;
  -- SELECT var_pop(qty) FROM products
  SELECT VAR_POP(qty) FROM products;
  -- warning 01003: null value eliminated in set function
  -- COL1: 238.888888888889e0

var_samp
^^^^^^^^

Returns the sample variance.

.. code-block:: sql

  -- var_samp(numeric_type) → double precision
  SELECT VAR_SAMP(/*numeric_type*/) FROM /*table*/;
  -- SELECT var_samp(qty) FROM products
  SELECT VAR_SAMP(qty) FROM products;
  -- warning 01003: null value eliminated in set function
  -- COL1: 358.333333333333e0

variance
^^^^^^^^

Returns the sample variance, the same as var_samp.

.. code-block:: sql

  -- variance(numeric_type) → double precision
  SELECT VAR_SAMP(/*numeric_type*/) FROM /*table*/;
  -- SELECT variance(qty) FROM products
  SELECT VAR_SAMP(qty) FROM products;
  -- warning 01003: null value eliminated in set function
  -- COL1: 358.333333333333e0

xmlagg
^^^^^^

.. code-block:: text

  xmlagg(xml ORDER BY input_sort_columns) → xml

Joins XML values together, the aggregate form of xmlconcat.

No equivalent.

Window Functions
----------------

vsql has no window functions (``OVER``). A subquery on the same table can
often give the same value for each row, as below. ``rank``, ``dense_rank``,
``percent_rank`` and ``cume_dist`` are in `Aggregate Functions`_.

first_value
^^^^^^^^^^^

Returns the value of the first row of the window frame.

.. code-block:: sql

  -- first_value(value anyelement) → anyelement
  SELECT /*columns*/, (SELECT q./*value*/ FROM /*table*/ q ORDER BY q./*sort*/ FETCH FIRST 1 ROW ONLY) FROM /*table*/ p;
  -- SELECT name, first_value(name) OVER (ORDER BY price) FROM products
  SELECT name, (SELECT q.name FROM products q ORDER BY q.price FETCH FIRST 1 ROW ONLY) FROM products p ORDER BY price;
  -- NAME: Banana COL2: Banana
  -- NAME: Apple COL2: Banana
  -- NAME: Date COL2: Banana
  -- NAME: Cherry COL2: Banana

The subquery reads the whole table, so a ``WHERE`` of the outer query has to be in the subquery too.

lag
^^^

Returns the value of the row a number of rows before the current row in the window, or a default.

.. code-block:: sql

  -- lag(value anycompatible [, offset integer [, default anycompatible]]) → anycompatible
  SELECT /*columns*/, (SELECT MAX(q./*value*/) FROM /*table*/ q WHERE q./*value*/ < p./*value*/) FROM /*table*/ p;
  -- SELECT name, lag(price) OVER (ORDER BY price) FROM products
  SELECT name, (SELECT MAX(q.price) FROM products q WHERE q.price < p.price) FROM products p ORDER BY price;
  -- NAME: Banana COL2: NULL
  -- NAME: Apple COL2: 0.25
  -- NAME: Date COL2: 1.50
  -- NAME: Cherry COL2: 3.00

This works when the rows are sorted by the value itself and it has no ties. An offset other than 1 has no equivalent.

last_value
^^^^^^^^^^

Returns the value of the last row of the window frame.

.. code-block:: sql

  -- last_value(value anyelement) → anyelement
  SELECT /*columns*/, (SELECT q./*value*/ FROM /*table*/ q ORDER BY q./*sort*/ DESC FETCH FIRST 1 ROW ONLY) FROM /*table*/ p;
  -- SELECT name, last_value(name) OVER (ORDER BY price ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) FROM products ORDER BY price
  SELECT name, (SELECT q.name FROM products q ORDER BY q.price DESC FETCH FIRST 1 ROW ONLY) FROM products p ORDER BY price;
  -- NAME: Banana COL2: Cherry
  -- NAME: Apple COL2: Cherry
  -- NAME: Date COL2: Cherry
  -- NAME: Cherry COL2: Cherry

This is for a frame of the whole partition. With the default frame (up to the current row) ``last_value`` is the value of the current row.

lead
^^^^

Returns the value of the row a number of rows after the current row in the window, or a default.

.. code-block:: sql

  -- lead(value anycompatible [, offset integer [, default anycompatible]]) → anycompatible
  SELECT /*columns*/, (SELECT MIN(q./*value*/) FROM /*table*/ q WHERE q./*value*/ > p./*value*/) FROM /*table*/ p;
  -- SELECT name, lead(price) OVER (ORDER BY price) FROM products
  SELECT name, (SELECT MIN(q.price) FROM products q WHERE q.price > p.price) FROM products p ORDER BY price;
  -- NAME: Banana COL2: 1.50
  -- NAME: Apple COL2: 3.00
  -- NAME: Date COL2: 4.00
  -- NAME: Cherry COL2: NULL

This works when the rows are sorted by the value itself and it has no ties. An offset other than 1 has no equivalent.

nth_value
^^^^^^^^^

.. code-block:: text

  nth_value(value anyelement, n integer) → anyelement

Returns the value of the nth row of the window frame.

No equivalent.

ntile
^^^^^

.. code-block:: text

  ntile(num_buckets integer) → integer

Splits the rows of the partition into a number of groups as equal as possible, and returns the group of the current row.

No equivalent.

row_number
^^^^^^^^^^

Returns the number of the current row in its partition, counting from 1.

.. code-block:: sql

  -- row_number() → bigint
  SELECT /*columns*/, (SELECT COUNT(*) FROM /*table*/ q WHERE q./*sort*/ <= p./*sort*/) FROM /*table*/ p;
  -- SELECT name, row_number() OVER (ORDER BY price) FROM products
  SELECT name, (SELECT COUNT(*) FROM products q WHERE q.price <= p.price) FROM products p ORDER BY price;
  -- NAME: Banana COL2: 1
  -- NAME: Apple COL2: 2
  -- NAME: Date COL2: 3
  -- NAME: Cherry COL2: 4

This works when the sort column has no ties (each tie would get the same number).

Merge Support Functions
-----------------------

merge_action
^^^^^^^^^^^^

.. code-block:: text

  merge_action() → text

Returns INSERT, UPDATE or DELETE for the action of a MERGE that made a row of its RETURNING list.

No equivalent.

vsql has no ``MERGE``.

Set Returning Functions
-----------------------

vsql has no functions that return a set of rows. ``unnest`` is in `Array
Functions`_.

generate_series
^^^^^^^^^^^^^^^

Returns a row for each value from a start to a stop, counting by a step.

.. code-block:: sql

  -- generate_series(start integer, stop integer [, step integer]) → setof integer
  SELECT n FROM (VALUES /*start*/, /*...*/, /*stop*/) AS t (n) ORDER BY n;
  -- SELECT * FROM generate_series(1, 3)
  SELECT n FROM (VALUES 1, 2, 3) AS t (n) ORDER BY n;
  -- N: 1
  -- N: 2
  -- N: 3

Each value has to be written out. The forms for timestamps (with an interval as the step) have no equivalent.

generate_subscripts
^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  generate_subscripts(array anyarray, dim integer [, reverse boolean]) → setof integer

Returns a row for each subscript of a dimension of an array.

No equivalent.

System Information Functions
----------------------------

vsql has no users, roles, privileges, object identifiers (oids) or system
catalog, so most of these have no equivalent. vsql keeps a description of its
schemas, tables and columns in :doc:`information-schema`.

acldefault
^^^^^^^^^^

.. code-block:: text

  acldefault(type "char", ownerId oid) → aclitem[]

Returns the default access privileges of a kind of object for an owner.

No equivalent.

aclexplode
^^^^^^^^^^

.. code-block:: text

  aclexplode(aclitem[]) → setof record

Returns a row for each privilege of an access privilege array.

No equivalent.

col_description
^^^^^^^^^^^^^^^

.. code-block:: text

  col_description(table oid, column integer) → text

Returns the comment of a column.

No equivalent.

COLLATION FOR
^^^^^^^^^^^^^

.. code-block:: text

  COLLATION FOR ("any") → text

Returns the name of the collation of a value.

No equivalent.

current_catalog
^^^^^^^^^^^^^^^

Returns the name of the current database.

.. code-block:: sql

  -- current_catalog → name
  VALUES CURRENT_CATALOG;
  -- current_catalog
  VALUES CURRENT_CATALOG;
  -- COL1: :memory:

vsql names the catalog of an in-memory database ``:memory:``, and of a file the name of the file up to its first dot. In PostgreSQL it's the name of the database the client connected to.

current_database
^^^^^^^^^^^^^^^^

Returns the name of the current database, the same as current_catalog.

.. code-block:: sql

  -- current_database() → name
  VALUES CURRENT_CATALOG;
  -- current_database()
  VALUES CURRENT_CATALOG;
  -- COL1: :memory:

vsql names the catalog of an in-memory database ``:memory:``, and of a file the name of the file up to its first dot.

current_query
^^^^^^^^^^^^^

.. code-block:: text

  current_query() → text

Returns the text of the statement the client sent.

No equivalent.

current_role
^^^^^^^^^^^^

.. code-block:: text

  current_role → name

Returns the name of the role whose privileges are in use, the same as current_user.

No equivalent.

current_schema
^^^^^^^^^^^^^^

Returns the name of the first schema of the search path, where new tables are created.

.. code-block:: sql

  -- current_schema → name
  VALUES CURRENT_SCHEMA;
  -- current_schema
  VALUES CURRENT_SCHEMA;
  -- COL1: PUBLIC

The default schema is ``PUBLIC`` in vsql, ``public`` in PostgreSQL. It's changed with :doc:`set-schema`, rather than ``SET search_path``.

current_schemas
^^^^^^^^^^^^^^^

.. code-block:: text

  current_schemas(include_implicit boolean) → name[]

Returns the schemas of the search path as an array, optionally with the implicit ones.

No equivalent.

current_user
^^^^^^^^^^^^

.. code-block:: text

  current_user → name

Returns the name of the user whose privileges are in use.

No equivalent.

format_type
^^^^^^^^^^^

.. code-block:: text

  format_type(type oid, typemod integer) → text

Returns the SQL name of a type from its oid and modifier.

No equivalent.

has_any_column_privilege
^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  has_any_column_privilege([user name or oid,] table text or oid, privilege text) → boolean

Tests if a user has a privilege on any column of a table.

No equivalent.

has_column_privilege
^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  has_column_privilege([user name or oid,] table text or oid, column text or smallint, privilege text) → boolean

Tests if a user has a privilege on a column.

No equivalent.

has_database_privilege
^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  has_database_privilege([user name or oid,] database text or oid, privilege text) → boolean

Tests if a user has a privilege on a database.

No equivalent.

has_foreign_data_wrapper_privilege
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  has_foreign_data_wrapper_privilege([user name or oid,] fdw text or oid, privilege text) → boolean

Tests if a user has a privilege on a foreign-data wrapper.

No equivalent.

has_function_privilege
^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  has_function_privilege([user name or oid,] function text or oid, privilege text) → boolean

Tests if a user has a privilege on a function.

No equivalent.

has_language_privilege
^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  has_language_privilege([user name or oid,] language text or oid, privilege text) → boolean

Tests if a user has a privilege on a language.

No equivalent.

has_largeobject_privilege
^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  has_largeobject_privilege([user name or oid,] largeobject oid, privilege text) → boolean

Tests if a user has a privilege on a large object.

No equivalent.

has_parameter_privilege
^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  has_parameter_privilege([user name or oid,] parameter text, privilege text) → boolean

Tests if a user has a privilege on a configuration parameter.

No equivalent.

has_schema_privilege
^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  has_schema_privilege([user name or oid,] schema text or oid, privilege text) → boolean

Tests if a user has a privilege on a schema.

No equivalent.

has_sequence_privilege
^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  has_sequence_privilege([user name or oid,] sequence text or oid, privilege text) → boolean

Tests if a user has a privilege on a sequence.

No equivalent.

has_server_privilege
^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  has_server_privilege([user name or oid,] server text or oid, privilege text) → boolean

Tests if a user has a privilege on a server.

No equivalent.

has_table_privilege
^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  has_table_privilege([user name or oid,] table text or oid, privilege text) → boolean

Tests if a user has a privilege on a table.

No equivalent.

has_tablespace_privilege
^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  has_tablespace_privilege([user name or oid,] tablespace text or oid, privilege text) → boolean

Tests if a user has a privilege on a tablespace.

No equivalent.

has_type_privilege
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  has_type_privilege([user name or oid,] type text or oid, privilege text) → boolean

Tests if a user has a privilege on a type.

No equivalent.

icu_unicode_version
^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  icu_unicode_version() → text

Returns the version of Unicode that ICU uses, or null without ICU.

No equivalent.

inet_client_addr
^^^^^^^^^^^^^^^^

.. code-block:: text

  inet_client_addr() → inet

Returns the IP address of the client.

No equivalent.

inet_client_port
^^^^^^^^^^^^^^^^

.. code-block:: text

  inet_client_port() → integer

Returns the port number of the client.

No equivalent.

inet_server_addr
^^^^^^^^^^^^^^^^

.. code-block:: text

  inet_server_addr() → inet

Returns the IP address the server accepted the connection on.

No equivalent.

inet_server_port
^^^^^^^^^^^^^^^^

.. code-block:: text

  inet_server_port() → integer

Returns the port number the server accepted the connection on.

No equivalent.

makeaclitem
^^^^^^^^^^^

.. code-block:: text

  makeaclitem(grantee oid, grantor oid, privileges text, is_grantable boolean) → aclitem

Builds an access privilege item.

No equivalent.

mxid_age
^^^^^^^^

.. code-block:: text

  mxid_age(xid) → integer

Returns how many multixact IDs ago a multixact ID was assigned.

No equivalent.

obj_description
^^^^^^^^^^^^^^^

.. code-block:: text

  obj_description(object oid [, catalog name]) → text

Returns the comment of a database object.

No equivalent.

vsql server (see :doc:`server`) has this function for its PostgreSQL clients only (flagged as ``V501-04``), and it returns ``NULL`` (vsql has no comments).

pg_available_wal_summaries
^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_available_wal_summaries() → setof record

Returns a row for each WAL summary file in the data directory.

No equivalent.

pg_backend_pid
^^^^^^^^^^^^^^

.. code-block:: text

  pg_backend_pid() → integer

Returns the process ID of the server process of the session.

No equivalent.

pg_basetype
^^^^^^^^^^^

.. code-block:: text

  pg_basetype(regtype) → regtype

Returns the base type of a domain.

No equivalent.

pg_blocking_pids
^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_blocking_pids(integer) → integer[]

Returns the process IDs of the sessions that block a process from getting a lock.

No equivalent.

pg_char_to_encoding
^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_char_to_encoding(encoding name) → integer

Returns the internal number of an encoding name.

No equivalent.

pg_collation_is_visible
^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_collation_is_visible(collation oid) → boolean

Tests if a collation can be found by its name without a schema, on the search path.

No equivalent.

pg_conf_load_time
^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_conf_load_time() → timestamp with time zone

Returns when the server configuration files were last loaded.

No equivalent.

pg_control_checkpoint
^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_control_checkpoint() → record

Returns information about the last checkpoint, from the control file.

No equivalent.

pg_control_init
^^^^^^^^^^^^^^^

.. code-block:: text

  pg_control_init() → record

Returns the settings the cluster was initialized with, from the control file.

No equivalent.

pg_control_recovery
^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_control_recovery() → record

Returns information about recovery, from the control file.

No equivalent.

pg_control_system
^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_control_system() → record

Returns the version and system identifier of the cluster, from the control file.

No equivalent.

pg_conversion_is_visible
^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_conversion_is_visible(conversion oid) → boolean

Tests if a conversion can be found by its name without a schema, on the search path.

No equivalent.

pg_current_logfile
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_current_logfile([text]) → text

Returns the path of the log file the logging collector is writing to.

No equivalent.

pg_current_snapshot
^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_current_snapshot() → pg_snapshot

Returns the snapshot of the current transaction.

No equivalent.

pg_current_xact_id
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_current_xact_id() → xid8

Returns the ID of the current transaction, assigning one if it has none.

No equivalent.

pg_current_xact_id_if_assigned
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_current_xact_id_if_assigned() → xid8

Returns the ID of the current transaction, or null if it has none yet.

No equivalent.

pg_describe_object
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_describe_object(classid oid, objid oid, objsubid integer) → text

Returns a description of a database object from its catalog oids.

No equivalent.

pg_encoding_to_char
^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_encoding_to_char(encoding integer) → name

Returns the name of an encoding from its internal number.

No equivalent.

pg_function_is_visible
^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_function_is_visible(function oid) → boolean

Tests if a function can be found by its name without a schema, on the search path.

No equivalent.

pg_get_acl
^^^^^^^^^^

.. code-block:: text

  pg_get_acl(classid oid, objid oid, objsubid integer) → aclitem[]

Returns the access privileges of a database object.

No equivalent.

pg_get_catalog_foreign_keys
^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_get_catalog_foreign_keys() → setof record

Returns a row for each foreign key relationship of the system catalog.

No equivalent.

pg_get_constraintdef
^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_get_constraintdef(constraint oid [, pretty boolean]) → text

Returns the definition of a constraint as SQL.

No equivalent.

pg_get_expr
^^^^^^^^^^^

.. code-block:: text

  pg_get_expr(expr pg_node_tree, relation oid [, pretty boolean]) → text

Converts the internal form of an expression in the catalog to SQL.

No equivalent.

pg_get_function_arguments
^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_get_function_arguments(func oid) → text

Returns the argument list of a function, with defaults.

No equivalent.

pg_get_function_identity_arguments
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_get_function_identity_arguments(func oid) → text

Returns the argument list that identifies a function, without defaults.

No equivalent.

vsql server (see :doc:`server`) has this function for its PostgreSQL clients only (flagged as ``V501-08``), and it returns an empty string (there's no ``pg_proc`` to describe).

pg_get_function_result
^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_get_function_result(func oid) → text

Returns the RETURNS clause of a function.

No equivalent.

pg_get_functiondef
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_get_functiondef(func oid) → text

Returns the CREATE FUNCTION statement of a function.

No equivalent.

pg_get_indexdef
^^^^^^^^^^^^^^^

.. code-block:: text

  pg_get_indexdef(index oid [, column integer, pretty boolean]) → text

Returns the CREATE INDEX statement of an index, or the definition of one of its columns.

No equivalent.

pg_get_keywords
^^^^^^^^^^^^^^^

.. code-block:: text

  pg_get_keywords() → setof record

Returns a row for each SQL keyword the server knows, with its category.

No equivalent.

pg_get_loaded_modules
^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_get_loaded_modules() → setof record

Returns a row for each loadable module the server process has loaded, with its version.

No equivalent.

pg_get_multixact_members
^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_get_multixact_members(multixid xid) → setof record

Returns the transaction IDs and lock modes of a multixact.

No equivalent.

pg_get_object_address
^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_get_object_address(type text, object_names text[], object_args text[]) → record

Returns the catalog oids of a database object from its type and names.

No equivalent.

pg_get_partition_constraintdef
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_get_partition_constraintdef(table oid) → text

Returns the constraint implied by the partition bound of a table.

No equivalent.

pg_get_partkeydef
^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_get_partkeydef(table oid) → text

Returns the partition key of a partitioned table.

No equivalent.

pg_get_ruledef
^^^^^^^^^^^^^^

.. code-block:: text

  pg_get_ruledef(rule oid [, pretty boolean]) → text

Returns the CREATE RULE statement of a rule.

No equivalent.

pg_get_serial_sequence
^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_get_serial_sequence(table text, column text) → text

Returns the name of the sequence that a serial or identity column uses.

No equivalent.

pg_get_statisticsobjdef
^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_get_statisticsobjdef(statobj oid) → text

Returns the CREATE STATISTICS statement of an extended statistics object.

No equivalent.

pg_get_triggerdef
^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_get_triggerdef(trigger oid [, pretty boolean]) → text

Returns the CREATE TRIGGER statement of a trigger.

No equivalent.

pg_get_userbyid
^^^^^^^^^^^^^^^

.. code-block:: text

  pg_get_userbyid(role oid) → name

Returns the name of a role from its oid.

No equivalent.

vsql server (see :doc:`server`) has this function for its PostgreSQL clients only (flagged as ``V501-03``), and it returns ``vsql`` for any oid (every object is owned by the only user).

pg_get_viewdef
^^^^^^^^^^^^^^

.. code-block:: text

  pg_get_viewdef(view oid [, pretty boolean]) → text
  pg_get_viewdef(view oid, wrap_column integer) → text
  pg_get_viewdef(view text [, pretty boolean]) → text

Returns the SELECT statement that defines a view or materialized view.

No equivalent.

pg_get_wal_summarizer_state
^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_get_wal_summarizer_state() → record

Returns how far the WAL summarizer has got.

No equivalent.

pg_has_role
^^^^^^^^^^^

.. code-block:: text

  pg_has_role([user name or oid,] role text or oid, privilege text) → boolean

Tests if a user is a member of a role, or can use its privileges.

No equivalent.

pg_identify_object
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_identify_object(classid oid, objid oid, objsubid integer) → record

Returns the type, schema, name and identity of a database object.

No equivalent.

pg_identify_object_as_address
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_identify_object_as_address(classid oid, objid oid, objsubid integer) → record

Returns the parts that identify a database object, for pg_get_object_address.

No equivalent.

pg_index_column_has_property
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_index_column_has_property(index regclass, column integer, property text) → boolean

Tests if a column of an index has a property, such as being sorted in ascending order.

No equivalent.

pg_index_has_property
^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_index_has_property(index regclass, property text) → boolean

Tests if an index has a property, such as being clusterable.

No equivalent.

pg_indexam_has_property
^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_indexam_has_property(am oid, property text) → boolean

Tests if an index access method has a property, such as supporting unique indexes.

No equivalent.

pg_input_error_info
^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_input_error_info(value text, type_name text) → record

Returns the error that converting a string to a type would raise.

No equivalent.

pg_input_is_valid
^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_input_is_valid(string text, type text) → boolean

Tests if a string can be converted to a type without an error.

No equivalent.

pg_is_other_temp_schema
^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_is_other_temp_schema(oid) → boolean

Tests if a schema is the temporary schema of another session.

No equivalent.

pg_jit_available
^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_jit_available() → boolean

Tests if JIT compilation is available and turned on.

No equivalent.

pg_last_committed_xact
^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_last_committed_xact() → record

Returns the ID, commit time and replication origin of the last committed transaction.

No equivalent.

pg_listening_channels
^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_listening_channels() → setof text

Returns the channels the session is listening on.

No equivalent.

pg_my_temp_schema
^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_my_temp_schema() → oid

Returns the oid of the temporary schema of the session.

No equivalent.

pg_notification_queue_usage
^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_notification_queue_usage() → double precision

Returns the fraction of the queue of notifications that is used.

No equivalent.

pg_numa_available
^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_numa_available() → boolean

Tests if the server was built with NUMA support.

No equivalent.

pg_opclass_is_visible
^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_opclass_is_visible(opclass oid) → boolean

Tests if a operator class can be found by its name without a schema, on the search path.

No equivalent.

pg_operator_is_visible
^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_operator_is_visible(operator oid) → boolean

Tests if a operator can be found by its name without a schema, on the search path.

No equivalent.

pg_opfamily_is_visible
^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_opfamily_is_visible(opclass oid) → boolean

Tests if a operator family can be found by its name without a schema, on the search path.

No equivalent.

pg_options_to_table
^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_options_to_table(options_array text[]) → setof record

Returns a row for each name=value storage option.

No equivalent.

pg_postmaster_start_time
^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_postmaster_start_time() → timestamp with time zone

Returns when the server started.

No equivalent.

pg_safe_snapshot_blocking_pids
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_safe_snapshot_blocking_pids(integer) → integer[]

Returns the process IDs of the sessions that a serializable transaction is waiting on for a safe snapshot.

No equivalent.

pg_settings_get_flags
^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_settings_get_flags(guc text) → text[]

Returns the flags of a configuration parameter.

No equivalent.

pg_snapshot_xip
^^^^^^^^^^^^^^^

.. code-block:: text

  pg_snapshot_xip(pg_snapshot) → setof xid8

Returns the IDs of the transactions that were in progress in a snapshot.

No equivalent.

pg_snapshot_xmax
^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_snapshot_xmax(pg_snapshot) → xid8

Returns the first transaction ID that wasn't assigned yet in a snapshot.

No equivalent.

pg_snapshot_xmin
^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_snapshot_xmin(pg_snapshot) → xid8

Returns the earliest transaction ID that was still active in a snapshot.

No equivalent.

pg_statistics_obj_is_visible
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_statistics_obj_is_visible(stat oid) → boolean

Tests if a extended statistics object can be found by its name without a schema, on the search path.

No equivalent.

pg_table_is_visible
^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_table_is_visible(table oid) → boolean

Tests if a table can be found by its name without a schema, on the search path.

No equivalent.

pg_tablespace_databases
^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_tablespace_databases(tablespace oid) → setof oid

Returns the oids of the databases that have objects in a tablespace.

No equivalent.

pg_tablespace_location
^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_tablespace_location(tablespace oid) → text

Returns the directory of a tablespace.

No equivalent.

pg_trigger_depth
^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_trigger_depth() → integer

Returns how many triggers are nested at this point.

No equivalent.

pg_ts_config_is_visible
^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_ts_config_is_visible(config oid) → boolean

Tests if a text search configuration can be found by its name without a schema, on the search path.

No equivalent.

pg_ts_dict_is_visible
^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_ts_dict_is_visible(dict oid) → boolean

Tests if a text search dictionary can be found by its name without a schema, on the search path.

No equivalent.

pg_ts_parser_is_visible
^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_ts_parser_is_visible(parser oid) → boolean

Tests if a text search parser can be found by its name without a schema, on the search path.

No equivalent.

pg_ts_template_is_visible
^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_ts_template_is_visible(template oid) → boolean

Tests if a text search template can be found by its name without a schema, on the search path.

No equivalent.

pg_type_is_visible
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_type_is_visible(type oid) → boolean

Tests if a type can be found by its name without a schema, on the search path.

No equivalent.

pg_typeof
^^^^^^^^^

.. code-block:: text

  pg_typeof("any") → regtype

Returns the data type of a value.

No equivalent.

pg_visible_in_snapshot
^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_visible_in_snapshot(xid8, pg_snapshot) → boolean

Tests if a transaction is visible in a snapshot.

No equivalent.

pg_wal_summary_contents
^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_wal_summary_contents(tli bigint, start_lsn pg_lsn, end_lsn pg_lsn) → setof record

Returns a row for each block that a WAL summary says was modified.

No equivalent.

pg_xact_commit_timestamp
^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_xact_commit_timestamp(xid) → timestamp with time zone

Returns when a transaction was committed.

No equivalent.

pg_xact_commit_timestamp_origin
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_xact_commit_timestamp_origin(xid) → record

Returns when a transaction was committed, and its replication origin.

No equivalent.

pg_xact_status
^^^^^^^^^^^^^^

.. code-block:: text

  pg_xact_status(xid8) → text

Returns whether a recent transaction is in progress, committed or aborted.

No equivalent.

row_security_active
^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  row_security_active(table text or oid) → boolean

Tests if row-level security is in force for a table for the current user.

No equivalent.

session_user
^^^^^^^^^^^^

.. code-block:: text

  session_user → name

Returns the name of the user that started the session.

No equivalent.

shobj_description
^^^^^^^^^^^^^^^^^

.. code-block:: text

  shobj_description(object oid, catalog name) → text

Returns the comment of an object that is shared by every database, such as a role.

No equivalent.

system_user
^^^^^^^^^^^

.. code-block:: text

  system_user → text

Returns the method and identity the user authenticated with.

No equivalent.

to_regclass
^^^^^^^^^^^

.. code-block:: text

  to_regclass(text) → regclass

Looks up a relation by its name and returns its oid, or null if there is none.

No equivalent.

to_regcollation
^^^^^^^^^^^^^^^

.. code-block:: text

  to_regcollation(text) → regcollation

Looks up a collation by its name and returns its oid, or null if there is none.

No equivalent.

to_regnamespace
^^^^^^^^^^^^^^^

.. code-block:: text

  to_regnamespace(text) → regnamespace

Looks up a schema by its name and returns its oid, or null if there is none.

No equivalent.

to_regoper
^^^^^^^^^^

.. code-block:: text

  to_regoper(text) → regoper

Looks up a operator by its name and returns its oid, or null if there is none.

No equivalent.

to_regoperator
^^^^^^^^^^^^^^

.. code-block:: text

  to_regoperator(text) → regoperator

Looks up a operator with its argument types by its name and returns its oid, or null if there is none.

No equivalent.

to_regproc
^^^^^^^^^^

.. code-block:: text

  to_regproc(text) → regproc

Looks up a function by its name and returns its oid, or null if there is none.

No equivalent.

to_regprocedure
^^^^^^^^^^^^^^^

.. code-block:: text

  to_regprocedure(text) → regprocedure

Looks up a function with its argument types by its name and returns its oid, or null if there is none.

No equivalent.

to_regrole
^^^^^^^^^^

.. code-block:: text

  to_regrole(text) → regrole

Looks up a role by its name and returns its oid, or null if there is none.

No equivalent.

to_regtype
^^^^^^^^^^

.. code-block:: text

  to_regtype(text) → regtype

Looks up a type by its name and returns its oid, or null if there is none.

No equivalent.

to_regtypemod
^^^^^^^^^^^^^

.. code-block:: text

  to_regtypemod(text) → integer

Returns the type modifier of a type name, such as the length of varchar(10).

No equivalent.

txid_current
^^^^^^^^^^^^

.. code-block:: text

  txid_current() → bigint

Returns the ID of the current transaction (deprecated, see pg_current_xact_id).

No equivalent.

txid_current_if_assigned
^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  txid_current_if_assigned() → bigint

Returns the ID of the current transaction, or null if it has none yet (deprecated).

No equivalent.

txid_current_snapshot
^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  txid_current_snapshot() → txid_snapshot

Returns the snapshot of the current transaction (deprecated).

No equivalent.

txid_snapshot_xip
^^^^^^^^^^^^^^^^^

.. code-block:: text

  txid_snapshot_xip(txid_snapshot) → setof bigint

Returns the IDs of the transactions that were in progress in a snapshot (deprecated).

No equivalent.

txid_snapshot_xmax
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  txid_snapshot_xmax(txid_snapshot) → bigint

Returns the first transaction ID that wasn't assigned yet in a snapshot (deprecated).

No equivalent.

txid_snapshot_xmin
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  txid_snapshot_xmin(txid_snapshot) → bigint

Returns the earliest transaction ID that was still active in a snapshot (deprecated).

No equivalent.

txid_status
^^^^^^^^^^^

.. code-block:: text

  txid_status(bigint) → text

Returns whether a recent transaction is in progress, committed or aborted (deprecated).

No equivalent.

txid_visible_in_snapshot
^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  txid_visible_in_snapshot(bigint, txid_snapshot) → boolean

Tests if a transaction is visible in a snapshot (deprecated).

No equivalent.

unicode_version
^^^^^^^^^^^^^^^

.. code-block:: text

  unicode_version() → text

Returns the version of Unicode that PostgreSQL uses.

No equivalent.

user
^^^^

.. code-block:: text

  user → name

Returns the name of the current user, the same as current_user.

No equivalent.

version
^^^^^^^

.. code-block:: text

  version() → text

Returns a string that describes the version of the server.

No equivalent.

vsql server (see :doc:`server`) has this function for its PostgreSQL clients only (flagged as ``V501-01``), and it returns the version string of PostgreSQL 9.3.10, for the clients that check it. ``vsql version`` on the command line prints the version of vsql.

System Administration Functions
-------------------------------

These manage a PostgreSQL server: its settings, processes, write-ahead log
(WAL), replication, files and locks. vsql is an embedded database with none
of these, so none of them has an equivalent.

brin_desummarize_range
^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  brin_desummarize_range(index regclass, blockNumber bigint) → void

Removes the summary of the page range of a BRIN index that holds a block.

No equivalent.

brin_summarize_new_values
^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  brin_summarize_new_values(index regclass) → integer

Summarizes the page ranges of a BRIN index that aren't summarized yet.

No equivalent.

brin_summarize_range
^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  brin_summarize_range(index regclass, blockNumber bigint) → integer

Summarizes the page range of a BRIN index that holds a block.

No equivalent.

current_setting
^^^^^^^^^^^^^^^

.. code-block:: text

  current_setting(setting_name text [, missing_ok boolean]) → text

Returns the value of a configuration parameter.

No equivalent.

vsql server (see :doc:`server`) has this function for its PostgreSQL clients only (flagged as ``V501-02``), and it returns ``90310`` for any name (the ``server_version_num`` of PostgreSQL 9.3.10), for the clients that check it.

gin_clean_pending_list
^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  gin_clean_pending_list(index regclass) → bigint

Moves the pending entries of a GIN index into its main structure.

No equivalent.

pg_advisory_lock
^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_advisory_lock(key bigint) → void
  pg_advisory_lock(key1 integer, key2 integer) → void

Takes an exclusive advisory lock for the session, waiting for it if needed.

No equivalent.

pg_advisory_lock_shared
^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_advisory_lock_shared(key bigint) → void
  pg_advisory_lock_shared(key1 integer, key2 integer) → void

Takes a shared advisory lock for the session, waiting for it if needed.

No equivalent.

pg_advisory_unlock
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_advisory_unlock(key bigint) → boolean
  pg_advisory_unlock(key1 integer, key2 integer) → boolean

Releases an exclusive advisory lock of the session.

No equivalent.

pg_advisory_unlock_all
^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_advisory_unlock_all() → void

Releases every advisory lock of the session.

No equivalent.

pg_advisory_unlock_shared
^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_advisory_unlock_shared(key bigint) → boolean
  pg_advisory_unlock_shared(key1 integer, key2 integer) → boolean

Releases a shared advisory lock of the session.

No equivalent.

pg_advisory_xact_lock
^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_advisory_xact_lock(key bigint) → void
  pg_advisory_xact_lock(key1 integer, key2 integer) → void

Takes an exclusive advisory lock until the end of the transaction, waiting for it if needed.

No equivalent.

pg_advisory_xact_lock_shared
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_advisory_xact_lock_shared(key bigint) → void
  pg_advisory_xact_lock_shared(key1 integer, key2 integer) → void

Takes a shared advisory lock until the end of the transaction, waiting for it if needed.

No equivalent.

pg_backup_start
^^^^^^^^^^^^^^^

.. code-block:: text

  pg_backup_start(label text [, fast boolean]) → pg_lsn

Gets the server ready for an online backup.

No equivalent.

pg_backup_stop
^^^^^^^^^^^^^^

.. code-block:: text

  pg_backup_stop([wait_for_archive boolean]) → record

Finishes an online backup.

No equivalent.

pg_cancel_backend
^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_cancel_backend(pid integer) → boolean

Cancels the current statement of another session.

No equivalent.

pg_clear_attribute_stats
^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_clear_attribute_stats(schemaname text, relname text, attname text, inherited boolean) → void

Clears the planner statistics of a column.

No equivalent.

pg_clear_relation_stats
^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_clear_relation_stats(schemaname text, relname text) → void

Clears the planner statistics of a table.

No equivalent.

pg_collation_actual_version
^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_collation_actual_version(oid) → text

Returns the version of a collation that the operating system has now.

No equivalent.

pg_column_compression
^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_column_compression("any") → text

Returns the compression method of a stored value.

No equivalent.

pg_column_size
^^^^^^^^^^^^^^

.. code-block:: text

  pg_column_size("any") → integer

Returns the number of bytes a value takes to store, after any compression.

No equivalent.

pg_column_toast_chunk_id
^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_column_toast_chunk_id("any") → oid

Returns the chunk_id of a value stored in TOAST.

No equivalent.

pg_copy_logical_replication_slot
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_copy_logical_replication_slot(src_slot_name name, dst_slot_name name [, temporary boolean [, plugin name]]) → record

Copies a logical replication slot, optionally with another plugin.

No equivalent.

pg_copy_physical_replication_slot
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_copy_physical_replication_slot(src_slot_name name, dst_slot_name name [, temporary boolean]) → record

Copies a physical replication slot.

No equivalent.

pg_create_logical_replication_slot
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_create_logical_replication_slot(slot_name name, plugin name [, temporary boolean, twophase boolean, failover boolean]) → record

Creates a logical replication slot with an output plugin.

No equivalent.

pg_create_physical_replication_slot
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_create_physical_replication_slot(slot_name name [, immediately_reserve boolean, temporary boolean]) → record

Creates a physical replication slot.

No equivalent.

pg_create_restore_point
^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_create_restore_point(name text) → pg_lsn

Adds a named point to the WAL to recover to.

No equivalent.

pg_current_wal_flush_lsn
^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_current_wal_flush_lsn() → pg_lsn

Returns how far the WAL has been flushed to disk.

No equivalent.

pg_current_wal_insert_lsn
^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_current_wal_insert_lsn() → pg_lsn

Returns the current insert position of the WAL.

No equivalent.

pg_current_wal_lsn
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_current_wal_lsn() → pg_lsn

Returns the current write position of the WAL.

No equivalent.

pg_database_collation_actual_version
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_database_collation_actual_version(oid) → text

Returns the version of the collation of a database that the operating system has now.

No equivalent.

pg_database_size
^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_database_size(name) → bigint
  pg_database_size(oid) → bigint

Returns the disk space a database uses.

No equivalent.

pg_drop_replication_slot
^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_drop_replication_slot(slot_name name) → void

Drops a replication slot.

No equivalent.

pg_export_snapshot
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_export_snapshot() → text

Saves the snapshot of the current transaction so that other sessions can use it.

No equivalent.

pg_filenode_relation
^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_filenode_relation(tablespace oid, filenode oid) → regclass

Returns the table or index that a file node belongs to.

No equivalent.

pg_get_wal_replay_pause_state
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_get_wal_replay_pause_state() → text

Returns whether the replay of the WAL is paused, being paused or not paused.

No equivalent.

pg_get_wal_resource_managers
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_get_wal_resource_managers() → setof record

Returns a row for each WAL resource manager.

No equivalent.

pg_import_system_collations
^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_import_system_collations(schema regnamespace) → integer

Adds the collations of the operating system to the catalog.

No equivalent.

pg_indexes_size
^^^^^^^^^^^^^^^

.. code-block:: text

  pg_indexes_size(regclass) → bigint

Returns the disk space the indexes of a table use.

No equivalent.

vsql server (see :doc:`server`) has this function for its PostgreSQL clients only (flagged as ``V501-07``), and it returns ``NULL`` (the size isn't known).

pg_is_in_recovery
^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_is_in_recovery() → boolean

Tests if the server is still recovering (a standby).

No equivalent.

pg_is_wal_replay_paused
^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_is_wal_replay_paused() → boolean

Tests if a pause of the replay of the WAL was asked for.

No equivalent.

pg_last_wal_receive_lsn
^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_last_wal_receive_lsn() → pg_lsn

Returns how far a standby has received and synced the WAL.

No equivalent.

pg_last_wal_replay_lsn
^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_last_wal_replay_lsn() → pg_lsn

Returns how far a standby has replayed the WAL.

No equivalent.

pg_last_xact_replay_timestamp
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_last_xact_replay_timestamp() → timestamp with time zone

Returns the commit time of the last transaction a standby replayed.

No equivalent.

pg_log_backend_memory_contexts
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_log_backend_memory_contexts(pid integer) → boolean

Writes the memory use of a server process to the log.

No equivalent.

pg_log_standby_snapshot
^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_log_standby_snapshot() → pg_lsn

Writes a snapshot of the running transactions to the WAL.

No equivalent.

pg_logical_emit_message
^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_logical_emit_message(transactional boolean, prefix text, message text [, flush boolean DEFAULT false]) → pg_lsn
  pg_logical_emit_message(transactional boolean, prefix text, message bytea [, flush boolean DEFAULT false]) → pg_lsn

Writes a message to the WAL for logical decoding.

No equivalent.

pg_logical_slot_get_binary_changes
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_logical_slot_get_binary_changes(slot_name name, upto_lsn pg_lsn, upto_nchanges integer, VARIADIC options text[]) → setof record

Returns and consumes the changes of a logical replication slot, as bytea.

No equivalent.

pg_logical_slot_get_changes
^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_logical_slot_get_changes(slot_name name, upto_lsn pg_lsn, upto_nchanges integer, VARIADIC options text[]) → setof record

Returns and consumes the changes of a logical replication slot.

No equivalent.

pg_logical_slot_peek_binary_changes
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_logical_slot_peek_binary_changes(slot_name name, upto_lsn pg_lsn, upto_nchanges integer, VARIADIC options text[]) → setof record

Returns the changes of a logical replication slot as bytea, without consuming them.

No equivalent.

pg_logical_slot_peek_changes
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_logical_slot_peek_changes(slot_name name, upto_lsn pg_lsn, upto_nchanges integer, VARIADIC options text[]) → setof record

Returns the changes of a logical replication slot without consuming them.

No equivalent.

pg_ls_archive_statusdir
^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_ls_archive_statusdir() → setof record

Returns the name, size and modification time of each file in the WAL archive status directory.

No equivalent.

pg_ls_dir
^^^^^^^^^

.. code-block:: text

  pg_ls_dir(dirname text [, missing_ok boolean, include_dot_dirs boolean]) → setof text

Returns the names of the files in a directory on the server.

No equivalent.

pg_ls_logdir
^^^^^^^^^^^^

.. code-block:: text

  pg_ls_logdir() → setof record

Returns the name, size and modification time of each file in the log directory.

No equivalent.

pg_ls_logicalmapdir
^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_ls_logicalmapdir() → setof record

Returns the name, size and modification time of each file in the logical mappings directory.

No equivalent.

pg_ls_logicalsnapdir
^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_ls_logicalsnapdir() → setof record

Returns the name, size and modification time of each file in the logical snapshots directory.

No equivalent.

pg_ls_replslotdir
^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_ls_replslotdir(slot_name text) → setof record

Returns the name, size and modification time of each file in the directory of a replication slot.

No equivalent.

pg_ls_summariesdir
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_ls_summariesdir() → setof record

Returns the name, size and modification time of each file in the WAL summaries directory.

No equivalent.

pg_ls_tmpdir
^^^^^^^^^^^^

.. code-block:: text

  pg_ls_tmpdir([tablespace oid]) → setof record

Returns the name, size and modification time of each temporary file of a tablespace.

No equivalent.

pg_ls_waldir
^^^^^^^^^^^^

.. code-block:: text

  pg_ls_waldir() → setof record

Returns the name, size and modification time of each file in the WAL directory.

No equivalent.

pg_partition_ancestors
^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_partition_ancestors(regclass) → setof regclass

Returns a partition and the tables above it.

No equivalent.

pg_partition_root
^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_partition_root(regclass) → regclass

Returns the top table of the partition tree of a partition.

No equivalent.

pg_partition_tree
^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_partition_tree(regclass) → setof record

Returns a row for each table in the partition tree of a table.

No equivalent.

pg_promote
^^^^^^^^^^

.. code-block:: text

  pg_promote(wait boolean DEFAULT true, wait_seconds integer DEFAULT 60) → boolean

Promotes a standby server to a primary.

No equivalent.

pg_read_binary_file
^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_read_binary_file(filename text [, offset bigint, length bigint] [, missing_ok boolean]) → bytea

Returns the bytes of a file (or part of it) on the server.

No equivalent.

pg_read_file
^^^^^^^^^^^^

.. code-block:: text

  pg_read_file(filename text [, offset bigint, length bigint] [, missing_ok boolean]) → text

Returns the text of a file (or part of it) on the server.

No equivalent.

pg_relation_filenode
^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_relation_filenode(relation regclass) → oid

Returns the file node number of a table or index.

No equivalent.

pg_relation_filepath
^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_relation_filepath(relation regclass) → text

Returns the path of the file of a table or index.

No equivalent.

pg_relation_size
^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_relation_size(relation regclass [, fork text]) → bigint

Returns the disk space one fork of a table or index uses.

No equivalent.

pg_reload_conf
^^^^^^^^^^^^^^

.. code-block:: text

  pg_reload_conf() → boolean

Tells the server processes to reload the configuration files.

No equivalent.

pg_replication_origin_advance
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_replication_origin_advance(node_name text, lsn pg_lsn) → void

Sets how far a replication origin has replayed.

No equivalent.

pg_replication_origin_create
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_replication_origin_create(node_name text) → oid

Creates a replication origin.

No equivalent.

pg_replication_origin_drop
^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_replication_origin_drop(node_name text) → void

Drops a replication origin.

No equivalent.

pg_replication_origin_oid
^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_replication_origin_oid(node_name text) → oid

Returns the oid of a replication origin.

No equivalent.

pg_replication_origin_progress
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_replication_origin_progress(node_name text, flush boolean) → pg_lsn

Returns how far a replication origin has replayed.

No equivalent.

pg_replication_origin_session_is_setup
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_replication_origin_session_is_setup() → boolean

Tests if the session has a replication origin.

No equivalent.

pg_replication_origin_session_progress
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_replication_origin_session_progress(flush boolean) → pg_lsn

Returns how far the replication origin of the session has replayed.

No equivalent.

pg_replication_origin_session_reset
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_replication_origin_session_reset() → void

Clears the replication origin of the session.

No equivalent.

pg_replication_origin_session_setup
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_replication_origin_session_setup(node_name text) → void

Marks the session as replaying from a replication origin.

No equivalent.

pg_replication_origin_xact_reset
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_replication_origin_xact_reset() → void

Clears what pg_replication_origin_xact_setup set.

No equivalent.

pg_replication_origin_xact_setup
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_replication_origin_xact_setup(origin_lsn pg_lsn, origin_timestamp timestamp with time zone) → void

Sets the origin position and commit time of the current transaction.

No equivalent.

pg_replication_slot_advance
^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_replication_slot_advance(slot_name name, upto_lsn pg_lsn) → record

Moves a replication slot forward to a WAL position.

No equivalent.

pg_restore_attribute_stats
^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_restore_attribute_stats(VARIADIC kwargs "any") → boolean

Sets the planner statistics of a column.

No equivalent.

pg_restore_relation_stats
^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_restore_relation_stats(VARIADIC kwargs "any") → boolean

Sets the planner statistics of a table.

No equivalent.

pg_rotate_logfile
^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_rotate_logfile() → boolean

Tells the logging collector to start a new log file.

No equivalent.

pg_size_bytes
^^^^^^^^^^^^^

.. code-block:: text

  pg_size_bytes(text) → bigint

Converts a size such as 1 MB to a number of bytes.

No equivalent.

pg_size_pretty
^^^^^^^^^^^^^^

.. code-block:: text

  pg_size_pretty(bigint) → text
  pg_size_pretty(numeric) → text

Converts a number of bytes to a size for people to read, such as 1024 kB.

No equivalent.

pg_split_walfile_name
^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_split_walfile_name(file_name text) → record

Returns the segment number and timeline of a WAL file name.

No equivalent.

pg_stat_file
^^^^^^^^^^^^

.. code-block:: text

  pg_stat_file(filename text [, missing_ok boolean]) → record

Returns the size, times and type of a file on the server.

No equivalent.

pg_switch_wal
^^^^^^^^^^^^^

.. code-block:: text

  pg_switch_wal() → pg_lsn

Makes the server start a new WAL file.

No equivalent.

pg_sync_replication_slots
^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_sync_replication_slots() → void

Copies the failover logical replication slots of the primary to a standby.

No equivalent.

pg_table_size
^^^^^^^^^^^^^

.. code-block:: text

  pg_table_size(regclass) → bigint

Returns the disk space a table uses, without its indexes.

No equivalent.

vsql server (see :doc:`server`) has this function for its PostgreSQL clients only (flagged as ``V501-06``), and it returns ``NULL`` (the size isn't known).

pg_tablespace_size
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_tablespace_size(name) → bigint
  pg_tablespace_size(oid) → bigint

Returns the disk space a tablespace uses.

No equivalent.

pg_terminate_backend
^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_terminate_backend(pid integer, timeout bigint DEFAULT 0) → boolean

Ends the session of a server process.

No equivalent.

pg_total_relation_size
^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_total_relation_size(regclass) → bigint

Returns the disk space a table uses, with its indexes and TOAST data.

No equivalent.

vsql server (see :doc:`server`) has this function for its PostgreSQL clients only (flagged as ``V501-05``), and it returns ``NULL`` (the size isn't known).

pg_try_advisory_lock
^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_try_advisory_lock(key bigint) → boolean
  pg_try_advisory_lock(key1 integer, key2 integer) → boolean

Takes an exclusive advisory lock for the session if it is free, without waiting.

No equivalent.

pg_try_advisory_lock_shared
^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_try_advisory_lock_shared(key bigint) → boolean
  pg_try_advisory_lock_shared(key1 integer, key2 integer) → boolean

Takes a shared advisory lock for the session if it is free, without waiting.

No equivalent.

pg_try_advisory_xact_lock
^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_try_advisory_xact_lock(key bigint) → boolean
  pg_try_advisory_xact_lock(key1 integer, key2 integer) → boolean

Takes an exclusive advisory lock until the end of the transaction if it is free, without waiting.

No equivalent.

pg_try_advisory_xact_lock_shared
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_try_advisory_xact_lock_shared(key bigint) → boolean
  pg_try_advisory_xact_lock_shared(key1 integer, key2 integer) → boolean

Takes a shared advisory lock until the end of the transaction if it is free, without waiting.

No equivalent.

pg_wal_lsn_diff
^^^^^^^^^^^^^^^

.. code-block:: text

  pg_wal_lsn_diff(lsn1 pg_lsn, lsn2 pg_lsn) → numeric

Returns the number of bytes between two WAL positions.

No equivalent.

pg_wal_replay_pause
^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_wal_replay_pause() → void

Asks for the replay of the WAL to pause.

No equivalent.

pg_wal_replay_resume
^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_wal_replay_resume() → void

Resumes the replay of the WAL.

No equivalent.

pg_walfile_name
^^^^^^^^^^^^^^^

.. code-block:: text

  pg_walfile_name(lsn pg_lsn) → text

Returns the name of the WAL file that holds a position.

No equivalent.

pg_walfile_name_offset
^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_walfile_name_offset(lsn pg_lsn) → record

Returns the name of the WAL file that holds a position, and the offset in it.

No equivalent.

set_config
^^^^^^^^^^

.. code-block:: text

  set_config(setting_name text, new_value text, is_local boolean) → text

Sets a configuration parameter for the session or the transaction, and returns the new value.

No equivalent.

vsql server replies ``SET`` to a PostgreSQL ``SET`` of a parameter without running it (see :doc:`server`).

Trigger Functions
-----------------

vsql has no triggers.

suppress_redundant_updates_trigger
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  suppress_redundant_updates_trigger() → trigger

A trigger function that skips an update that doesn't change the row.

No equivalent.

tsvector_update_trigger
^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  tsvector_update_trigger() → trigger

A trigger function that fills a tsvector column from text columns, with a fixed configuration.

No equivalent.

tsvector_update_trigger_column
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  tsvector_update_trigger_column() → trigger

A trigger function that fills a tsvector column from text columns, with the configuration in another column.

No equivalent.

Event Trigger Functions
-----------------------

vsql has no event triggers.

pg_event_trigger_ddl_commands
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_event_trigger_ddl_commands() → setof record

Returns a row for each DDL command that an event trigger at the end of a command fires for.

No equivalent.

pg_event_trigger_dropped_objects
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_event_trigger_dropped_objects() → setof record

Returns a row for each object that a DDL command dropped.

No equivalent.

pg_event_trigger_table_rewrite_oid
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_event_trigger_table_rewrite_oid() → oid

Returns the oid of the table that is about to be rewritten.

No equivalent.

pg_event_trigger_table_rewrite_reason
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_event_trigger_table_rewrite_reason() → integer

Returns a bit mask of the reasons a table is about to be rewritten.

No equivalent.

Statistics Information Functions
--------------------------------

vsql has no extended statistics.

pg_mcv_list_items
^^^^^^^^^^^^^^^^^

.. code-block:: text

  pg_mcv_list_items(pg_mcv_list) → setof record

Returns a row for each item of a most common values list of extended statistics.

No equivalent.
