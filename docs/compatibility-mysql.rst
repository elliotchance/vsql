MySQL Functions
===============

.. contents::
   :local:
   :depth: 1

How to write the functions you know from MySQL 8.4 (LTS) in vsql. Every
built-in function of MySQL is here, in the same categories as the MySQL
reference manual, and each one can be linked to by its name, such as
``compatibility-mysql.html#ifnull``. Operators, such as ``DIV``, ``LIKE`` and
``->>``, aren't listed. Functions that have no equivalent in vsql are listed
too, so you can tell that they haven't been missed.

Moving from MySQL
-----------------

Each function shows the MySQL call with the names of its arguments, and below
it the same statement in vsql with each argument as a comment where its value
goes. An example follows, with its result in vsql:

.. code-block:: sql

  -- IFNULL(expr1, expr2)
  VALUES COALESCE(/*expr1*/, /*expr2*/);
  -- IFNULL(NULL, 'none')
  VALUES COALESCE(CAST(NULL AS VARCHAR(10)), 'none');
  -- COL1: none

When an optional argument changes the statement, each form has its own
statement and example. MySQL gives the same result for each example, apart
from how it's shown (see the notes after an example when it's more than that).

There are a few other differences to watch for:

- vsql doesn't convert between text and numbers by itself, so ``'1' + 2`` is
  an error rather than 3. Use ``CAST('1' AS INTEGER) + 2``. The same goes for
  dates: ``'2024-03-15'`` is text, so write ``DATE '2024-03-15'`` or
  ``CAST('2024-03-15' AS DATE)``.
- Dividing two integers gives an integer, so ``7 / 2`` is 3 rather than 3.5000
  (it's MySQL's ``7 DIV 2``). Write ``7 / 2.0`` or ``7 / 2e0`` to keep the
  fraction.
- A ``DOUBLE PRECISION`` result is shown with 12 significant digits and an
  exponent, so ``SQRT(2)`` is ``1.414213562373e0`` where MySQL shows
  ``1.4142135623730951``.
- Text is in single quotes (``'Apple'``). Double quotes are always for names
  of tables and columns, as with the ``ANSI_QUOTES`` mode of MySQL. Names that
  aren't quoted are upper case, which is why the results show ``COL1`` and
  ``NAME``.
- ``||`` joins text, as with the ``PIPES_AS_CONCAT`` mode of MySQL, rather
  than being ``OR``.
- Comparing text is case sensitive, so ``'abc' = 'ABC'`` is ``FALSE`` (in
  MySQL it's 1 with the default collation). Compare ``UPPER()`` of both sides
  to ignore the case.
- ``TRUE`` and ``FALSE`` are a ``BOOLEAN``, not the numbers 1 and 0, and a
  comparison such as ``ISNULL()`` gives a ``BOOLEAN``. Use
  ``CASE WHEN ... THEN 1 ELSE 0 END`` for a number.
- A bare ``NULL`` has no type, so it often has to be cast, such as
  ``CAST(NULL AS VARCHAR(10))``. Most functions return ``NULL`` when an
  argument is ``NULL``, as in MySQL.
- Where MySQL returns ``NULL`` (with a warning) for an argument that's out of
  range, vsql returns an error: dividing by zero is a ``22012`` error, and
  ``SQRT(-1)`` and ``LN(0)`` are errors too. Text that isn't a number, such as
  ``CAST('abc' AS INTEGER)``, is a ``22018`` error rather than 0 (see
  :doc:`sqlstate`).
- There's no ``INTERVAL`` or date arithmetic, so many of the date and time
  functions have no equivalent. ``EXTRACT`` takes a part of a date or time,
  such as its year or day of the week, and ``MAKE_TIME`` builds a time from its
  parts.
- vsql has no window functions (``OVER``). A subquery for each row gives the
  same result for many of them (see `Window Functions`_).

Example Tables
--------------

The examples that need a table use this one, which is the same as on
:doc:`compatibility-spreadsheet`:

.. code-block:: sql

  CREATE TABLE products (sku VARCHAR(10), name VARCHAR(20), price DECIMAL(10, 2), qty INTEGER);
  INSERT INTO products VALUES ('A1', 'Apple', 1.50, 10), ('B2', 'Banana', 0.25, 40), ('C3', 'Cherry', 4.00, 5), ('D4', 'Date', 3.00, NULL);

It's the same in MySQL.

Comparison Functions
--------------------

COALESCE
^^^^^^^^

Returns the first of its arguments that isn't ``NULL``.

.. code-block:: sql

  -- COALESCE(value, ...)
  VALUES COALESCE(/*value*/, ...);
  -- COALESCE(NULL, 'b', 'c')
  VALUES COALESCE(CAST(NULL AS VARCHAR(5)), 'b', 'c');
  -- COL1: b

GREATEST
^^^^^^^^

Returns the largest of its arguments.

.. code-block:: sql

  -- GREATEST(value1, value2, ...)
  VALUES GREATEST(/*value1*/, /*value2*/, ...);
  -- GREATEST(2, 34, 7)
  VALUES GREATEST(2, 34, 7);
  -- COL1: 34

As in MySQL, the result is ``NULL`` if any argument is ``NULL``.

INTERVAL
^^^^^^^^

Counts how many of a sorted list of numbers are less than or equal to a
number.

.. code-block:: sql

  -- INTERVAL(N, N1, N2, N3)
  VALUES CASE WHEN /*N*/ < /*N1*/ THEN 0 WHEN /*N*/ < /*N2*/ THEN 1 WHEN /*N*/ < /*N3*/ THEN 2 ELSE 3 END;
  -- INTERVAL(23, 1, 15, 30)
  VALUES CASE WHEN 23 < 1 THEN 0 WHEN 23 < 15 THEN 1 WHEN 23 < 30 THEN 2 ELSE 3 END;
  -- COL1: 2

Add a ``WHEN`` for each number of the list.

ISNULL
^^^^^^

Tells whether a value is ``NULL``.

.. code-block:: sql

  -- ISNULL(expr)
  VALUES /*expr*/ IS NULL;
  -- SELECT ISNULL(qty) FROM products WHERE sku = 'D4'
  SELECT qty IS NULL FROM products WHERE sku = 'D4';
  -- COL1: TRUE

The result is a ``BOOLEAN`` (``TRUE``) rather than 1.

LEAST
^^^^^

Returns the smallest of its arguments.

.. code-block:: sql

  -- LEAST(value1, value2, ...)
  VALUES LEAST(/*value1*/, /*value2*/, ...);
  -- LEAST('B', 'A', 'C')
  VALUES LEAST('B', 'A', 'C');
  -- COL1: A

As in MySQL, the result is ``NULL`` if any argument is ``NULL``.

Flow Control Functions
----------------------

IF
^^^

Returns one of two values, depending on whether a condition is true.

.. code-block:: sql

  -- IF(expr1, expr2, expr3)
  VALUES CASE WHEN /*expr1*/ THEN /*expr2*/ ELSE /*expr3*/ END;
  -- IF(1 < 2, 'yes', 'no')
  VALUES CASE WHEN 1 < 2 THEN 'yes' ELSE 'no' END;
  -- COL1: yes

The condition must be a ``BOOLEAN``. For a number, write ``x <> 0``.

IFNULL
^^^^^^

Returns the first value, or the second one when the first is ``NULL``.

.. code-block:: sql

  -- IFNULL(expr1, expr2)
  VALUES COALESCE(/*expr1*/, /*expr2*/);
  -- IFNULL(NULL, 'none')
  VALUES COALESCE(CAST(NULL AS VARCHAR(10)), 'none');
  -- COL1: none

NULLIF
^^^^^^

Returns ``NULL`` when two values are equal, otherwise the first one.

.. code-block:: sql

  -- NULLIF(expr1, expr2)
  VALUES NULLIF(/*expr1*/, /*expr2*/);
  -- NULLIF(1, 2)
  VALUES NULLIF(1, 2);
  -- COL1: 1

Numeric Functions
-----------------

ABS
^^^

Returns a number without its sign.

.. code-block:: sql

  -- ABS(X)
  VALUES ABS(/*X*/);
  -- ABS(-32)
  VALUES ABS(-32);
  -- COL1: 32

ACOS
^^^^

Returns the angle, in radians, whose cosine is a number.

.. code-block:: sql

  -- ACOS(X)
  VALUES ACOS(/*X*/);
  -- ACOS(0.5)
  VALUES ACOS(0.5);
  -- COL1: 1.047197551197e0

A number outside -1 to 1 is an error, where MySQL returns ``NULL``.

ASIN
^^^^

Returns the angle, in radians, whose sine is a number.

.. code-block:: sql

  -- ASIN(X)
  VALUES ASIN(/*X*/);
  -- ASIN(0.2)
  VALUES ASIN(0.2);
  -- COL1: 0.20135792079e0

A number outside -1 to 1 is an error, where MySQL returns ``NULL``.

ATAN
^^^^

Returns the angle, in radians, whose tangent is a number, or the angle of a
point from its two coordinates.

.. code-block:: sql

  -- ATAN(X)
  VALUES ATAN(/*X*/);
  -- ATAN(2)
  VALUES ATAN(2);
  -- COL1: 1.107148717794e0

  -- ATAN(Y, X)
  VALUES ATAN2(/*Y*/, /*X*/);
  -- ATAN(-2, 2)
  VALUES ATAN2(-2, 2);
  -- COL1: -0.785398163397e0

ATAN2
^^^^^

Returns the angle, in radians, of a point from its two coordinates.

.. code-block:: sql

  -- ATAN2(Y, X)
  VALUES ATAN2(/*Y*/, /*X*/);
  -- ATAN2(-2, 2)
  VALUES ATAN2(-2, 2);
  -- COL1: -0.785398163397e0

CEIL
^^^^

Rounds a number up to a whole number.

.. code-block:: sql

  -- CEIL(X)
  VALUES CEIL(/*X*/);
  -- CEIL(1.23)
  VALUES CEIL(1.23);
  -- COL1: 2

CEILING
^^^^^^^

Rounds a number up to a whole number.

.. code-block:: sql

  -- CEILING(X)
  VALUES CEILING(/*X*/);
  -- CEILING(-1.23)
  VALUES CEILING(-1.23);
  -- COL1: -1

CONV
^^^^

.. code-block:: text

  CONV(N, from_base, to_base)

Converts a number written in one base, from 2 to 36, into another base.

No equivalent.

COS
^^^

Returns the cosine of an angle in radians.

.. code-block:: sql

  -- COS(X)
  VALUES COS(/*X*/);
  -- COS(1)
  VALUES COS(1);
  -- COL1: 0.540302305868e0

COT
^^^

Returns the cotangent of an angle in radians.

.. code-block:: sql

  -- COT(X)
  VALUES 1 / TAN(/*X*/);
  -- COT(12)
  VALUES 1 / TAN(12);
  -- COL1: -1.572673406398e0

CRC32
^^^^^

.. code-block:: text

  CRC32(expr)

Returns the 32-bit cyclic redundancy check of a string.

No equivalent.

DEGREES
^^^^^^^

Converts an angle from radians to degrees.

.. code-block:: sql

  -- DEGREES(X)
  VALUES DEGREES(/*X*/);
  -- DEGREES(1)
  VALUES DEGREES(1);
  -- COL1: 57.295779513082e0

EXP
^^^

Returns e raised to the power of a number.

.. code-block:: sql

  -- EXP(X)
  VALUES EXP(/*X*/);
  -- EXP(2)
  VALUES EXP(2);
  -- COL1: 7.389056098931e0

FLOOR
^^^^^

Rounds a number down to a whole number.

.. code-block:: sql

  -- FLOOR(X)
  VALUES FLOOR(/*X*/);
  -- FLOOR(-1.23)
  VALUES FLOOR(-1.23);
  -- COL1: -2

LN
^^^

Returns the natural logarithm of a number.

.. code-block:: sql

  -- LN(X)
  VALUES LN(/*X*/);
  -- LN(2)
  VALUES LN(2);
  -- COL1: 0.69314718056e0

Zero or a negative number is an error, where MySQL returns ``NULL``.

LOG
^^^

Returns the natural logarithm of a number, or its logarithm to a base.

.. code-block:: sql

  -- LOG(X)
  VALUES LN(/*X*/);
  -- LOG(2)
  VALUES LN(2);
  -- COL1: 0.69314718056e0

  -- LOG(B, X)
  VALUES LOG(/*B*/, /*X*/);
  -- LOG(2, 65536)
  VALUES LOG(2, 65536);
  -- COL1: 16e0

With one argument, use ``LN``: vsql's ``LOG`` always has the base first.

LOG10
^^^^^

Returns the base-10 logarithm of a number.

.. code-block:: sql

  -- LOG10(X)
  VALUES LOG10(/*X*/);
  -- LOG10(100)
  VALUES LOG10(100);
  -- COL1: 2e0

LOG2
^^^^

Returns the base-2 logarithm of a number.

.. code-block:: sql

  -- LOG2(X)
  VALUES LOG(2, /*X*/);
  -- LOG2(65536)
  VALUES LOG(2, 65536);
  -- COL1: 16e0

MOD
^^^

Returns the remainder of dividing one number by another.

.. code-block:: sql

  -- MOD(N, M)
  VALUES MOD(/*N*/, /*M*/);
  -- MOD(234, 10)
  VALUES MOD(234, 10);
  -- COL1: 4

MySQL's ``%`` operator is ``MOD`` too. A remainder by zero is an error, where
MySQL returns ``NULL``.

PI
^^^

Returns the number pi.

.. code-block:: sql

  -- PI()
  VALUES PI();
  -- PI()
  VALUES PI();
  -- COL1: 3.14159265359e0

MySQL shows 6 decimal places (3.141593), but uses the full value.

POW
^^^

Raises a number to a power.

.. code-block:: sql

  -- POW(X, Y)
  VALUES POWER(/*X*/, /*Y*/);
  -- POW(2, 2)
  VALUES POWER(2, 2);
  -- COL1: 4e0

POWER
^^^^^

Raises a number to a power.

.. code-block:: sql

  -- POWER(X, Y)
  VALUES POWER(/*X*/, /*Y*/);
  -- POWER(2, -2)
  VALUES POWER(2, -2);
  -- COL1: 0.25e0

RADIANS
^^^^^^^

Converts an angle from degrees to radians.

.. code-block:: sql

  -- RADIANS(X)
  VALUES RADIANS(/*X*/);
  -- RADIANS(90)
  VALUES RADIANS(90);
  -- COL1: 1.570796326795e0

RAND
^^^^

Returns a random number from 0 up to, but not including, 1.

.. code-block:: sql

  -- RAND()
  VALUES RANDOM();
  -- RAND() < 1
  VALUES RANDOM() < 1;
  -- COL1: TRUE

There's no seed, so ``RAND(N)`` has no equivalent.

ROUND
^^^^^

Rounds a number to a number of decimal places.

.. code-block:: sql

  -- ROUND(X)
  VALUES ROUND(/*X*/);
  -- ROUND(-1.58)
  VALUES ROUND(-1.58);
  -- COL1: -2

  -- ROUND(X, D)
  VALUES ROUND(/*X*/, /*D*/);
  -- ROUND(1.298, 1)
  VALUES ROUND(1.298, 1);
  -- COL1: 1.3

SIGN
^^^^

Returns -1, 0 or 1 for a negative number, zero or a positive number.

.. code-block:: sql

  -- SIGN(X)
  VALUES SIGN(/*X*/);
  -- SIGN(-32)
  VALUES SIGN(-32);
  -- COL1: -1

SIN
^^^

Returns the sine of an angle in radians.

.. code-block:: sql

  -- SIN(X)
  VALUES SIN(/*X*/);
  -- SIN(1)
  VALUES SIN(1);
  -- COL1: 0.841470984808e0

SQRT
^^^^

Returns the square root of a number.

.. code-block:: sql

  -- SQRT(X)
  VALUES SQRT(/*X*/);
  -- SQRT(4)
  VALUES SQRT(4);
  -- COL1: 2e0

A negative number is an error, where MySQL returns ``NULL``.

TAN
^^^

Returns the tangent of an angle in radians.

.. code-block:: sql

  -- TAN(X)
  VALUES TAN(/*X*/);
  -- TAN(1)
  VALUES TAN(1);
  -- COL1: 1.557407724655e0

TRUNCATE
^^^^^^^^

Cuts a number down to a number of decimal places, without rounding.

.. code-block:: sql

  -- TRUNCATE(X, D)
  VALUES TRUNC(/*X*/, /*D*/);
  -- TRUNCATE(1.223, 1)
  VALUES TRUNC(1.223, 1);
  -- COL1: 1.2

Date and Time Functions
-----------------------

ADDDATE
^^^^^^^

.. code-block:: text

  ADDDATE(date, INTERVAL expr unit)

Adds an interval, or a number of days, to a date.

No equivalent.

ADDTIME
^^^^^^^

.. code-block:: text

  ADDTIME(expr1, expr2)

Adds a time to a time or to a date and time.

No equivalent.

CONVERT_TZ
^^^^^^^^^^

.. code-block:: text

  CONVERT_TZ(dt, from_tz, to_tz)

Converts a date and time from one time zone to another.

No equivalent.

CURDATE
^^^^^^^

Returns the current date.

.. code-block:: sql

  -- CURDATE()
  VALUES CURRENT_DATE;
  -- CURDATE() > '2020-01-01'
  VALUES CURRENT_DATE > DATE '2020-01-01';
  -- COL1: TRUE

There are no parentheses after ``CURRENT_DATE``.

CURRENT_DATE
^^^^^^^^^^^^

Returns the current date.

.. code-block:: sql

  -- CURRENT_DATE()
  VALUES CURRENT_DATE;
  -- CURRENT_DATE() > '2020-01-01'
  VALUES CURRENT_DATE > DATE '2020-01-01';
  -- COL1: TRUE

There are no parentheses after ``CURRENT_DATE``.

CURRENT_TIME
^^^^^^^^^^^^

Returns the current time.

.. code-block:: sql

  -- CURRENT_TIME()
  VALUES LOCALTIME;
  -- CURRENT_TIME() >= '00:00:00'
  VALUES LOCALTIME >= TIME '00:00:00';
  -- COL1: TRUE

vsql's ``CURRENT_TIME`` includes the time zone, so ``LOCALTIME`` is the one
that's the same as MySQL's.

CURRENT_TIMESTAMP
^^^^^^^^^^^^^^^^^

Returns the current date and time.

.. code-block:: sql

  -- CURRENT_TIMESTAMP()
  VALUES LOCALTIMESTAMP(0);
  -- CURRENT_TIMESTAMP() > '2020-01-01 00:00:00'
  VALUES LOCALTIMESTAMP(0) > TIMESTAMP '2020-01-01 00:00:00';
  -- COL1: TRUE

vsql's ``CURRENT_TIMESTAMP`` includes the time zone, so ``LOCALTIMESTAMP`` is
the one that's the same as MySQL's. The ``(0)`` leaves out the fractions of a
second, as MySQL does unless it's given a precision.

CURTIME
^^^^^^^

Returns the current time.

.. code-block:: sql

  -- CURTIME()
  VALUES LOCALTIME;
  -- CURTIME() >= '00:00:00'
  VALUES LOCALTIME >= TIME '00:00:00';
  -- COL1: TRUE

DATE
^^^^

Returns the date part of a date and time.

.. code-block:: sql

  -- DATE(expr)
  VALUES CAST(/*expr*/ AS DATE);
  -- DATE('2024-03-15 10:20:30')
  VALUES CAST(TIMESTAMP '2024-03-15 10:20:30' AS DATE);
  -- COL1: 2024-03-15

DATEDIFF
^^^^^^^^

Counts the days from one date to another.

.. code-block:: sql

  -- DATEDIFF(expr1, expr2)
  VALUES (EXTRACT(EPOCH FROM CAST(/*expr1*/ AS DATE)) - EXTRACT(EPOCH FROM CAST(/*expr2*/ AS DATE))) / 86400;
  -- DATEDIFF('2024-03-15 23:00:00', '2024-03-01 08:00:00')
  VALUES (EXTRACT(EPOCH FROM CAST(TIMESTAMP '2024-03-15 23:00:00' AS DATE))
    - EXTRACT(EPOCH FROM CAST(TIMESTAMP '2024-03-01 08:00:00' AS DATE))) / 86400;
  -- COL1: 14.0000000000000000

The cast to ``DATE`` leaves out the time, as MySQL does.

DATE_ADD
^^^^^^^^

.. code-block:: text

  DATE_ADD(date, INTERVAL expr unit)

Adds an interval to a date or a date and time.

No equivalent.

DATE_FORMAT
^^^^^^^^^^^

Formats a date as text, following a pattern of format specifiers.

.. code-block:: sql

  -- DATE_FORMAT(date, format)
  VALUES CAST(/*date*/ AS VARCHAR(/*length*/) FORMAT /*format*/);
  -- DATE_FORMAT('2024-03-15 10:30:00', '%Y-%m-%d %H:%i')
  VALUES CAST(TIMESTAMP '2024-03-15 10:30:00' AS VARCHAR(16) FORMAT 'YYYY-MM-DD HH24:MI');
  -- COL1: 2024-03-15 10:30

To round a date down to the start of a month (``DATE_FORMAT(d, '%Y-%m-01')``) or another unit, use ``DATE_TRUNC('month', d)``, which keeps the type of the value.

The format is the SQL standard's ``FORMAT`` (see :doc:`dates-times`), where ``%Y`` is ``YYYY``, ``%y`` is ``YY``, ``%m`` is ``MM``, ``%d`` is ``DD``, ``%j`` is ``DDD``, ``%H`` is ``HH24``, ``%h`` is ``HH12``, ``%i`` is ``MI``, ``%s`` is ``SS``, ``%f`` is ``FF6`` and ``%p`` is ``A.M.``. There are no names of months or days.

DATE_SUB
^^^^^^^^

.. code-block:: text

  DATE_SUB(date, INTERVAL expr unit)

Subtracts an interval from a date or a date and time.

No equivalent.

DAY
^^^

Returns the day of the month of a date, from 1 to 31.

.. code-block:: sql

  -- DAY(date)
  VALUES EXTRACT(DAY FROM /*date*/);
  -- DAY('2024-03-05')
  VALUES EXTRACT(DAY FROM DATE '2024-03-05');
  -- COL1: 5

DAYNAME
^^^^^^^

.. code-block:: text

  DAYNAME(date)

Returns the name of the day of the week of a date.

No equivalent.

DAYOFMONTH
^^^^^^^^^^

Returns the day of the month of a date, from 1 to 31.

.. code-block:: sql

  -- DAYOFMONTH(date)
  VALUES EXTRACT(DAY FROM /*date*/);
  -- DAYOFMONTH('2024-03-05')
  VALUES EXTRACT(DAY FROM DATE '2024-03-05');
  -- COL1: 5

DAYOFWEEK
^^^^^^^^^

Returns the day of the week of a date, from 1 for Sunday to 7 for Saturday.

.. code-block:: sql

  -- DAYOFWEEK(date)
  VALUES EXTRACT(DOW FROM /*date*/) + 1;
  -- DAYOFWEEK('2024-03-05')
  VALUES EXTRACT(DOW FROM DATE '2024-03-05') + 1;
  -- COL1: 3

vsql's ``DOW`` counts from 0 for Sunday.

DAYOFYEAR
^^^^^^^^^

Returns the day of the year of a date, from 1 to 366.

.. code-block:: sql

  -- DAYOFYEAR(date)
  VALUES EXTRACT(DOY FROM /*date*/);
  -- DAYOFYEAR('2024-03-05')
  VALUES EXTRACT(DOY FROM DATE '2024-03-05');
  -- COL1: 65

EXTRACT
^^^^^^^

Returns one part of a date or time, such as its year.

.. code-block:: sql

  -- EXTRACT(unit FROM date)
  VALUES EXTRACT(/*unit*/ FROM /*date*/);
  -- EXTRACT(YEAR FROM '2024-03-05')
  VALUES EXTRACT(YEAR FROM DATE '2024-03-05');
  -- COL1: 2024

The value must be a ``DATE``, ``TIME`` or ``TIMESTAMP``, not text, and it must
have the part: a ``DATE`` has no ``HOUR``. Some units differ:

- ``WEEK`` in MySQL counts weeks that start on a Sunday, as `WEEK`_ does. In
  vsql it's the ISO 8601 week, as `WEEKOFYEAR`_ is.
- ``SECOND`` keeps the fraction of a second in vsql, MySQL leaves it out.
  ``MICROSECOND`` is written as in `MICROSECOND`_.
- The units made of two parts, such as ``YEAR_MONTH`` or ``DAY_SECOND``, have
  no equivalent.

FROM_DAYS
^^^^^^^^^

.. code-block:: text

  FROM_DAYS(N)

Returns the date that is a number of days after year 0.

No equivalent.

FROM_UNIXTIME
^^^^^^^^^^^^^

.. code-block:: text

  FROM_UNIXTIME(unix_timestamp[, format])

Converts a number of seconds since 1970-01-01 00:00:00 UTC into a date and time.

No equivalent.

GET_FORMAT
^^^^^^^^^^

.. code-block:: text

  GET_FORMAT({DATE 

 TIME | DATETIME}, {'EUR' | 'USA' | 'JIS' | 'ISO' | 'INTERNAL'})|Returns the format string that a region uses for dates or times, for use with DATE_FORMAT.

No equivalent.

HOUR
^^^^

Returns the hour of a time.

.. code-block:: sql

  -- HOUR(time)
  VALUES EXTRACT(HOUR FROM /*time*/);
  -- HOUR('10:05:03')
  VALUES EXTRACT(HOUR FROM TIME '10:05:03');
  -- COL1: 10

A MySQL ``TIME`` can be more than 24 hours, a vsql one can't.

LAST_DAY
^^^^^^^^

.. code-block:: text

  LAST_DAY(date)

Returns the last day of the month of a date.

No equivalent.

LOCALTIME
^^^^^^^^^

Returns the current date and time.

.. code-block:: sql

  -- LOCALTIME()
  VALUES LOCALTIMESTAMP(0);
  -- LOCALTIME() > '2020-01-01 00:00:00'
  VALUES LOCALTIMESTAMP(0) > TIMESTAMP '2020-01-01 00:00:00';
  -- COL1: TRUE

MySQL's ``LOCALTIME`` is a date and time, but vsql's is only the time, so use
``LOCALTIMESTAMP``.

LOCALTIMESTAMP
^^^^^^^^^^^^^^

Returns the current date and time.

.. code-block:: sql

  -- LOCALTIMESTAMP()
  VALUES LOCALTIMESTAMP(0);
  -- LOCALTIMESTAMP() > '2020-01-01 00:00:00'
  VALUES LOCALTIMESTAMP(0) > TIMESTAMP '2020-01-01 00:00:00';
  -- COL1: TRUE

MAKEDATE
^^^^^^^^

.. code-block:: text

  MAKEDATE(year, dayofyear)

Builds a date from a year and a day of the year.

No equivalent.

MAKETIME
^^^^^^^^

Builds a time from an hour, a minute and a second.

.. code-block:: sql

  -- MAKETIME(hour, minute, second)
  VALUES MAKE_TIME(/*hour*/, /*minute*/, /*second*/);
  -- MAKETIME(12, 15, 30)
  VALUES MAKE_TIME(12, 15, 30);
  -- COL1: 12:15:30.000000

The result is a ``TIME(6)``, so it always has 6 decimal places of seconds;
cast it to ``TIME(0)`` to leave them out. The hour must be from 0 to 23, and a
minute or second out of range is an error, rather than ``NULL`` in MySQL.

MICROSECOND
^^^^^^^^^^^

Returns the microseconds of a time.

.. code-block:: sql

  -- MICROSECOND(expr)
  VALUES CAST(MOD(EXTRACT(SECOND FROM /*expr*/) * 1000000, 1000000) AS INTEGER);
  -- MICROSECOND('12:00:00.123456')
  VALUES CAST(MOD(EXTRACT(SECOND FROM TIME '12:00:00.123456') * 1000000, 1000000) AS INTEGER);
  -- COL1: 123456

MINUTE
^^^^^^

Returns the minute of a time, from 0 to 59.

.. code-block:: sql

  -- MINUTE(time)
  VALUES EXTRACT(MINUTE FROM /*time*/);
  -- MINUTE('10:05:03')
  VALUES EXTRACT(MINUTE FROM TIME '10:05:03');
  -- COL1: 5

MONTH
^^^^^

Returns the month of a date, from 1 to 12.

.. code-block:: sql

  -- MONTH(date)
  VALUES EXTRACT(MONTH FROM /*date*/);
  -- MONTH('2024-03-05')
  VALUES EXTRACT(MONTH FROM DATE '2024-03-05');
  -- COL1: 3

MONTHNAME
^^^^^^^^^

.. code-block:: text

  MONTHNAME(date)

Returns the name of the month of a date.

No equivalent.

NOW
^^^

Returns the current date and time.

.. code-block:: sql

  -- NOW()
  VALUES LOCALTIMESTAMP(0);
  -- NOW() > '2020-01-01 00:00:00'
  VALUES LOCALTIMESTAMP(0) > TIMESTAMP '2020-01-01 00:00:00';
  -- COL1: TRUE

vsql's ``NOW()`` is a different function: it includes the time zone and it
reads the clock each time it's called (see `SYSDATE`_). ``LOCALTIMESTAMP`` is
the time the statement started, as MySQL's ``NOW()`` is. For ``NOW(fsp)``,
write ``LOCALTIMESTAMP(fsp)``.

PERIOD_ADD
^^^^^^^^^^

Adds a number of months to a period written as a number ``YYYYMM``.

.. code-block:: sql

  -- PERIOD_ADD(P, N)
  VALUES (/*P*/ / 100 * 12 + MOD(/*P*/, 100) - 1 + /*N*/) / 12 * 100 + MOD(/*P*/ / 100 * 12 + MOD(/*P*/, 100) - 1 + /*N*/, 12) + 1;
  -- PERIOD_ADD(202311, 3)
  VALUES (202311 / 100 * 12 + MOD(202311, 100) - 1 + 3) / 12 * 100
    + MOD(202311 / 100 * 12 + MOD(202311, 100) - 1 + 3, 12) + 1;
  -- COL1: 202402

This counts the months since year 0, adds ``N`` and turns them back into
``YYYYMM``. MySQL also takes a two-digit year (``YYMM``), which this doesn't.

PERIOD_DIFF
^^^^^^^^^^^

Counts the months from one period, written as a number ``YYYYMM``, to another.

.. code-block:: sql

  -- PERIOD_DIFF(P1, P2)
  VALUES (/*P1*/ / 100 * 12 + MOD(/*P1*/, 100)) - (/*P2*/ / 100 * 12 + MOD(/*P2*/, 100));
  -- PERIOD_DIFF(202403, 202310)
  VALUES (202403 / 100 * 12 + MOD(202403, 100)) - (202310 / 100 * 12 + MOD(202310, 100));
  -- COL1: 5

QUARTER
^^^^^^^

Returns the quarter of the year of a date, from 1 to 4.

.. code-block:: sql

  -- QUARTER(date)
  VALUES EXTRACT(QUARTER FROM /*date*/);
  -- QUARTER('2024-08-05')
  VALUES EXTRACT(QUARTER FROM DATE '2024-08-05');
  -- COL1: 3

SECOND
^^^^^^

Returns the second of a time, from 0 to 59.

.. code-block:: sql

  -- SECOND(time)
  VALUES EXTRACT(SECOND FROM /*time*/);
  -- SECOND('10:05:03')
  VALUES EXTRACT(SECOND FROM TIME '10:05:03');
  -- COL1: 3

vsql keeps the fraction of a second, such as 3.75 for ``TIME '10:05:03.75'``,
where MySQL returns 3. Use ``FLOOR()`` to leave it out.

SEC_TO_TIME
^^^^^^^^^^^

Turns a number of seconds into a time.

.. code-block:: sql

  -- SEC_TO_TIME(seconds)
  VALUES CAST(MAKE_TIME(/*seconds*/ / 3600, MOD(/*seconds*/ / 60, 60), MOD(/*seconds*/, 60)) AS TIME(0));
  -- SEC_TO_TIME(2378)
  VALUES CAST(MAKE_TIME(2378 / 3600, MOD(2378 / 60, 60), MOD(2378, 60)) AS TIME(0));
  -- COL1: 00:39:38

This only works for less than 24 hours (86400 seconds), and for whole seconds.

STR_TO_DATE
^^^^^^^^^^^

Reads a date, a time or both from text, following a pattern of format specifiers.

.. code-block:: sql

  -- STR_TO_DATE(str, format)
  VALUES CAST(/*str*/ AS TIMESTAMP(0) FORMAT /*format*/);
  -- STR_TO_DATE('15/03/2024 10:30', '%d/%m/%Y %H:%i')
  VALUES CAST('15/03/2024 10:30' AS TIMESTAMP(0) FORMAT 'DD/MM/YYYY HH24:MI');
  -- COL1: 2024-03-15T10:30:00

The type (``DATE``, ``TIME`` or ``TIMESTAMP``) is part of the cast, rather than depending on the format. The format is the SQL standard's ``FORMAT`` (see :doc:`dates-times`), where ``%Y`` is ``YYYY``, ``%y`` is ``YY``, ``%m`` is ``MM``, ``%d`` is ``DD``, ``%j`` is ``DDD``, ``%H`` is ``HH24``, ``%h`` is ``HH12``, ``%i`` is ``MI``, ``%s`` is ``SS``, ``%f`` is ``FF6`` and ``%p`` is ``A.M.``. There are no names of months or days.

SUBDATE
^^^^^^^

.. code-block:: text

  SUBDATE(date, INTERVAL expr unit)

Subtracts an interval, or a number of days, from a date.

No equivalent.

SUBTIME
^^^^^^^

.. code-block:: text

  SUBTIME(expr1, expr2)

Subtracts a time from a time or from a date and time.

No equivalent.

SYSDATE
^^^^^^^

Returns the date and time at the moment the function runs.

.. code-block:: sql

  -- SYSDATE()
  VALUES CAST(NOW() AS TIMESTAMP(0));
  -- SYSDATE() > '2020-01-01 00:00:00'
  VALUES CAST(NOW() AS TIMESTAMP(0)) > TIMESTAMP '2020-01-01 00:00:00';
  -- COL1: TRUE

vsql's ``NOW()`` reads the clock each time it's called, like MySQL's
``SYSDATE()``, but it includes the time zone, which the cast leaves out.

TIME
^^^^

Returns the time part of a date and time.

.. code-block:: sql

  -- TIME(expr)
  VALUES CAST(/*expr*/ AS TIME);
  -- TIME('2024-03-15 10:20:30')
  VALUES CAST(TIMESTAMP '2024-03-15 10:20:30' AS TIME);
  -- COL1: 10:20:30

TIMEDIFF
^^^^^^^^

.. code-block:: text

  TIMEDIFF(expr1, expr2)

Returns the time between two times, or two dates and times.

No equivalent.

TIMESTAMP
^^^^^^^^^

Turns a date, or text, into a date and time.

.. code-block:: sql

  -- TIMESTAMP(expr)
  VALUES CAST(/*expr*/ AS TIMESTAMP(0));
  -- TIMESTAMP('2024-03-15')
  VALUES CAST(DATE '2024-03-15' AS TIMESTAMP(0));
  -- COL1: 2024-03-15T00:00:00

A ``TIMESTAMP`` is shown with a ``T`` between the date and the time. There's
no equivalent of ``TIMESTAMP(expr1, expr2)``, which adds a time to it.

TIMESTAMPADD
^^^^^^^^^^^^

.. code-block:: text

  TIMESTAMPADD(unit, interval, datetime_expr)

Adds a number of units, such as days or hours, to a date and time.

No equivalent.

TIMESTAMPDIFF
^^^^^^^^^^^^^

.. code-block:: text

  TIMESTAMPDIFF(unit, datetime_expr1, datetime_expr2)

Counts the whole units, such as days or months, between two dates and times.

No equivalent.

TIME_FORMAT
^^^^^^^^^^^

Formats a time as text, following a pattern of format specifiers.

.. code-block:: sql

  -- TIME_FORMAT(time, format)
  VALUES CAST(/*time*/ AS VARCHAR(/*length*/) FORMAT /*format*/);
  -- TIME_FORMAT('22:23:00', '%h:%i %p')
  VALUES CAST(TIME '22:23:00' AS VARCHAR(10) FORMAT 'HH12:MI A.M.');
  -- COL1: 10:23 P.M.

The format is the SQL standard's ``FORMAT`` (see :doc:`dates-times`), where ``%Y`` is ``YYYY``, ``%y`` is ``YY``, ``%m`` is ``MM``, ``%d`` is ``DD``, ``%j`` is ``DDD``, ``%H`` is ``HH24``, ``%h`` is ``HH12``, ``%i`` is ``MI``, ``%s`` is ``SS``, ``%f`` is ``FF6`` and ``%p`` is ``A.M.``. There are no names of months or days. An hour over 23 can't be formatted, since a ``TIME`` is a time of day.

TIME_TO_SEC
^^^^^^^^^^^

Turns a time into a number of seconds.

.. code-block:: sql

  -- TIME_TO_SEC(time)
  VALUES EXTRACT(HOUR FROM /*time*/) * 3600 + EXTRACT(MINUTE FROM /*time*/) * 60 + EXTRACT(SECOND FROM /*time*/);
  -- TIME_TO_SEC('22:23:00')
  VALUES EXTRACT(HOUR FROM TIME '22:23:00') * 3600 + EXTRACT(MINUTE FROM TIME '22:23:00') * 60
    + EXTRACT(SECOND FROM TIME '22:23:00');
  -- COL1: 80580

A fraction of a second is kept, where MySQL leaves it out.

TO_DAYS
^^^^^^^

Counts the days from year 0 to a date.

.. code-block:: sql

  -- TO_DAYS(date)
  VALUES EXTRACT(EPOCH FROM /*date*/) / 86400 + 719528;
  -- TO_DAYS('2024-03-05')
  VALUES EXTRACT(EPOCH FROM DATE '2024-03-05') / 86400 + 719528;
  -- COL1: 739315.0000000000000000

719528 is ``TO_DAYS('1970-01-01')``, the day that ``EPOCH`` counts seconds
from. Cast a ``TIMESTAMP`` to ``DATE`` first.

TO_SECONDS
^^^^^^^^^^

Counts the seconds from year 0 to a date and time.

.. code-block:: sql

  -- TO_SECONDS(expr)
  VALUES EXTRACT(EPOCH FROM /*expr*/) + 62167219200;
  -- TO_SECONDS('2024-03-05 10:20:30')
  VALUES EXTRACT(EPOCH FROM TIMESTAMP '2024-03-05 10:20:30') + 62167219200;
  -- COL1: 63876853230

62167219200 is ``TO_SECONDS('1970-01-01')``. A fraction of a second is kept,
where MySQL leaves it out.

UNIX_TIMESTAMP
^^^^^^^^^^^^^^

Returns the number of seconds since 1970-01-01 00:00:00 UTC, now or at a date and time.

.. code-block:: sql

  -- UNIX_TIMESTAMP()
  VALUES FLOOR(EXTRACT(EPOCH FROM CURRENT_TIMESTAMP(0)));
  -- UNIX_TIMESTAMP() > 1577836800
  VALUES FLOOR(EXTRACT(EPOCH FROM CURRENT_TIMESTAMP(0))) > 1577836800;
  -- COL1: TRUE

.. code-block:: sql

  -- UNIX_TIMESTAMP(date)
  VALUES EXTRACT(EPOCH FROM /*date*/);
  -- UNIX_TIMESTAMP('2024-03-05 10:20:30')
  VALUES EXTRACT(EPOCH FROM TIMESTAMP '2024-03-05 10:20:30');
  -- COL1: 1709634030

MySQL reads a date and time in the time zone of the session, but vsql takes a
``DATE`` or ``TIMESTAMP`` to be UTC, so they're the same only when the session
is in UTC. Give a ``TIMESTAMP WITH TIME ZONE`` for any other time zone.

UTC_DATE
^^^^^^^^

.. code-block:: text

  UTC_DATE()

Returns the current date in UTC.

No equivalent.

UTC_TIME
^^^^^^^^

.. code-block:: text

  UTC_TIME([fsp])

Returns the current time in UTC.

No equivalent.

UTC_TIMESTAMP
^^^^^^^^^^^^^

.. code-block:: text

  UTC_TIMESTAMP([fsp])

Returns the current date and time in UTC.

No equivalent.

WEEK
^^^^

Returns the week number of a date, counted in one of several ways.

.. code-block:: sql

  -- WEEK(date)
  VALUES (EXTRACT(DOY FROM /*date*/) - EXTRACT(DOW FROM /*date*/) + 6) / 7;
  -- WEEK('2024-03-05')
  VALUES (EXTRACT(DOY FROM DATE '2024-03-05') - EXTRACT(DOW FROM DATE '2024-03-05') + 6) / 7;
  -- COL1: 9

.. code-block:: sql

  -- WEEK(date, 3)
  VALUES EXTRACT(WEEK FROM /*date*/);
  -- WEEK('2027-01-01', 3)
  VALUES EXTRACT(WEEK FROM DATE '2027-01-01');
  -- COL1: 53

Without a mode, MySQL uses ``default_week_format``, which is 0: weeks start on
a Sunday, and the days before the first Sunday of the year are in week 0. That
is what the first statement counts, from the day of the year and the day of
the week. Mode 3 is the ISO 8601 week, which is vsql's ``WEEK``. The other
modes have no equivalent.

WEEKDAY
^^^^^^^

Returns the day of the week of a date, from 0 for Monday to 6 for Sunday.

.. code-block:: sql

  -- WEEKDAY(date)
  VALUES EXTRACT(ISODOW FROM /*date*/) - 1;
  -- WEEKDAY('2024-03-05')
  VALUES EXTRACT(ISODOW FROM DATE '2024-03-05') - 1;
  -- COL1: 1

WEEKOFYEAR
^^^^^^^^^^

Returns the week of the year of a date, from 1 to 53, as ISO 8601 counts weeks.

.. code-block:: sql

  -- WEEKOFYEAR(date)
  VALUES EXTRACT(WEEK FROM /*date*/);
  -- WEEKOFYEAR('2027-01-01')
  VALUES EXTRACT(WEEK FROM DATE '2027-01-01');
  -- COL1: 53

A week starts on a Monday and belongs to the year of its Thursday, so January
1, 2027 is in week 53 of 2026.

YEAR
^^^^

Returns the year of a date.

.. code-block:: sql

  -- YEAR(date)
  VALUES EXTRACT(YEAR FROM /*date*/);
  -- YEAR('2024-03-05')
  VALUES EXTRACT(YEAR FROM DATE '2024-03-05');
  -- COL1: 2024

YEARWEEK
^^^^^^^^

Returns the year and the week number of a date as one number, such as 202410.

.. code-block:: sql

  -- YEARWEEK(date, 3)
  VALUES EXTRACT(ISOYEAR FROM /*date*/) * 100 + EXTRACT(WEEK FROM /*date*/);
  -- YEARWEEK('2027-01-01', 3)
  VALUES EXTRACT(ISOYEAR FROM DATE '2027-01-01') * 100 + EXTRACT(WEEK FROM DATE '2027-01-01');
  -- COL1: 202653

Mode 3 is the ISO 8601 week, and its year can be the one before or after the
year of the date. The other modes, including the default (0), have no
equivalent.

String Functions
----------------

ASCII
^^^^^

Returns the code of the first character of a string.

.. code-block:: sql

  -- ASCII(str)
  VALUES UNICODE(/*str*/);
  -- ASCII('dx')
  VALUES UNICODE('dx');
  -- COL1: 100

``UNICODE`` returns the code point of the character, where MySQL returns its
first byte, so they differ for characters past 127 (``ASCII('é')`` is 195,
``UNICODE('é')`` is 233). An empty string is ``NULL`` rather than 0.

BIN
^^^

.. code-block:: text

  BIN(N)

Returns a number written in binary, as a string.

No equivalent.

BIT_LENGTH
^^^^^^^^^^

Returns the length of a string in bits.

.. code-block:: sql

  -- BIT_LENGTH(str)
  VALUES OCTET_LENGTH(/*str*/) * 8;
  -- BIT_LENGTH('text')
  VALUES OCTET_LENGTH('text') * 8;
  -- COL1: 32

CHAR
^^^^

Builds a string from the codes of its characters.

.. code-block:: sql

  -- CHAR(N, ...)
  VALUES CHR(/*N*/) || ...;
  -- CHAR(77, 121, 83, 81, 76)
  VALUES CHR(77) || CHR(121) || CHR(83) || CHR(81) || CHR(76);
  -- COL1: MySQL

``CHR`` takes a Unicode code point. MySQL's ``CHAR`` returns a binary string of
bytes, and a number over 255 is several bytes.

CHARACTER_LENGTH
^^^^^^^^^^^^^^^^

Returns the number of characters in a string.

.. code-block:: sql

  -- CHARACTER_LENGTH(str)
  VALUES CHARACTER_LENGTH(/*str*/);
  -- CHARACTER_LENGTH('héllo')
  VALUES CHARACTER_LENGTH('héllo');
  -- COL1: 5

CHAR_LENGTH
^^^^^^^^^^^

Returns the number of characters in a string.

.. code-block:: sql

  -- CHAR_LENGTH(str)
  VALUES CHAR_LENGTH(/*str*/);
  -- CHAR_LENGTH('héllo')
  VALUES CHAR_LENGTH('héllo');
  -- COL1: 5

CONCAT
^^^^^^

Joins strings together.

.. code-block:: sql

  -- CONCAT(str1, str2, ...)
  VALUES CONCAT(/*str1*/, /*str2*/, ...);
  -- CONCAT('My', 'S', 'QL')
  VALUES CONCAT('My', 'S', 'QL');
  -- COL1: MySQL

Unlike MySQL, a ``NULL`` is left out rather than making the result ``NULL``.
Use ``||`` (``'My' || 'S' || 'QL'``) for a result that's ``NULL`` if any of
them is. A number must be cast to text first, such as
``CAST(14.3 AS VARCHAR(10))``.

CONCAT_WS
^^^^^^^^^

Joins strings together with a separator between them, skipping the ones that
are ``NULL``.

.. code-block:: sql

  -- CONCAT_WS(separator, str1, str2, ...)
  VALUES CONCAT_WS(/*separator*/, /*str1*/, /*str2*/, ...);
  -- CONCAT_WS(',', 'First name', 'Last Name')
  VALUES CONCAT_WS(',', 'First name', 'Last Name');
  -- COL1: First name,Last Name

ELT
^^^

Returns the string at a position of a list.

.. code-block:: sql

  -- ELT(N, str1, str2, str3)
  VALUES CASE /*N*/ WHEN 1 THEN /*str1*/ WHEN 2 THEN /*str2*/ WHEN 3 THEN /*str3*/ END;
  -- ELT(2, 'Aa', 'Bb', 'Cc')
  VALUES CASE 2 WHEN 1 THEN 'Aa' WHEN 2 THEN 'Bb' WHEN 3 THEN 'Cc' END;
  -- COL1: Bb

Add a ``WHEN`` for each string of the list.

EXPORT_SET
^^^^^^^^^^

.. code-block:: text

  EXPORT_SET(bits, on, off[, separator[, number_of_bits]])

Returns a string with one word for each bit of a number, one word for the bits that are set and another for the bits that aren't.

No equivalent.

FIELD
^^^^^

Returns the position of a string in a list, or 0 if it's not there.

.. code-block:: sql

  -- FIELD(str, str1, str2, str3)
  VALUES CASE /*str*/ WHEN /*str1*/ THEN 1 WHEN /*str2*/ THEN 2 WHEN /*str3*/ THEN 3 ELSE 0 END;
  -- FIELD('Bb', 'Aa', 'Bb', 'Cc')
  VALUES CASE 'Bb' WHEN 'Aa' THEN 1 WHEN 'Bb' THEN 2 WHEN 'Cc' THEN 3 ELSE 0 END;
  -- COL1: 2

Add a ``WHEN`` for each string of the list.

FIND_IN_SET
^^^^^^^^^^^

Returns the position of a string in a list separated by commas, or 0 if it's
not there.

.. code-block:: sql

  -- FIND_IN_SET(str, strlist)
  VALUES CASE /*str*/ WHEN SPLIT_PART(/*strlist*/, ',', 1) THEN 1 WHEN SPLIT_PART(/*strlist*/, ',', 2) THEN 2 WHEN SPLIT_PART(/*strlist*/, ',', 3) THEN 3 ELSE 0 END;
  -- FIND_IN_SET('b', 'a,b,c')
  VALUES CASE 'b' WHEN SPLIT_PART('a,b,c', ',', 1) THEN 1 WHEN SPLIT_PART('a,b,c', ',', 2) THEN 2
    WHEN SPLIT_PART('a,b,c', ',', 3) THEN 3 ELSE 0 END;
  -- COL1: 2

Add a ``WHEN`` for each item that the list can have.

FORMAT
^^^^^^

.. code-block:: text

  FORMAT(X, D[, locale])

Rounds a number to a number of decimal places and writes it with a separator between each group of thousands.

No equivalent.

FROM_BASE64
^^^^^^^^^^^

.. code-block:: text

  FROM_BASE64(str)

Decodes a base-64 string.

No equivalent.

HEX
^^^

.. code-block:: text

  HEX(str)

Returns a number, or each byte of a string, written in hexadecimal.

No equivalent.

INSERT
^^^^^^

Replaces part of a string, from a position and for a length, with another
string.

.. code-block:: sql

  -- INSERT(str, pos, len, newstr)
  VALUES OVERLAY(/*str*/ PLACING /*newstr*/ FROM /*pos*/ FOR /*len*/);
  -- INSERT('Quadratic', 3, 4, 'What')
  VALUES OVERLAY('Quadratic' PLACING 'What' FROM 3 FOR 4);
  -- COL1: QuWhattic

INSTR
^^^^^

Returns the position of the first time a substring appears in a string, or 0.

.. code-block:: sql

  -- INSTR(str, substr)
  VALUES POSITION(/*substr*/ IN /*str*/);
  -- INSTR('foobarbar', 'bar')
  VALUES POSITION('bar' IN 'foobarbar');
  -- COL1: 4

The comparison is case sensitive in vsql.

LCASE
^^^^^

Converts a string to lower case.

.. code-block:: sql

  -- LCASE(str)
  VALUES LOWER(/*str*/);
  -- LCASE('MySQL')
  VALUES LOWER('MySQL');
  -- COL1: mysql

LEFT
^^^^

Returns a number of characters from the start of a string.

.. code-block:: sql

  -- LEFT(str, len)
  VALUES SUBSTRING(/*str*/ FROM 1 FOR /*len*/);
  -- LEFT('foobarbar', 5)
  VALUES SUBSTRING('foobarbar' FROM 1 FOR 5);
  -- COL1: fooba

LENGTH
^^^^^^

Returns the length of a string in bytes.

.. code-block:: sql

  -- LENGTH(str)
  VALUES OCTET_LENGTH(/*str*/);
  -- LENGTH('héllo')
  VALUES OCTET_LENGTH('héllo');
  -- COL1: 6

Use ``CHAR_LENGTH`` (or ``LENGTH``) for the number of characters. vsql's
``LENGTH`` counts characters, not bytes, like ``CHAR_LENGTH``, so it can't be
used for MySQL's ``LENGTH``.

LOAD_FILE
^^^^^^^^^

.. code-block:: text

  LOAD_FILE(file_name)

Reads a file on the server and returns its contents.

No equivalent.

LOCATE
^^^^^^

Returns the position of the first time a substring appears in a string, or 0,
optionally starting from a position.

.. code-block:: sql

  -- LOCATE(substr, str)
  VALUES POSITION(/*substr*/ IN /*str*/);
  -- LOCATE('bar', 'foobarbar')
  VALUES POSITION('bar' IN 'foobarbar');
  -- COL1: 4

  -- LOCATE(substr, str, pos)
  VALUES CASE POSITION(/*substr*/ IN SUBSTRING(/*str*/ FROM /*pos*/)) WHEN 0 THEN 0 ELSE POSITION(/*substr*/ IN SUBSTRING(/*str*/ FROM /*pos*/)) + /*pos*/ - 1 END;
  -- LOCATE('bar', 'foobarbar', 5)
  VALUES CASE POSITION('bar' IN SUBSTRING('foobarbar' FROM 5)) WHEN 0 THEN 0
    ELSE POSITION('bar' IN SUBSTRING('foobarbar' FROM 5)) + 5 - 1 END;
  -- COL1: 7

LOWER
^^^^^

Converts a string to lower case.

.. code-block:: sql

  -- LOWER(str)
  VALUES LOWER(/*str*/);
  -- LOWER('QUADRATICALLY')
  VALUES LOWER('QUADRATICALLY');
  -- COL1: quadratically

LPAD
^^^^

Pads the start of a string with another string up to a length.

.. code-block:: sql

  -- LPAD(str, len, padstr)
  VALUES LPAD(/*str*/, /*len*/, /*padstr*/);
  -- LPAD('hi', 4, '??')
  VALUES LPAD('hi', 4, '??');
  -- COL1: ??hi

LTRIM
^^^^^

Removes the spaces at the start of a string.

.. code-block:: sql

  -- LTRIM(str)
  VALUES LTRIM(/*str*/);
  -- LTRIM('  barbar')
  VALUES LTRIM('  barbar');
  -- COL1: barbar

MAKE_SET
^^^^^^^^

.. code-block:: text

  MAKE_SET(bits, str1, str2, ...)

Joins, with commas, the strings whose bits are set in a number.

No equivalent.

MID
^^^

Returns part of a string, from a position and for a length.

.. code-block:: sql

  -- MID(str, pos, len)
  VALUES SUBSTRING(/*str*/ FROM /*pos*/ FOR /*len*/);
  -- MID('Quadratically', 5, 6)
  VALUES SUBSTRING('Quadratically' FROM 5 FOR 6);
  -- COL1: ratica

OCT
^^^

.. code-block:: text

  OCT(N)

Returns a number written in octal, as a string.

No equivalent.

OCTET_LENGTH
^^^^^^^^^^^^

Returns the length of a string in bytes.

.. code-block:: sql

  -- OCTET_LENGTH(str)
  VALUES OCTET_LENGTH(/*str*/);
  -- OCTET_LENGTH('héllo')
  VALUES OCTET_LENGTH('héllo');
  -- COL1: 6

ORD
^^^

Returns the code of the first character of a string.

.. code-block:: sql

  -- ORD(str)
  VALUES UNICODE(/*str*/);
  -- ORD('2')
  VALUES UNICODE('2');
  -- COL1: 50

``UNICODE`` returns the code point of the character. For a character of more
than one byte MySQL combines its bytes instead, so ``ORD('é')`` is 50089 where
``UNICODE('é')`` is 233.

POSITION
^^^^^^^^

Returns the position of the first time a substring appears in a string, or 0.

.. code-block:: sql

  -- POSITION(substr IN str)
  VALUES POSITION(/*substr*/ IN /*str*/);
  -- POSITION('bar' IN 'foobarbar')
  VALUES POSITION('bar' IN 'foobarbar');
  -- COL1: 4

QUOTE
^^^^^

Puts a string in single quotes, escaping the characters that need it, so it
can be used in a statement.

.. code-block:: sql

  -- QUOTE(str)
  VALUES '''' || REPLACE(/*str*/, '''', '\''') || '''';
  -- QUOTE('Don''t!')
  VALUES '''' || REPLACE('Don''t!', '''', '\''') || '''';
  -- COL1: 'Don\'t!'

This escapes the quotes with a backslash, as MySQL does. MySQL also escapes
backslashes and a few control characters, and returns the word ``NULL``
(without quotes) for a ``NULL``. A string for vsql would double the quote
instead: ``REPLACE(str, '''', '''''')``.

REGEXP_INSTR
^^^^^^^^^^^^

.. code-block:: text

  REGEXP_INSTR(expr, pat[, pos[, occurrence[, return_option[, match_type]]]])

Returns the position of a match of a regular expression in a string.

No equivalent.

REGEXP_LIKE
^^^^^^^^^^^

Tells whether a string matches a pattern.

.. code-block:: sql

  -- REGEXP_LIKE(expr, pat)
  VALUES /*expr*/ SIMILAR TO /*pattern*/;
  -- REGEXP_LIKE('abc', 'b')
  VALUES 'abc' SIMILAR TO '%b%';
  -- COL1: TRUE

``SIMILAR TO`` has to match the whole string, so put ``%`` around a pattern
that can match anywhere. It has ``|``, ``*``, ``+``, ``?``, ``{m,n}``,
``()`` and ``[]`` as regular expressions do, but ``_`` and ``%`` in place of
``.`` and ``.*``, and no ``^``, ``$`` or ``\d``. There's no ``match_type``: it's
always case sensitive.

REGEXP_REPLACE
^^^^^^^^^^^^^^

.. code-block:: text

  REGEXP_REPLACE(expr, pat, repl[, pos[, occurrence[, match_type]]])

Replaces the matches of a regular expression in a string.

No equivalent.

REGEXP_SUBSTR
^^^^^^^^^^^^^

Returns the part of a string that matches a pattern.

.. code-block:: sql

  -- REGEXP_SUBSTR(expr, pat)
  VALUES SUBSTRING(/*expr*/ SIMILAR '%#"' || /*pattern*/ || '#"%' ESCAPE '#');
  -- REGEXP_SUBSTR('abc123def', '[0-9]+')
  VALUES SUBSTRING('abc123def' SIMILAR '%#"[0-9]+#"%' ESCAPE '#');
  -- COL1: 123

The pattern is a ``SIMILAR TO`` pattern (see `REGEXP_LIKE`_), and the part
between the two ``#"`` is what's returned. The result is ``NULL`` when there's
no match, as in MySQL.

REPEAT
^^^^^^

Repeats a string a number of times.

.. code-block:: sql

  -- REPEAT(str, count)
  VALUES REPEAT(/*str*/, /*count*/);
  -- REPEAT('MySQL', 3)
  VALUES REPEAT('MySQL', 3);
  -- COL1: MySQLMySQLMySQL

REPLACE
^^^^^^^

Replaces every time a substring appears in a string with another string.

.. code-block:: sql

  -- REPLACE(str, from_str, to_str)
  VALUES REPLACE(/*str*/, /*from_str*/, /*to_str*/);
  -- REPLACE('www.mysql.com', 'w', 'Ww')
  VALUES REPLACE('www.mysql.com', 'w', 'Ww');
  -- COL1: WwWwWw.mysql.com

REVERSE
^^^^^^^

Returns the characters of a string in reverse order.

.. code-block:: sql

  -- REVERSE(str)
  VALUES REVERSE(/*str*/);
  -- REVERSE('abc')
  VALUES REVERSE('abc');
  -- COL1: cba

RIGHT
^^^^^

Returns a number of characters from the end of a string.

.. code-block:: sql

  -- RIGHT(str, len)
  VALUES SUBSTRING(/*str*/ FROM CHAR_LENGTH(/*str*/) - /*len*/ + 1);
  -- RIGHT('foobarbar', 4)
  VALUES SUBSTRING('foobarbar' FROM CHAR_LENGTH('foobarbar') - 4 + 1);
  -- COL1: rbar

RPAD
^^^^

Pads the end of a string with another string up to a length.

.. code-block:: sql

  -- RPAD(str, len, padstr)
  VALUES RPAD(/*str*/, /*len*/, /*padstr*/);
  -- RPAD('hi', 5, '?')
  VALUES RPAD('hi', 5, '?');
  -- COL1: hi???

RTRIM
^^^^^

Removes the spaces at the end of a string.

.. code-block:: sql

  -- RTRIM(str)
  VALUES RTRIM(/*str*/);
  -- CONCAT(RTRIM('barbar   '), '|')
  VALUES RTRIM('barbar   ') || '|';
  -- COL1: barbar|

SOUNDEX
^^^^^^^

.. code-block:: text

  SOUNDEX(str)

Returns a code for how a word sounds in English, so that words that sound alike have the same code.

No equivalent.

SPACE
^^^^^

Returns a number of spaces.

.. code-block:: sql

  -- SPACE(N)
  VALUES REPEAT(' ', /*N*/);
  -- CONCAT('[', SPACE(3), ']')
  VALUES '[' || REPEAT(' ', 3) || ']';
  -- COL1: [   ]

STRCMP
^^^^^^

Compares two strings, giving -1, 0 or 1.

.. code-block:: sql

  -- STRCMP(expr1, expr2)
  VALUES CASE WHEN /*expr1*/ < /*expr2*/ THEN -1 WHEN /*expr1*/ > /*expr2*/ THEN 1 ELSE 0 END;
  -- STRCMP('text', 'text2')
  VALUES CASE WHEN 'text' < 'text2' THEN -1 WHEN 'text' > 'text2' THEN 1 ELSE 0 END;
  -- COL1: -1

The comparison is case sensitive in vsql, so ``'a'`` and ``'A'`` aren't equal.

SUBSTR
^^^^^^

Returns part of a string, from a position and optionally for a length.

.. code-block:: sql

  -- SUBSTR(str, pos)
  VALUES SUBSTRING(/*str*/ FROM /*pos*/);
  -- SUBSTR('Quadratically', 5)
  VALUES SUBSTRING('Quadratically' FROM 5);
  -- COL1: ratically

  -- SUBSTR(str, pos, len)
  VALUES SUBSTRING(/*str*/ FROM /*pos*/ FOR /*len*/);
  -- SUBSTR('Quadratically', 5, 6)
  VALUES SUBSTRING('Quadratically' FROM 5 FOR 6);
  -- COL1: ratica

SUBSTRING
^^^^^^^^^

Returns part of a string, from a position and optionally for a length.

.. code-block:: sql

  -- SUBSTRING(str, pos)
  VALUES SUBSTRING(/*str*/ FROM /*pos*/);
  -- SUBSTRING('Quadratically', 5)
  VALUES SUBSTRING('Quadratically' FROM 5);
  -- COL1: ratically

  -- SUBSTRING(str, pos, len)
  VALUES SUBSTRING(/*str*/ FROM /*pos*/ FOR /*len*/);
  -- SUBSTRING('Quadratically', 5, 6)
  VALUES SUBSTRING('Quadratically' FROM 5 FOR 6);
  -- COL1: ratica

  -- SUBSTRING(str, -pos)
  VALUES SUBSTRING(/*str*/ FROM CHAR_LENGTH(/*str*/) - /*pos*/ + 1);
  -- SUBSTRING('Sakila', -3)
  VALUES SUBSTRING('Sakila' FROM CHAR_LENGTH('Sakila') - 3 + 1);
  -- COL1: ila

A negative position counts from the end in MySQL, but not in vsql, so the last
form works it out from the length.

SUBSTRING_INDEX
^^^^^^^^^^^^^^^

Returns the part of a string before, or after, a number of times a delimiter
appears in it.

.. code-block:: sql

  -- SUBSTRING_INDEX(str, delim, 1)
  VALUES SPLIT_PART(/*str*/, /*delim*/, 1);
  -- SUBSTRING_INDEX('www.mysql.com', '.', 1)
  VALUES SPLIT_PART('www.mysql.com', '.', 1);
  -- COL1: www

  -- SUBSTRING_INDEX(str, delim, -1)
  VALUES SPLIT_PART(/*str*/, /*delim*/, -1);
  -- SUBSTRING_INDEX('www.mysql.com', '.', -1)
  VALUES SPLIT_PART('www.mysql.com', '.', -1);
  -- COL1: com

  -- SUBSTRING_INDEX(str, delim, 2)
  VALUES SPLIT_PART(/*str*/, /*delim*/, 1) || /*delim*/ || SPLIT_PART(/*str*/, /*delim*/, 2);
  -- SUBSTRING_INDEX('www.mysql.com', '.', 2)
  VALUES SPLIT_PART('www.mysql.com', '.', 1) || '.' || SPLIT_PART('www.mysql.com', '.', 2);
  -- COL1: www.mysql

``SPLIT_PART`` returns only one part, so more than one part is joined back
together with the delimiter.

TO_BASE64
^^^^^^^^^

.. code-block:: text

  TO_BASE64(str)

Encodes a string as base 64.

No equivalent.

TRIM
^^^^

Removes spaces, or another string, from the start and end of a string.

.. code-block:: sql

  -- TRIM(str)
  VALUES TRIM(/*str*/);
  -- CONCAT('|', TRIM('  bar   '), '|')
  VALUES '|' || TRIM('  bar   ') || '|';
  -- COL1: |bar|

  -- TRIM([BOTH | LEADING | TRAILING] remstr FROM str)
  VALUES TRIM(LEADING /*remstr*/ FROM /*str*/);
  -- TRIM(LEADING 'x' FROM 'xxxbarxxx')
  VALUES TRIM(LEADING 'x' FROM 'xxxbarxxx');
  -- COL1: barxxx

In vsql, ``remstr`` must be one character (otherwise it's a ``22027`` error),
where MySQL removes a longer ``remstr`` as a whole, as many times as it
appears.

UCASE
^^^^^

Converts a string to upper case.

.. code-block:: sql

  -- UCASE(str)
  VALUES UPPER(/*str*/);
  -- UCASE('Hej')
  VALUES UPPER('Hej');
  -- COL1: HEJ

UNHEX
^^^^^

.. code-block:: text

  UNHEX(str)

Turns pairs of hexadecimal digits into the bytes they stand for.

No equivalent.

UPPER
^^^^^

Converts a string to upper case.

.. code-block:: sql

  -- UPPER(str)
  VALUES UPPER(/*str*/);
  -- UPPER('Hej')
  VALUES UPPER('Hej');
  -- COL1: HEJ

WEIGHT_STRING
^^^^^^^^^^^^^

.. code-block:: text

  WEIGHT_STRING(str [AS {CHAR

BINARY}(N)])|Returns the binary string that the collation of a string sorts it by.

No equivalent.

Full-Text Search Functions
--------------------------

MATCH
^^^^^

.. code-block:: text

  MATCH (col1, col2, ...) AGAINST (expr [search_modifier])

Searches a FULLTEXT index for words or phrases and returns how relevant each row is.

No equivalent.

Cast Functions
--------------

CAST
^^^^

Converts a value to another type.

.. code-block:: sql

  -- CAST(expr AS type)
  VALUES CAST(/*expr*/ AS /*type*/);
  -- CAST('12' AS SIGNED)
  VALUES CAST('12' AS BIGINT);
  -- COL1: 12

The names of some types are different: ``SIGNED`` is ``BIGINT``, ``CHAR(N)``
is ``VARCHAR(N)``, ``DATETIME`` is ``TIMESTAMP``, ``DOUBLE`` is
``DOUBLE PRECISION`` and ``FLOAT`` is ``REAL``. There's no ``UNSIGNED``,
``BINARY``, ``JSON`` or ``YEAR``. A decimal cast to an integer drops the
fraction (``CAST(12.5 AS BIGINT)`` is 12), where MySQL rounds it to 13.

CONVERT
^^^^^^^

Converts a value to another type, or a string to another character set.

.. code-block:: sql

  -- CONVERT(expr, type)
  VALUES CAST(/*expr*/ AS /*type*/);
  -- CONVERT('2024-03-15', DATE)
  VALUES CAST('2024-03-15' AS DATE);
  -- COL1: 2024-03-15

The types are named as for `CAST`_. There's no equivalent of
``CONVERT(expr USING transcoding_name)``, since all text in vsql is UTF-8.

XML Functions
-------------

ExtractValue
^^^^^^^^^^^^

.. code-block:: text

  ExtractValue(xml_frag, xpath_expr)

Returns the text that an XPath expression selects from a fragment of XML.

No equivalent.

UpdateXML
^^^^^^^^^

.. code-block:: text

  UpdateXML(xml_target, xpath_expr, new_xml)

Replaces the part of a fragment of XML that an XPath expression selects with new XML.

No equivalent.

Bit Functions
-------------

BIT_COUNT
^^^^^^^^^

.. code-block:: text

  BIT_COUNT(N)

Counts the bits that are set in a number.

No equivalent.

Encryption and Compression Functions
------------------------------------

AES_DECRYPT
^^^^^^^^^^^

.. code-block:: text

  AES_DECRYPT(crypt_str, key_str[, init_vector[, kdf_name[, salt[, info 

 iterations]]]])|Decrypts a string that was encrypted with AES.

No equivalent.

AES_ENCRYPT
^^^^^^^^^^^

.. code-block:: text

  AES_ENCRYPT(str, key_str[, init_vector[, kdf_name[, salt[, info 

 iterations]]]])|Encrypts a string with AES, returning a binary string.

No equivalent.

COMPRESS
^^^^^^^^

.. code-block:: text

  COMPRESS(string_to_compress)

Compresses a string with zlib, returning a binary string.

No equivalent.

MD5
^^^

.. code-block:: text

  MD5(str)

Returns the MD5 checksum of a string, as 32 hexadecimal digits.

No equivalent.

RANDOM_BYTES
^^^^^^^^^^^^

.. code-block:: text

  RANDOM_BYTES(len)

Returns a binary string of random bytes from a cryptographically secure generator.

No equivalent.

SHA
^^^

.. code-block:: text

  SHA(str)

Another name for SHA1: returns the SHA-1 checksum of a string.

No equivalent.

SHA1
^^^^

.. code-block:: text

  SHA1(str)

Returns the SHA-1 checksum of a string, as 40 hexadecimal digits.

No equivalent.

SHA2
^^^^

.. code-block:: text

  SHA2(str, hash_length)

Returns a checksum of a string from the SHA-2 family (SHA-224, SHA-256, SHA-384 or SHA-512).

No equivalent.

STATEMENT_DIGEST
^^^^^^^^^^^^^^^^

.. code-block:: text

  STATEMENT_DIGEST(statement)

Returns the hash that the Performance Schema would give a statement once its values are taken out.

No equivalent.

STATEMENT_DIGEST_TEXT
^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  STATEMENT_DIGEST_TEXT(statement)

Returns a statement in the normalized form that its digest is computed from.

No equivalent.

UNCOMPRESS
^^^^^^^^^^

.. code-block:: text

  UNCOMPRESS(string_to_uncompress)

Decompresses a string compressed with COMPRESS.

No equivalent.

UNCOMPRESSED_LENGTH
^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  UNCOMPRESSED_LENGTH(compressed_string)

Returns the length that a string compressed with COMPRESS had before it was compressed.

No equivalent.

VALIDATE_PASSWORD_STRENGTH
^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  VALIDATE_PASSWORD_STRENGTH(str)

Rates how strong a password is, from 0 to 100.

No equivalent.

Locking Functions
-----------------

GET_LOCK
^^^^^^^^

.. code-block:: text

  GET_LOCK(str, timeout)

Takes a named lock for the session, waiting up to a number of seconds for it.

No equivalent.

IS_FREE_LOCK
^^^^^^^^^^^^

.. code-block:: text

  IS_FREE_LOCK(str)

Tells whether nobody holds a named lock.

No equivalent.

IS_USED_LOCK
^^^^^^^^^^^^

.. code-block:: text

  IS_USED_LOCK(str)

Returns the connection ID of the session that holds a named lock, or NULL.

No equivalent.

RELEASE_ALL_LOCKS
^^^^^^^^^^^^^^^^^

.. code-block:: text

  RELEASE_ALL_LOCKS()

Releases every named lock that the session holds, and returns how many there were.

No equivalent.

RELEASE_LOCK
^^^^^^^^^^^^

.. code-block:: text

  RELEASE_LOCK(str)

Releases a named lock that the session holds.

No equivalent.

Information Functions
---------------------

BENCHMARK
^^^^^^^^^

.. code-block:: text

  BENCHMARK(count, expr)

Evaluates an expression a number of times, to time how fast it is, and returns 0.

No equivalent.

CHARSET
^^^^^^^

.. code-block:: text

  CHARSET(str)

Returns the character set of a string.

No equivalent.

COERCIBILITY
^^^^^^^^^^^^

.. code-block:: text

  COERCIBILITY(str)

Returns how strongly the collation of a string takes part when two collations meet.

No equivalent.

COLLATION
^^^^^^^^^

.. code-block:: text

  COLLATION(str)

Returns the collation of a string.

No equivalent.

CONNECTION_ID
^^^^^^^^^^^^^

.. code-block:: text

  CONNECTION_ID()

Returns the ID of the current connection.

No equivalent.

CURRENT_ROLE
^^^^^^^^^^^^

.. code-block:: text

  CURRENT_ROLE()

Returns the roles that are active in the session.

No equivalent.

CURRENT_USER
^^^^^^^^^^^^

.. code-block:: text

  CURRENT_USER()

Returns the account that the server checked the privileges of the session against.

No equivalent.

DATABASE
^^^^^^^^

Returns the name of the current database.

.. code-block:: sql

  -- DATABASE()
  VALUES CURRENT_SCHEMA;
  -- DATABASE()
  VALUES CURRENT_SCHEMA;
  -- COL1: PUBLIC

A database in MySQL is a schema in vsql, which is ``PUBLIC`` unless it's been
changed with :doc:`set-schema`. MySQL returns ``NULL`` when no database has
been chosen.

FOUND_ROWS
^^^^^^^^^^

.. code-block:: text

  FOUND_ROWS()

Returns how many rows the last SELECT would have returned without its LIMIT.

No equivalent.

ICU_VERSION
^^^^^^^^^^^

.. code-block:: text

  ICU_VERSION()

Returns the version of the ICU library that regular expressions use.

No equivalent.

LAST_INSERT_ID
^^^^^^^^^^^^^^

.. code-block:: text

  LAST_INSERT_ID([expr])

Returns the first AUTO_INCREMENT value that the last INSERT generated.

No equivalent.

ROLES_GRAPHML
^^^^^^^^^^^^^

.. code-block:: text

  ROLES_GRAPHML()

Returns a GraphML document of the roles and which roles are granted to which.

No equivalent.

ROW_COUNT
^^^^^^^^^

.. code-block:: text

  ROW_COUNT()

Returns how many rows the last statement changed.

No equivalent.

SCHEMA
^^^^^^

Returns the name of the current database.

.. code-block:: sql

  -- SCHEMA()
  VALUES CURRENT_SCHEMA;
  -- SCHEMA()
  VALUES CURRENT_SCHEMA;
  -- COL1: PUBLIC

See `DATABASE`_.

SESSION_USER
^^^^^^^^^^^^

.. code-block:: text

  SESSION_USER()

Returns the user name and host that the client connected with.

No equivalent.

SYSTEM_USER
^^^^^^^^^^^

.. code-block:: text

  SYSTEM_USER()

Returns the user name and host that the client connected with.

No equivalent.

USER
^^^^

.. code-block:: text

  USER()

Returns the user name and host that the client connected with.

No equivalent.

VERSION
^^^^^^^

.. code-block:: text

  VERSION()

Returns the version of the MySQL server.

No equivalent.

VERSION_WITH_UPDATE
^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  VERSION_WITH_UPDATE()

Returns the version of the MySQL server, including its update number.

No equivalent.

Spatial Analysis Functions
--------------------------

GeomCollection
^^^^^^^^^^^^^^

.. code-block:: text

  GeomCollection(g [, g] ...)

Builds a geometry collection from geometries.

No equivalent.

GeometryCollection
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  GeometryCollection(g [, g] ...)

Builds a geometry collection from geometries.

No equivalent.

LineString
^^^^^^^^^^

.. code-block:: text

  LineString(pt [, pt] ...)

Builds a line from points.

No equivalent.

MBRContains
^^^^^^^^^^^

.. code-block:: text

  MBRContains(g1, g2)

Tells whether the bounding rectangle of one geometry contains that of another.

No equivalent.

MBRCoveredBy
^^^^^^^^^^^^

.. code-block:: text

  MBRCoveredBy(g1, g2)

Tells whether the bounding rectangle of one geometry is covered by that of another.

No equivalent.

MBRCovers
^^^^^^^^^

.. code-block:: text

  MBRCovers(g1, g2)

Tells whether the bounding rectangle of one geometry covers that of another.

No equivalent.

MBRDisjoint
^^^^^^^^^^^

.. code-block:: text

  MBRDisjoint(g1, g2)

Tells whether the bounding rectangles of two geometries don't meet.

No equivalent.

MBREquals
^^^^^^^^^

.. code-block:: text

  MBREquals(g1, g2)

Tells whether two geometries have the same bounding rectangle.

No equivalent.

MBRIntersects
^^^^^^^^^^^^^

.. code-block:: text

  MBRIntersects(g1, g2)

Tells whether the bounding rectangles of two geometries meet.

No equivalent.

MBROverlaps
^^^^^^^^^^^

.. code-block:: text

  MBROverlaps(g1, g2)

Tells whether the bounding rectangles of two geometries overlap.

No equivalent.

MBRTouches
^^^^^^^^^^

.. code-block:: text

  MBRTouches(g1, g2)

Tells whether the bounding rectangles of two geometries touch only at their edges.

No equivalent.

MBRWithin
^^^^^^^^^

.. code-block:: text

  MBRWithin(g1, g2)

Tells whether the bounding rectangle of one geometry is inside that of another.

No equivalent.

MultiLineString
^^^^^^^^^^^^^^^

.. code-block:: text

  MultiLineString(ls [, ls] ...)

Builds a multi-line from lines.

No equivalent.

MultiPoint
^^^^^^^^^^

.. code-block:: text

  MultiPoint(pt [, pt2] ...)

Builds a multi-point from points.

No equivalent.

MultiPolygon
^^^^^^^^^^^^

.. code-block:: text

  MultiPolygon(poly [, poly] ...)

Builds a multi-polygon from polygons.

No equivalent.

Point
^^^^^

.. code-block:: text

  Point(x, y)

Builds a point from its coordinates.

No equivalent.

Polygon
^^^^^^^

.. code-block:: text

  Polygon(ls [, ls] ...)

Builds a polygon from rings.

No equivalent.

ST_Area
^^^^^^^

.. code-block:: text

  ST_Area({poly

mpoly})|Returns the area of a polygon or multi-polygon.

No equivalent.

ST_AsBinary
^^^^^^^^^^^

.. code-block:: text

  ST_AsBinary(g [, options])

Writes a geometry as well-known binary (WKB).

No equivalent.

ST_AsGeoJSON
^^^^^^^^^^^^

.. code-block:: text

  ST_AsGeoJSON(g [, max_dec_digits [, options]])

Writes a geometry as a GeoJSON object.

No equivalent.

ST_AsText
^^^^^^^^^

.. code-block:: text

  ST_AsText(g [, options])

Writes a geometry as well-known text (WKT).

No equivalent.

ST_AsWKB
^^^^^^^^

.. code-block:: text

  ST_AsWKB(g [, options])

Another name for ST_AsBinary: writes a geometry as well-known binary.

No equivalent.

ST_AsWKT
^^^^^^^^

.. code-block:: text

  ST_AsWKT(g [, options])

Another name for ST_AsText: writes a geometry as well-known text.

No equivalent.

ST_Buffer
^^^^^^^^^

.. code-block:: text

  ST_Buffer(g, d [, strategy1 [, strategy2 [, strategy3]]])

Returns the geometry of every point within a distance of a geometry.

No equivalent.

ST_Buffer_Strategy
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_Buffer_Strategy(strategy [, points_per_circle])

Returns a strategy that controls how ST_Buffer draws its buffer.

No equivalent.

ST_Centroid
^^^^^^^^^^^

.. code-block:: text

  ST_Centroid({poly

mpoly})|Returns the center of mass of a polygon or multi-polygon as a point.

No equivalent.

ST_Collect
^^^^^^^^^^

.. code-block:: text

  ST_Collect([DISTINCT] g) [over_clause]

Aggregates geometries into a collection.

No equivalent.

ST_Contains
^^^^^^^^^^^

.. code-block:: text

  ST_Contains(g1, g2)

Tells whether one geometry contains another.

No equivalent.

ST_ConvexHull
^^^^^^^^^^^^^

.. code-block:: text

  ST_ConvexHull(g)

Returns the smallest convex geometry that holds a geometry.

No equivalent.

ST_Crosses
^^^^^^^^^^

.. code-block:: text

  ST_Crosses(g1, g2)

Tells whether two geometries cross.

No equivalent.

ST_Difference
^^^^^^^^^^^^^

.. code-block:: text

  ST_Difference(g1, g2)

Returns the part of one geometry that isn't in another.

No equivalent.

ST_Dimension
^^^^^^^^^^^^

.. code-block:: text

  ST_Dimension(g)

Returns the dimension of a geometry: 0 for points, 1 for lines and 2 for areas.

No equivalent.

ST_Disjoint
^^^^^^^^^^^

.. code-block:: text

  ST_Disjoint(g1, g2)

Tells whether two geometries have no point in common.

No equivalent.

ST_Distance
^^^^^^^^^^^

.. code-block:: text

  ST_Distance(g1, g2 [, unit])

Returns the distance between two geometries.

No equivalent.

ST_Distance_Sphere
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_Distance_Sphere(g1, g2 [, radius])

Returns the distance between two points or multi-points on a sphere, in meters.

No equivalent.

ST_EndPoint
^^^^^^^^^^^

.. code-block:: text

  ST_EndPoint(ls)

Returns the last point of a line.

No equivalent.

ST_Envelope
^^^^^^^^^^^

.. code-block:: text

  ST_Envelope(g)

Returns the bounding rectangle of a geometry.

No equivalent.

ST_Equals
^^^^^^^^^

.. code-block:: text

  ST_Equals(g1, g2)

Tells whether two geometries are the same shape.

No equivalent.

ST_ExteriorRing
^^^^^^^^^^^^^^^

.. code-block:: text

  ST_ExteriorRing(poly)

Returns the outer ring of a polygon as a line.

No equivalent.

ST_FrechetDistance
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_FrechetDistance(g1, g2 [, unit])

Returns the discrete Fréchet distance between two lines.

No equivalent.

ST_GeoHash
^^^^^^^^^^

.. code-block:: text

  ST_GeoHash(longitude, latitude, max_length)

Returns the geohash string of a point.

No equivalent.

ST_GeomCollFromText
^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_GeomCollFromText(wkt [, srid [, options]])

Reads a geometry collection from well-known text.

No equivalent.

ST_GeomCollFromTxt
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_GeomCollFromTxt(wkt [, srid [, options]])

Another name for ST_GeomCollFromText.

No equivalent.

ST_GeomCollFromWKB
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_GeomCollFromWKB(wkb [, srid [, options]])

Reads a geometry collection from well-known binary.

No equivalent.

ST_GeometryCollectionFromText
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_GeometryCollectionFromText(wkt [, srid [, options]])

Another name for ST_GeomCollFromText.

No equivalent.

ST_GeometryCollectionFromWKB
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_GeometryCollectionFromWKB(wkb [, srid [, options]])

Another name for ST_GeomCollFromWKB.

No equivalent.

ST_GeometryFromText
^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_GeometryFromText(wkt [, srid [, options]])

Another name for ST_GeomFromText.

No equivalent.

ST_GeometryFromWKB
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_GeometryFromWKB(wkb [, srid [, options]])

Another name for ST_GeomFromWKB.

No equivalent.

ST_GeometryN
^^^^^^^^^^^^

.. code-block:: text

  ST_GeometryN(gc, N)

Returns one geometry, by its position, of a geometry collection.

No equivalent.

ST_GeometryType
^^^^^^^^^^^^^^^

.. code-block:: text

  ST_GeometryType(g)

Returns the name of the type of a geometry, such as POINT.

No equivalent.

ST_GeomFromGeoJSON
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_GeomFromGeoJSON(str [, options [, srid]])

Reads a geometry from a GeoJSON object.

No equivalent.

ST_GeomFromText
^^^^^^^^^^^^^^^

.. code-block:: text

  ST_GeomFromText(wkt [, srid [, options]])

Reads a geometry of any type from well-known text.

No equivalent.

ST_GeomFromWKB
^^^^^^^^^^^^^^

.. code-block:: text

  ST_GeomFromWKB(wkb [, srid [, options]])

Reads a geometry of any type from well-known binary.

No equivalent.

ST_HausdorffDistance
^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_HausdorffDistance(g1, g2 [, unit])

Returns the discrete Hausdorff distance between two geometries.

No equivalent.

ST_InteriorRingN
^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_InteriorRingN(poly, N)

Returns one inner ring, by its position, of a polygon.

No equivalent.

ST_Intersection
^^^^^^^^^^^^^^^

.. code-block:: text

  ST_Intersection(g1, g2)

Returns the part that two geometries have in common.

No equivalent.

ST_Intersects
^^^^^^^^^^^^^

.. code-block:: text

  ST_Intersects(g1, g2)

Tells whether two geometries have any point in common.

No equivalent.

ST_IsClosed
^^^^^^^^^^^

.. code-block:: text

  ST_IsClosed(ls)

Tells whether a line ends where it starts.

No equivalent.

ST_IsEmpty
^^^^^^^^^^

.. code-block:: text

  ST_IsEmpty(g)

Tells whether a geometry is an empty geometry collection.

No equivalent.

ST_IsSimple
^^^^^^^^^^^

.. code-block:: text

  ST_IsSimple(g)

Tells whether a geometry has no self-intersections or other irregular points.

No equivalent.

ST_IsValid
^^^^^^^^^^

.. code-block:: text

  ST_IsValid(g)

Tells whether a geometry is valid.

No equivalent.

ST_LatFromGeoHash
^^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_LatFromGeoHash(geohash_str)

Returns the latitude of a geohash string.

No equivalent.

ST_Latitude
^^^^^^^^^^^

.. code-block:: text

  ST_Latitude(p [, new_latitude_val])

Returns, or sets, the latitude of a point in a geographic coordinate system.

No equivalent.

ST_Length
^^^^^^^^^

.. code-block:: text

  ST_Length(ls [, unit])

Returns the length of a line or multi-line.

No equivalent.

ST_LineFromText
^^^^^^^^^^^^^^^

.. code-block:: text

  ST_LineFromText(wkt [, srid [, options]])

Reads a line from well-known text.

No equivalent.

ST_LineFromWKB
^^^^^^^^^^^^^^

.. code-block:: text

  ST_LineFromWKB(wkb [, srid [, options]])

Reads a line from well-known binary.

No equivalent.

ST_LineInterpolatePoint
^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_LineInterpolatePoint(ls, fractional_distance)

Returns the point at a fraction of the way along a line.

No equivalent.

ST_LineInterpolatePoints
^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_LineInterpolatePoints(ls, fractional_distance)

Returns the points at each multiple of a fraction of the way along a line.

No equivalent.

ST_LineStringFromText
^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_LineStringFromText(wkt [, srid [, options]])

Another name for ST_LineFromText.

No equivalent.

ST_LineStringFromWKB
^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_LineStringFromWKB(wkb [, srid [, options]])

Another name for ST_LineFromWKB.

No equivalent.

ST_LongFromGeoHash
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_LongFromGeoHash(geohash_str)

Returns the longitude of a geohash string.

No equivalent.

ST_Longitude
^^^^^^^^^^^^

.. code-block:: text

  ST_Longitude(p [, new_longitude_val])

Returns, or sets, the longitude of a point in a geographic coordinate system.

No equivalent.

ST_MakeEnvelope
^^^^^^^^^^^^^^^

.. code-block:: text

  ST_MakeEnvelope(pt1, pt2)

Returns the rectangle with two points at its opposite corners.

No equivalent.

ST_MLineFromText
^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_MLineFromText(wkt [, srid [, options]])

Reads a multi-line from well-known text.

No equivalent.

ST_MLineFromWKB
^^^^^^^^^^^^^^^

.. code-block:: text

  ST_MLineFromWKB(wkb [, srid [, options]])

Reads a multi-line from well-known binary.

No equivalent.

ST_MPointFromText
^^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_MPointFromText(wkt [, srid [, options]])

Reads a multi-point from well-known text.

No equivalent.

ST_MPointFromWKB
^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_MPointFromWKB(wkb [, srid [, options]])

Reads a multi-point from well-known binary.

No equivalent.

ST_MPolyFromText
^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_MPolyFromText(wkt [, srid [, options]])

Reads a multi-polygon from well-known text.

No equivalent.

ST_MPolyFromWKB
^^^^^^^^^^^^^^^

.. code-block:: text

  ST_MPolyFromWKB(wkb [, srid [, options]])

Reads a multi-polygon from well-known binary.

No equivalent.

ST_MultiLineStringFromText
^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_MultiLineStringFromText(wkt [, srid [, options]])

Another name for ST_MLineFromText.

No equivalent.

ST_MultiLineStringFromWKB
^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_MultiLineStringFromWKB(wkb [, srid [, options]])

Another name for ST_MLineFromWKB.

No equivalent.

ST_MultiPointFromText
^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_MultiPointFromText(wkt [, srid [, options]])

Another name for ST_MPointFromText.

No equivalent.

ST_MultiPointFromWKB
^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_MultiPointFromWKB(wkb [, srid [, options]])

Another name for ST_MPointFromWKB.

No equivalent.

ST_MultiPolygonFromText
^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_MultiPolygonFromText(wkt [, srid [, options]])

Another name for ST_MPolyFromText.

No equivalent.

ST_MultiPolygonFromWKB
^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_MultiPolygonFromWKB(wkb [, srid [, options]])

Another name for ST_MPolyFromWKB.

No equivalent.

ST_NumGeometries
^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_NumGeometries(gc)

Counts the geometries in a geometry collection.

No equivalent.

ST_NumInteriorRing
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_NumInteriorRing(poly)

Another name for ST_NumInteriorRings.

No equivalent.

ST_NumInteriorRings
^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_NumInteriorRings(poly)

Counts the inner rings of a polygon.

No equivalent.

ST_NumPoints
^^^^^^^^^^^^

.. code-block:: text

  ST_NumPoints(ls)

Counts the points of a line.

No equivalent.

ST_Overlaps
^^^^^^^^^^^

.. code-block:: text

  ST_Overlaps(g1, g2)

Tells whether two geometries of the same dimension overlap without one containing the other.

No equivalent.

ST_PointAtDistance
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_PointAtDistance(ls, distance)

Returns the point at a distance along a line.

No equivalent.

ST_PointFromGeoHash
^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_PointFromGeoHash(geohash_str, srid)

Returns the point of a geohash string.

No equivalent.

ST_PointFromText
^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_PointFromText(wkt [, srid [, options]])

Reads a point from well-known text.

No equivalent.

ST_PointFromWKB
^^^^^^^^^^^^^^^

.. code-block:: text

  ST_PointFromWKB(wkb [, srid [, options]])

Reads a point from well-known binary.

No equivalent.

ST_PointN
^^^^^^^^^

.. code-block:: text

  ST_PointN(ls, N)

Returns one point, by its position, of a line.

No equivalent.

ST_PolyFromText
^^^^^^^^^^^^^^^

.. code-block:: text

  ST_PolyFromText(wkt [, srid [, options]])

Reads a polygon from well-known text.

No equivalent.

ST_PolyFromWKB
^^^^^^^^^^^^^^

.. code-block:: text

  ST_PolyFromWKB(wkb [, srid [, options]])

Reads a polygon from well-known binary.

No equivalent.

ST_PolygonFromText
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_PolygonFromText(wkt [, srid [, options]])

Another name for ST_PolyFromText.

No equivalent.

ST_PolygonFromWKB
^^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_PolygonFromWKB(wkb [, srid [, options]])

Another name for ST_PolyFromWKB.

No equivalent.

ST_Simplify
^^^^^^^^^^^

.. code-block:: text

  ST_Simplify(g, max_distance)

Simplifies a geometry with the Douglas-Peucker algorithm.

No equivalent.

ST_SRID
^^^^^^^

.. code-block:: text

  ST_SRID(g [, srid])

Returns, or changes, the spatial reference system ID of a geometry.

No equivalent.

ST_StartPoint
^^^^^^^^^^^^^

.. code-block:: text

  ST_StartPoint(ls)

Returns the first point of a line.

No equivalent.

ST_SwapXY
^^^^^^^^^

.. code-block:: text

  ST_SwapXY(g)

Returns a geometry with the X and Y of every point swapped.

No equivalent.

ST_SymDifference
^^^^^^^^^^^^^^^^

.. code-block:: text

  ST_SymDifference(g1, g2)

Returns the parts of two geometries that aren't in both.

No equivalent.

ST_Touches
^^^^^^^^^^

.. code-block:: text

  ST_Touches(g1, g2)

Tells whether two geometries touch at their edges without their insides meeting.

No equivalent.

ST_Transform
^^^^^^^^^^^^

.. code-block:: text

  ST_Transform(g, target_srid)

Converts a geometry to another spatial reference system.

No equivalent.

ST_Union
^^^^^^^^

.. code-block:: text

  ST_Union(g1, g2)

Returns the geometry of every point in either of two geometries.

No equivalent.

ST_Validate
^^^^^^^^^^^

.. code-block:: text

  ST_Validate(g)

Returns a geometry if it's valid, or NULL.

No equivalent.

ST_Within
^^^^^^^^^

.. code-block:: text

  ST_Within(g1, g2)

Tells whether one geometry is inside another.

No equivalent.

ST_X
^^^^

.. code-block:: text

  ST_X(p [, new_x_val])

Returns, or sets, the X coordinate of a point.

No equivalent.

ST_Y
^^^^

.. code-block:: text

  ST_Y(p [, new_y_val])

Returns, or sets, the Y coordinate of a point.

No equivalent.

JSON Functions
--------------

JSON_ARRAY
^^^^^^^^^^

.. code-block:: text

  JSON_ARRAY([val[, val] ...])

Builds a JSON array from values.

No equivalent.

JSON_ARRAY_APPEND
^^^^^^^^^^^^^^^^^

.. code-block:: text

  JSON_ARRAY_APPEND(json_doc, path, val[, path, val] ...)

Adds values to the end of arrays in a JSON document.

No equivalent.

JSON_ARRAY_INSERT
^^^^^^^^^^^^^^^^^

.. code-block:: text

  JSON_ARRAY_INSERT(json_doc, path, val[, path, val] ...)

Inserts values at positions of arrays in a JSON document.

No equivalent.

JSON_CONTAINS
^^^^^^^^^^^^^

.. code-block:: text

  JSON_CONTAINS(target, candidate[, path])

Tells whether a JSON document contains another one, optionally at a path.

No equivalent.

JSON_CONTAINS_PATH
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  JSON_CONTAINS_PATH(json_doc, one_or_all, path[, path] ...)

Tells whether a JSON document has data at one, or all, of some paths.

No equivalent.

JSON_DEPTH
^^^^^^^^^^

.. code-block:: text

  JSON_DEPTH(json_doc)

Returns how deeply a JSON document is nested.

No equivalent.

JSON_EXTRACT
^^^^^^^^^^^^

.. code-block:: text

  JSON_EXTRACT(json_doc, path[, path] ...)

Returns the data at paths of a JSON document.

No equivalent.

JSON_INSERT
^^^^^^^^^^^

.. code-block:: text

  JSON_INSERT(json_doc, path, val[, path, val] ...)

Adds values at paths of a JSON document where there's nothing yet.

No equivalent.

JSON_KEYS
^^^^^^^^^

.. code-block:: text

  JSON_KEYS(json_doc[, path])

Returns the keys of a JSON object as an array.

No equivalent.

JSON_LENGTH
^^^^^^^^^^^

.. code-block:: text

  JSON_LENGTH(json_doc[, path])

Counts the elements of a JSON array or the members of a JSON object.

No equivalent.

JSON_MERGE
^^^^^^^^^^

.. code-block:: text

  JSON_MERGE(json_doc, json_doc[, json_doc] ...)

An older name for JSON_MERGE_PRESERVE.

No equivalent.

JSON_MERGE_PATCH
^^^^^^^^^^^^^^^^

.. code-block:: text

  JSON_MERGE_PATCH(json_doc, json_doc[, json_doc] ...)

Merges JSON documents as RFC 7396 does, with the later values replacing the earlier ones.

No equivalent.

JSON_MERGE_PRESERVE
^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  JSON_MERGE_PRESERVE(json_doc, json_doc[, json_doc] ...)

Merges JSON documents, keeping every value of a key in an array.

No equivalent.

JSON_OBJECT
^^^^^^^^^^^

.. code-block:: text

  JSON_OBJECT([key, val[, key, val] ...])

Builds a JSON object from keys and values.

No equivalent.

JSON_OVERLAPS
^^^^^^^^^^^^^

.. code-block:: text

  JSON_OVERLAPS(json_doc1, json_doc2)

Tells whether two JSON documents have any key and value, or array element, in common.

No equivalent.

JSON_PRETTY
^^^^^^^^^^^

.. code-block:: text

  JSON_PRETTY(json_val)

Writes a JSON document over several indented lines.

No equivalent.

JSON_QUOTE
^^^^^^^^^^

.. code-block:: text

  JSON_QUOTE(string)

Puts a string in double quotes and escapes it, as a JSON string.

No equivalent.

JSON_REMOVE
^^^^^^^^^^^

.. code-block:: text

  JSON_REMOVE(json_doc, path[, path] ...)

Removes the data at paths of a JSON document.

No equivalent.

JSON_REPLACE
^^^^^^^^^^^^

.. code-block:: text

  JSON_REPLACE(json_doc, path, val[, path, val] ...)

Replaces the values at paths of a JSON document that already have one.

No equivalent.

JSON_SCHEMA_VALID
^^^^^^^^^^^^^^^^^

.. code-block:: text

  JSON_SCHEMA_VALID(schema, document)

Tells whether a JSON document follows a JSON schema.

No equivalent.

JSON_SCHEMA_VALIDATION_REPORT
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  JSON_SCHEMA_VALIDATION_REPORT(schema, document)

Returns a JSON report of whether, and why not, a JSON document follows a JSON schema.

No equivalent.

JSON_SEARCH
^^^^^^^^^^^

.. code-block:: text

  JSON_SEARCH(json_doc, one_or_all, search_str[, escape_char[, path] ...])

Returns the paths of a JSON document where a string is found.

No equivalent.

JSON_SET
^^^^^^^^

.. code-block:: text

  JSON_SET(json_doc, path, val[, path, val] ...)

Sets the values at paths of a JSON document, adding or replacing them.

No equivalent.

JSON_STORAGE_FREE
^^^^^^^^^^^^^^^^^

.. code-block:: text

  JSON_STORAGE_FREE(json_val)

Returns how many bytes of a JSON column were freed by a partial update.

No equivalent.

JSON_STORAGE_SIZE
^^^^^^^^^^^^^^^^^

.. code-block:: text

  JSON_STORAGE_SIZE(json_val)

Returns how many bytes a JSON document takes when it's stored.

No equivalent.

JSON_TABLE
^^^^^^^^^^

.. code-block:: text

  JSON_TABLE(expr, path COLUMNS (column_list)) [AS] alias

Turns the data of a JSON document into the rows and columns of a table.

No equivalent.

JSON_TYPE
^^^^^^^^^

.. code-block:: text

  JSON_TYPE(json_val)

Returns the type of a JSON value, such as OBJECT or INTEGER.

No equivalent.

JSON_UNQUOTE
^^^^^^^^^^^^

.. code-block:: text

  JSON_UNQUOTE(json_val)

Removes the double quotes, and the escapes, of a JSON string.

No equivalent.

JSON_VALID
^^^^^^^^^^

.. code-block:: text

  JSON_VALID(val)

Tells whether a value is valid JSON.

No equivalent.

JSON_VALUE
^^^^^^^^^^

.. code-block:: text

  JSON_VALUE(json_doc, path [RETURNING type] [on_empty] [on_error])

Returns the scalar at a path of a JSON document, as a SQL type.

No equivalent.

Replication Functions
---------------------

asynchronous_connection_failover_add_managed
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  asynchronous_connection_failover_add_managed(channel, managed_type, managed_name, host, port, network_namespace, primary_weight, secondary_weight)

Adds a Group Replication group to the source list of a replication channel, for its connections to fail over to.

No equivalent.

asynchronous_connection_failover_add_source
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  asynchronous_connection_failover_add_source(channel, host, port, network_namespace, weight)

Adds a server to the source list of a replication channel, for its connections to fail over to.

No equivalent.

asynchronous_connection_failover_delete_managed
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  asynchronous_connection_failover_delete_managed(channel, managed_name)

Removes a Group Replication group from the source list of a replication channel.

No equivalent.

asynchronous_connection_failover_delete_source
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  asynchronous_connection_failover_delete_source(channel, host, port, network_namespace)

Removes a server from the source list of a replication channel.

No equivalent.

asynchronous_connection_failover_reset
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  asynchronous_connection_failover_reset()

Removes every setting of the asynchronous connection failover of a server.

No equivalent.

group_replication_disable_member_action
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  group_replication_disable_member_action(name, event)

Turns off an action that group members take on an event.

No equivalent.

group_replication_enable_member_action
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  group_replication_enable_member_action(name, event)

Turns on an action that group members take on an event.

No equivalent.

group_replication_get_communication_protocol
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  group_replication_get_communication_protocol()

Returns the version of the protocol that the group communicates with.

No equivalent.

group_replication_get_write_concurrency
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  group_replication_get_write_concurrency()

Returns how many consensus instances the group can run in parallel.

No equivalent.

group_replication_reset_member_actions
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  group_replication_reset_member_actions()

Puts the member actions of a server back to their defaults.

No equivalent.

group_replication_set_as_primary
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  group_replication_set_as_primary(member_uuid[, timeout])

Makes a member the primary of a single-primary group.

No equivalent.

group_replication_set_communication_protocol
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  group_replication_set_communication_protocol(version)

Changes the version of the protocol that the group communicates with.

No equivalent.

group_replication_set_write_concurrency
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  group_replication_set_write_concurrency(instances)

Changes how many consensus instances the group can run in parallel.

No equivalent.

group_replication_switch_to_multi_primary_mode
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  group_replication_switch_to_multi_primary_mode()

Switches a group to having every member as a primary.

No equivalent.

group_replication_switch_to_single_primary_mode
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  group_replication_switch_to_single_primary_mode([member_uuid])

Switches a group to having one primary.

No equivalent.

GTID_SUBSET
^^^^^^^^^^^

.. code-block:: text

  GTID_SUBSET(set1, set2)

Tells whether every GTID of one set is in another.

No equivalent.

GTID_SUBTRACT
^^^^^^^^^^^^^

.. code-block:: text

  GTID_SUBTRACT(set1, set2)

Returns the GTIDs of one set that aren't in another.

No equivalent.

MASTER_POS_WAIT
^^^^^^^^^^^^^^^

.. code-block:: text

  MASTER_POS_WAIT(log_name, log_pos[, timeout][, channel])

An older name for SOURCE_POS_WAIT.

No equivalent.

SOURCE_POS_WAIT
^^^^^^^^^^^^^^^

.. code-block:: text

  SOURCE_POS_WAIT(log_name, log_pos[, timeout][, channel])

Waits until a replica has applied the changes up to a position of the binary log of its source.

No equivalent.

WAIT_FOR_EXECUTED_GTID_SET
^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  WAIT_FOR_EXECUTED_GTID_SET(gtid_set[, timeout])

Waits until the server has applied every transaction of a GTID set.

No equivalent.

Aggregate Functions
-------------------

AVG
^^^

Returns the average of the values that aren't ``NULL``.

.. code-block:: sql

  -- AVG([DISTINCT] expr)
  SELECT AVG(/*expr*/) FROM /*table*/;
  -- SELECT AVG(price) FROM products
  SELECT AVG(price) FROM products;
  -- COL1: 2.1875000000000000

The average of a ``DECIMAL`` keeps its number of decimal places, so it's
rounded down to 2.18, where MySQL adds 4 decimal places (2.187500). Use
``AVG(CAST(price AS DOUBLE PRECISION))`` for the exact average.

BIT_AND
^^^^^^^

Returns the bitwise AND of all the values.

.. code-block:: sql

  -- BIT_AND(expr)
  SELECT BIT_AND(/*expr*/) FROM /*table*/;
  -- SELECT BIT_AND(qty) FROM products
  SELECT BIT_AND(qty) FROM products;
  -- warning 01003: null value eliminated in set function
  -- COL1: 0

``BIT_AND`` is a vsql extension. The value must be a ``SMALLINT``,
``INTEGER`` or ``BIGINT``, and the result has the same type. With no rows (or
only ``NULL`` values) the result is ``NULL``, where MySQL returns a value with
every bit set. Use ``COALESCE(BIT_AND(qty), -1)`` to get the same bits. MySQL's result is always
an unsigned ``BIGINT``, so a negative result is a large positive number there.

BIT_OR
^^^^^^

Returns the bitwise OR of all the values.

.. code-block:: sql

  -- BIT_OR(expr)
  SELECT BIT_OR(/*expr*/) FROM /*table*/;
  -- SELECT BIT_OR(qty) FROM products
  SELECT BIT_OR(qty) FROM products;
  -- warning 01003: null value eliminated in set function
  -- COL1: 47

``BIT_OR`` is a vsql extension. The value must be a ``SMALLINT``,
``INTEGER`` or ``BIGINT``, and the result has the same type. With no rows (or
only ``NULL`` values) the result is ``NULL``, where MySQL returns 0. Use
``COALESCE(BIT_OR(qty), 0)`` to get the same result. MySQL's result is always
an unsigned ``BIGINT``, so a negative result is a large positive number there.

BIT_XOR
^^^^^^^

Returns the bitwise XOR of all the values.

.. code-block:: sql

  -- BIT_XOR(expr)
  SELECT BIT_XOR(/*expr*/) FROM /*table*/;
  -- SELECT BIT_XOR(qty) FROM products
  SELECT BIT_XOR(qty) FROM products;
  -- warning 01003: null value eliminated in set function
  -- COL1: 39

``BIT_XOR`` is a vsql extension. The value must be a ``SMALLINT``,
``INTEGER`` or ``BIGINT``, and the result has the same type. With no rows (or
only ``NULL`` values) the result is ``NULL``, where MySQL returns 0. Use
``COALESCE(BIT_XOR(qty), 0)`` to get the same result. MySQL's result is always
an unsigned ``BIGINT``, so a negative result is a large positive number there.

COUNT
^^^^^

Counts the rows, or the values that aren't ``NULL``, optionally only the
distinct ones.

.. code-block:: sql

  -- COUNT(*)
  SELECT COUNT(*) FROM /*table*/;
  -- SELECT COUNT(*) FROM products
  SELECT COUNT(*) FROM products;
  -- COL1: 4

  -- COUNT(DISTINCT expr)
  SELECT COUNT(DISTINCT /*expr*/) FROM /*table*/;
  -- SELECT COUNT(DISTINCT price > 2) FROM products
  SELECT COUNT(DISTINCT price > 2) FROM products;
  -- COL1: 2

``COUNT(expr)`` counts the values that aren't ``NULL`` in the same way.

GROUP_CONCAT
^^^^^^^^^^^^

Joins the values of a group into one string.

.. code-block:: sql

  -- GROUP_CONCAT(expr ORDER BY expr SEPARATOR sep)
  SELECT LISTAGG(/*expr*/, /*sep*/) WITHIN GROUP (ORDER BY /*expr*/) FROM /*table*/;
  -- SELECT GROUP_CONCAT(name ORDER BY name SEPARATOR ', ') FROM products
  SELECT LISTAGG(name, ', ') WITHIN GROUP (ORDER BY name) FROM products;
  -- COL1: Apple, Banana, Cherry, Date

The separator is required (MySQL uses a comma when it's left out), and so is
the ``WITHIN GROUP``. ``DISTINCT`` works in the same way. MySQL cuts the result
at 1024 bytes by default (``group_concat_max_len``).

JSON_ARRAYAGG
^^^^^^^^^^^^^

.. code-block:: text

  JSON_ARRAYAGG(col_or_expr) [over_clause]

Aggregates values into a JSON array.

No equivalent.

JSON_OBJECTAGG
^^^^^^^^^^^^^^

.. code-block:: text

  JSON_OBJECTAGG(key, value) [over_clause]

Aggregates keys and values into a JSON object.

No equivalent.

MAX
^^^

Returns the largest value.

.. code-block:: sql

  -- MAX([DISTINCT] expr)
  SELECT MAX(/*expr*/) FROM /*table*/;
  -- SELECT MAX(price) FROM products
  SELECT MAX(price) FROM products;
  -- COL1: 4.00

MIN
^^^

Returns the smallest value.

.. code-block:: sql

  -- MIN([DISTINCT] expr)
  SELECT MIN(/*expr*/) FROM /*table*/;
  -- SELECT MIN(name) FROM products
  SELECT MIN(name) FROM products;
  -- COL1: Apple

STD
^^^

Returns the population standard deviation.

.. code-block:: sql

  -- STD(expr)
  SELECT STDDEV_POP(/*expr*/) FROM /*table*/;
  -- SELECT STD(price) FROM products
  SELECT STDDEV_POP(price) FROM products;
  -- COL1: 1.429324578254e0

STDDEV
^^^^^^

Returns the population standard deviation.

.. code-block:: sql

  -- STDDEV(expr)
  SELECT STDDEV_POP(/*expr*/) FROM /*table*/;
  -- SELECT STDDEV(price) FROM products
  SELECT STDDEV_POP(price) FROM products;
  -- COL1: 1.429324578254e0

STDDEV_POP
^^^^^^^^^^

Returns the population standard deviation.

.. code-block:: sql

  -- STDDEV_POP(expr)
  SELECT STDDEV_POP(/*expr*/) FROM /*table*/;
  -- SELECT STDDEV_POP(price) FROM products
  SELECT STDDEV_POP(price) FROM products;
  -- COL1: 1.429324578254e0

STDDEV_SAMP
^^^^^^^^^^^

Returns the sample standard deviation.

.. code-block:: sql

  -- STDDEV_SAMP(expr)
  SELECT STDDEV_SAMP(/*expr*/) FROM /*table*/;
  -- SELECT STDDEV_SAMP(price) FROM products
  SELECT STDDEV_SAMP(price) FROM products;
  -- COL1: 1.650441860028e0

SUM
^^^

Adds up the values that aren't ``NULL``.

.. code-block:: sql

  -- SUM([DISTINCT] expr)
  SELECT SUM(/*expr*/) FROM /*table*/;
  -- SELECT SUM(price) FROM products
  SELECT SUM(price) FROM products;
  -- COL1: 8.75

VARIANCE
^^^^^^^^

Returns the population variance.

.. code-block:: sql

  -- VARIANCE(expr)
  SELECT VAR_POP(/*expr*/) FROM /*table*/;
  -- SELECT VARIANCE(price) FROM products
  SELECT VAR_POP(price) FROM products;
  -- COL1: 2.04296875e0

Unlike some other databases, MySQL's ``VARIANCE`` is the population variance,
so it's ``VAR_POP`` rather than ``VAR_SAMP``.

VAR_POP
^^^^^^^

Returns the population variance.

.. code-block:: sql

  -- VAR_POP(expr)
  SELECT VAR_POP(/*expr*/) FROM /*table*/;
  -- SELECT VAR_POP(price) FROM products
  SELECT VAR_POP(price) FROM products;
  -- COL1: 2.04296875e0

VAR_SAMP
^^^^^^^^

Returns the sample variance.

.. code-block:: sql

  -- VAR_SAMP(expr)
  SELECT VAR_SAMP(/*expr*/) FROM /*table*/;
  -- SELECT VAR_SAMP(price) FROM products
  SELECT VAR_SAMP(price) FROM products;
  -- COL1: 2.723958333333e0

Window Functions
----------------

CUME_DIST
^^^^^^^^^

Returns the fraction of the rows that sort before or with the current row.

.. code-block:: sql

  -- CUME_DIST() OVER (ORDER BY expr)
  SELECT CAST((SELECT COUNT(*) FROM /*table*/ AS t2 WHERE t2./*expr*/ <= t./*expr*/) AS DOUBLE PRECISION) / (SELECT COUNT(*) FROM /*table*/) FROM /*table*/ AS t;
  -- SELECT name, CUME_DIST() OVER (ORDER BY price) AS cd FROM products ORDER BY price
  SELECT name, CAST((SELECT COUNT(*) FROM products AS p2 WHERE p2.price <= p.price) AS DOUBLE PRECISION)
    / (SELECT COUNT(*) FROM products) AS cd
  FROM products AS p ORDER BY price;
  -- NAME: Banana CD: 0.25e0
  -- NAME: Apple CD: 0.5e0
  -- NAME: Date CD: 0.75e0
  -- NAME: Cherry CD: 1e0

vsql has no window functions, so a subquery counts the rows for each row.
``CUME_DIST(value) WITHIN GROUP (ORDER BY expr)`` gives it for one value.

DENSE_RANK
^^^^^^^^^^

Ranks the rows by an order, with no gaps after rows that are equal.

.. code-block:: sql

  -- DENSE_RANK() OVER (ORDER BY expr)
  SELECT (SELECT COUNT(DISTINCT t2./*expr*/) FROM /*table*/ AS t2 WHERE t2./*expr*/ < t./*expr*/) + 1 FROM /*table*/ AS t;
  -- SELECT name, DENSE_RANK() OVER (ORDER BY price) AS r FROM products ORDER BY price
  SELECT name, (SELECT COUNT(DISTINCT p2.price) FROM products AS p2 WHERE p2.price < p.price) + 1 AS r
  FROM products AS p ORDER BY price;
  -- NAME: Banana R: 1
  -- NAME: Apple R: 2
  -- NAME: Date R: 3
  -- NAME: Cherry R: 4

FIRST_VALUE
^^^^^^^^^^^

Returns a value from the first row of the window.

.. code-block:: sql

  -- FIRST_VALUE(expr) OVER (ORDER BY order_expr)
  SELECT (SELECT t2./*expr*/ FROM /*table*/ AS t2 ORDER BY t2./*order_expr*/ FETCH FIRST 1 ROW ONLY) FROM /*table*/ AS t;
  -- SELECT name, FIRST_VALUE(name) OVER (ORDER BY price) AS f FROM products ORDER BY price
  SELECT name, (SELECT p2.name FROM products AS p2 ORDER BY p2.price FETCH FIRST 1 ROW ONLY) AS f
  FROM products AS p ORDER BY price;
  -- NAME: Banana F: Banana
  -- NAME: Apple F: Banana
  -- NAME: Date F: Banana
  -- NAME: Cherry F: Banana

LAG
^^^

Returns a value from the row before the current row.

.. code-block:: sql

  -- LAG(expr) OVER (ORDER BY order_expr)
  SELECT (SELECT t2./*expr*/ FROM /*table*/ AS t2 WHERE t2./*order_expr*/ < t./*order_expr*/ ORDER BY t2./*order_expr*/ DESC FETCH FIRST 1 ROW ONLY) FROM /*table*/ AS t;
  -- SELECT name, LAG(name) OVER (ORDER BY price) AS prev FROM products ORDER BY price
  SELECT name, (SELECT p2.name FROM products AS p2 WHERE p2.price < p.price
    ORDER BY p2.price DESC FETCH FIRST 1 ROW ONLY) AS prev
  FROM products AS p ORDER BY price;
  -- NAME: Banana PREV: NULL
  -- NAME: Apple PREV: Banana
  -- NAME: Date PREV: Apple
  -- NAME: Cherry PREV: Date

For ``LAG(expr, N)``, add ``OFFSET N - 1 ROWS``, and for a default other than
``NULL`` wrap the subquery in ``COALESCE``. Rows with equal values of
``order_expr`` need another column to break the tie.

LAST_VALUE
^^^^^^^^^^

Returns a value from the last row of the window.

.. code-block:: sql

  -- LAST_VALUE(expr) OVER (ORDER BY order_expr ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
  SELECT (SELECT t2./*expr*/ FROM /*table*/ AS t2 ORDER BY t2./*order_expr*/ DESC FETCH FIRST 1 ROW ONLY) FROM /*table*/ AS t;
  -- SELECT name, LAST_VALUE(name) OVER (ORDER BY price ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS l FROM products ORDER BY price
  SELECT name, (SELECT p2.name FROM products AS p2 ORDER BY p2.price DESC FETCH FIRST 1 ROW ONLY) AS l
  FROM products AS p ORDER BY price;
  -- NAME: Banana L: Cherry
  -- NAME: Apple L: Cherry
  -- NAME: Date L: Cherry
  -- NAME: Cherry L: Cherry

With the default window, which ends at the current row, ``LAST_VALUE`` is the
current row's own value.

LEAD
^^^^

Returns a value from the row after the current row.

.. code-block:: sql

  -- LEAD(expr) OVER (ORDER BY order_expr)
  SELECT (SELECT t2./*expr*/ FROM /*table*/ AS t2 WHERE t2./*order_expr*/ > t./*order_expr*/ ORDER BY t2./*order_expr*/ FETCH FIRST 1 ROW ONLY) FROM /*table*/ AS t;
  -- SELECT name, LEAD(name) OVER (ORDER BY price) AS next FROM products ORDER BY price
  SELECT name, (SELECT p2.name FROM products AS p2 WHERE p2.price > p.price
    ORDER BY p2.price FETCH FIRST 1 ROW ONLY) AS next
  FROM products AS p ORDER BY price;
  -- NAME: Banana NEXT: Apple
  -- NAME: Apple NEXT: Date
  -- NAME: Date NEXT: Cherry
  -- NAME: Cherry NEXT: NULL

See `LAG`_.

NTH_VALUE
^^^^^^^^^

Returns a value from a row, by its position, of the window.

.. code-block:: sql

  -- NTH_VALUE(expr, N) OVER (ORDER BY order_expr ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
  SELECT (SELECT t2./*expr*/ FROM /*table*/ AS t2 ORDER BY t2./*order_expr*/ OFFSET /*N - 1*/ ROWS FETCH FIRST 1 ROW ONLY) FROM /*table*/ AS t;
  -- SELECT name, NTH_VALUE(name, 2) OVER (ORDER BY price ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS n FROM products ORDER BY price
  SELECT name, (SELECT p2.name FROM products AS p2 ORDER BY p2.price OFFSET 1 ROW FETCH FIRST 1 ROW ONLY) AS n
  FROM products AS p ORDER BY price;
  -- NAME: Banana N: Apple
  -- NAME: Apple N: Apple
  -- NAME: Date N: Apple
  -- NAME: Cherry N: Apple

NTILE
^^^^^

.. code-block:: text

  NTILE(N) over_clause

Splits the rows into a number of groups of about the same size and returns the group of the current row.

No equivalent.

PERCENT_RANK
^^^^^^^^^^^^

Returns the rank of the row as a fraction from 0 to 1.

.. code-block:: sql

  -- PERCENT_RANK() OVER (ORDER BY expr)
  SELECT CAST((SELECT COUNT(*) FROM /*table*/ AS t2 WHERE t2./*expr*/ < t./*expr*/) AS DOUBLE PRECISION) / ((SELECT COUNT(*) FROM /*table*/) - 1) FROM /*table*/ AS t;
  -- SELECT name, PERCENT_RANK() OVER (ORDER BY price) AS pr FROM products ORDER BY price
  SELECT name, CAST((SELECT COUNT(*) FROM products AS p2 WHERE p2.price < p.price) AS DOUBLE PRECISION)
    / ((SELECT COUNT(*) FROM products) - 1) AS pr
  FROM products AS p ORDER BY price;
  -- NAME: Banana PR: 0e0
  -- NAME: Apple PR: 0.333333333333e0
  -- NAME: Date PR: 0.666666666667e0
  -- NAME: Cherry PR: 1e0

``PERCENT_RANK(value) WITHIN GROUP (ORDER BY expr)`` gives it for one value.

RANK
^^^^

Ranks the rows by an order, with gaps after rows that are equal.

.. code-block:: sql

  -- RANK() OVER (ORDER BY expr)
  SELECT (SELECT COUNT(*) FROM /*table*/ AS t2 WHERE t2./*expr*/ < t./*expr*/) + 1 FROM /*table*/ AS t;
  -- SELECT name, RANK() OVER (ORDER BY price) AS r FROM products ORDER BY price
  SELECT name, (SELECT COUNT(*) FROM products AS p2 WHERE p2.price < p.price) + 1 AS r
  FROM products AS p ORDER BY price;
  -- NAME: Banana R: 1
  -- NAME: Apple R: 2
  -- NAME: Date R: 3
  -- NAME: Cherry R: 4

``RANK(value) WITHIN GROUP (ORDER BY expr)`` gives the rank of one value.

ROW_NUMBER
^^^^^^^^^^

Numbers the rows in an order, from 1.

.. code-block:: sql

  -- ROW_NUMBER() OVER (ORDER BY expr)
  SELECT (SELECT COUNT(*) FROM /*table*/ AS t2 WHERE t2./*expr*/ < t./*expr*/) + 1 FROM /*table*/ AS t;
  -- SELECT name, ROW_NUMBER() OVER (ORDER BY price) AS rn FROM products ORDER BY price
  SELECT name, (SELECT COUNT(*) FROM products AS p2 WHERE p2.price < p.price) + 1 AS rn
  FROM products AS p ORDER BY price;
  -- NAME: Banana RN: 1
  -- NAME: Apple RN: 2
  -- NAME: Date RN: 3
  -- NAME: Cherry RN: 4

This is the same as `RANK`_, so it only numbers the rows one by one when
the values are all different. Add more columns to the ``WHERE`` to break the
ties.

Performance Schema Functions
----------------------------

FORMAT_BYTES
^^^^^^^^^^^^

.. code-block:: text

  FORMAT_BYTES(count)

Writes a number of bytes in a readable unit, such as 2.00 KiB.

No equivalent.

FORMAT_PICO_TIME
^^^^^^^^^^^^^^^^

.. code-block:: text

  FORMAT_PICO_TIME(time_val)

Writes a time in picoseconds in a readable unit, such as 3.00 s.

No equivalent.

PS_CURRENT_THREAD_ID
^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  PS_CURRENT_THREAD_ID()

Returns the Performance Schema thread ID of the current connection.

No equivalent.

PS_THREAD_ID
^^^^^^^^^^^^

.. code-block:: text

  PS_THREAD_ID(connection_id)

Returns the Performance Schema thread ID of a connection.

No equivalent.

Internal Functions
------------------

CAN_ACCESS_COLUMN
^^^^^^^^^^^^^^^^^

.. code-block:: text

  CAN_ACCESS_COLUMN(ARGS)

Used by INFORMATION_SCHEMA views to check that the user can see a column.

No equivalent.

CAN_ACCESS_DATABASE
^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  CAN_ACCESS_DATABASE(ARGS)

Used by INFORMATION_SCHEMA views to check that the user can see a database.

No equivalent.

CAN_ACCESS_TABLE
^^^^^^^^^^^^^^^^

.. code-block:: text

  CAN_ACCESS_TABLE(ARGS)

Used by INFORMATION_SCHEMA views to check that the user can see a table.

No equivalent.

CAN_ACCESS_USER
^^^^^^^^^^^^^^^

.. code-block:: text

  CAN_ACCESS_USER(ARGS)

Used by INFORMATION_SCHEMA views to check that the user can see a user.

No equivalent.

CAN_ACCESS_VIEW
^^^^^^^^^^^^^^^

.. code-block:: text

  CAN_ACCESS_VIEW(ARGS)

Used by INFORMATION_SCHEMA views to check that the user can see a view.

No equivalent.

GET_DD_COLUMN_PRIVILEGES
^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  GET_DD_COLUMN_PRIVILEGES(ARGS)

Used by INFORMATION_SCHEMA views to list the privileges on a column.

No equivalent.

GET_DD_CREATE_OPTIONS
^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  GET_DD_CREATE_OPTIONS(ARGS)

Used by INFORMATION_SCHEMA views to show the options a table was created with.

No equivalent.

GET_DD_INDEX_SUB_PART_LENGTH
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  GET_DD_INDEX_SUB_PART_LENGTH(ARGS)

Used by INFORMATION_SCHEMA views to show the prefix length of an index column.

No equivalent.

INTERNAL_AUTO_INCREMENT
^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  INTERNAL_AUTO_INCREMENT(ARGS)

Used by INFORMATION_SCHEMA views to show the next AUTO_INCREMENT value of a table.

No equivalent.

INTERNAL_AVG_ROW_LENGTH
^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  INTERNAL_AVG_ROW_LENGTH(ARGS)

Used by INFORMATION_SCHEMA views to show the average row length of a table.

No equivalent.

INTERNAL_CHECKSUM
^^^^^^^^^^^^^^^^^

.. code-block:: text

  INTERNAL_CHECKSUM(ARGS)

Used by INFORMATION_SCHEMA views to show the live checksum of a table.

No equivalent.

INTERNAL_CHECK_TIME
^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  INTERNAL_CHECK_TIME(ARGS)

Used by INFORMATION_SCHEMA views to show when a table was last checked.

No equivalent.

INTERNAL_DATA_FREE
^^^^^^^^^^^^^^^^^^

.. code-block:: text

  INTERNAL_DATA_FREE(ARGS)

Used by INFORMATION_SCHEMA views to show the unused space of a table.

No equivalent.

INTERNAL_DATA_LENGTH
^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  INTERNAL_DATA_LENGTH(ARGS)

Used by INFORMATION_SCHEMA views to show the size of the data of a table.

No equivalent.

INTERNAL_DD_CHAR_LENGTH
^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  INTERNAL_DD_CHAR_LENGTH(ARGS)

Used by INFORMATION_SCHEMA views to show the length of a character column.

No equivalent.

INTERNAL_GET_COMMENT_OR_ERROR
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  INTERNAL_GET_COMMENT_OR_ERROR(ARGS)

Used by INFORMATION_SCHEMA views to show the comment of a table, or why it can't be read.

No equivalent.

INTERNAL_GET_ENABLED_ROLE_JSON
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  INTERNAL_GET_ENABLED_ROLE_JSON(ARGS)

Used by INFORMATION_SCHEMA views to list the enabled roles as JSON.

No equivalent.

INTERNAL_GET_HOSTNAME
^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  INTERNAL_GET_HOSTNAME(ARGS)

Used by INFORMATION_SCHEMA views to show the host name of a session.

No equivalent.

INTERNAL_GET_USERNAME
^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  INTERNAL_GET_USERNAME(ARGS)

Used by INFORMATION_SCHEMA views to show the user name of a session.

No equivalent.

INTERNAL_GET_VIEW_WARNING_OR_ERROR
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  INTERNAL_GET_VIEW_WARNING_OR_ERROR(ARGS)

Used by INFORMATION_SCHEMA views to show why a view can't be used.

No equivalent.

INTERNAL_INDEX_COLUMN_CARDINALITY
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  INTERNAL_INDEX_COLUMN_CARDINALITY(ARGS)

Used by INFORMATION_SCHEMA views to show the estimated number of distinct values of an index column.

No equivalent.

INTERNAL_INDEX_LENGTH
^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  INTERNAL_INDEX_LENGTH(ARGS)

Used by INFORMATION_SCHEMA views to show the size of the indexes of a table.

No equivalent.

INTERNAL_IS_ENABLED_ROLE
^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  INTERNAL_IS_ENABLED_ROLE(ARGS)

Used by INFORMATION_SCHEMA views to tell whether a role is enabled.

No equivalent.

INTERNAL_IS_MANDATORY_ROLE
^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  INTERNAL_IS_MANDATORY_ROLE(ARGS)

Used by INFORMATION_SCHEMA views to tell whether a role is mandatory.

No equivalent.

INTERNAL_KEYS_DISABLED
^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  INTERNAL_KEYS_DISABLED(ARGS)

Used by INFORMATION_SCHEMA views to tell whether the indexes of a table are disabled.

No equivalent.

INTERNAL_MAX_DATA_LENGTH
^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  INTERNAL_MAX_DATA_LENGTH(ARGS)

Used by INFORMATION_SCHEMA views to show the largest size the data of a table can have.

No equivalent.

INTERNAL_TABLE_ROWS
^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  INTERNAL_TABLE_ROWS(ARGS)

Used by INFORMATION_SCHEMA views to show the estimated number of rows of a table.

No equivalent.

INTERNAL_UPDATE_TIME
^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  INTERNAL_UPDATE_TIME(ARGS)

Used by INFORMATION_SCHEMA views to show when a table was last changed.

No equivalent.

IS_VISIBLE_DD_OBJECT
^^^^^^^^^^^^^^^^^^^^

.. code-block:: text

  IS_VISIBLE_DD_OBJECT(ARGS)

Used by INFORMATION_SCHEMA views to tell whether a data dictionary object can be shown.

No equivalent.

Miscellaneous Functions
-----------------------

ANY_VALUE
^^^^^^^^^

Returns a value from any of the rows of a group, for a column that isn't in
the ``GROUP BY``.

.. code-block:: sql

  -- ANY_VALUE(arg)
  SELECT ANY_VALUE(/*arg*/) FROM /*table*/;
  -- SELECT ANY_VALUE(name) FROM products WHERE sku = 'A1'
  SELECT ANY_VALUE(name) FROM products WHERE sku = 'A1';
  -- COL1: Apple

vsql's ``ANY_VALUE`` is an aggregate, so it's only allowed where an aggregate
is, and it skips ``NULL`` values.

BIN_TO_UUID
^^^^^^^^^^^

.. code-block:: text

  BIN_TO_UUID(binary_uuid[, swap_flag])

Writes a UUID stored as 16 bytes in its usual text form.

No equivalent.

DEFAULT
^^^^^^^

.. code-block:: text

  DEFAULT(col_name)

Returns the default value of a column.

No equivalent.

GROUPING
^^^^^^^^

.. code-block:: text

  GROUPING(expr [, expr] ...)

Tells whether a row of a GROUP BY ... WITH ROLLUP is a super-aggregate row for an expression.

No equivalent.

INET6_ATON
^^^^^^^^^^

.. code-block:: text

  INET6_ATON(expr)

Turns an IPv6 or IPv4 address into its bytes.

No equivalent.

INET6_NTOA
^^^^^^^^^^

.. code-block:: text

  INET6_NTOA(expr)

Writes the bytes of an IPv6 or IPv4 address in their usual text form.

No equivalent.

INET_ATON
^^^^^^^^^

.. code-block:: text

  INET_ATON(expr)

Turns an IPv4 address into a number.

No equivalent.

INET_NTOA
^^^^^^^^^

.. code-block:: text

  INET_NTOA(expr)

Writes an IPv4 address stored as a number in its dotted form.

No equivalent.

IS_IPV4
^^^^^^^

.. code-block:: text

  IS_IPV4(expr)

Tells whether a string is a valid IPv4 address.

No equivalent.

IS_IPV4_COMPAT
^^^^^^^^^^^^^^

.. code-block:: text

  IS_IPV4_COMPAT(expr)

Tells whether the bytes of an IPv6 address are an IPv4-compatible address.

No equivalent.

IS_IPV4_MAPPED
^^^^^^^^^^^^^^

.. code-block:: text

  IS_IPV4_MAPPED(expr)

Tells whether the bytes of an IPv6 address are an IPv4-mapped address.

No equivalent.

IS_IPV6
^^^^^^^

.. code-block:: text

  IS_IPV6(expr)

Tells whether a string is a valid IPv6 address.

No equivalent.

IS_UUID
^^^^^^^

.. code-block:: text

  IS_UUID(string_uuid)

Tells whether a string is a valid UUID.

No equivalent.

NAME_CONST
^^^^^^^^^^

Returns a value as a column with a name.

.. code-block:: sql

  -- NAME_CONST(name, value)
  SELECT /*value*/ AS /*name*/ FROM (VALUES 1) AS t (x);
  -- SELECT NAME_CONST('myname', 14)
  SELECT 14 AS myname FROM (VALUES 1) AS t (x);
  -- MYNAME: 14

The name is a name, not a string, so it's written without quotes (or in double
quotes).

SLEEP
^^^^^

.. code-block:: text

  SLEEP(duration)

Waits for a number of seconds and returns 0.

No equivalent.

UUID
^^^^

.. code-block:: text

  UUID()

Returns a new version 1 UUID, as text.

No equivalent.

UUID_SHORT
^^^^^^^^^^

.. code-block:: text

  UUID_SHORT()

Returns a 64-bit number that's unique as long as the server ID and start time are.

No equivalent.

UUID_TO_BIN
^^^^^^^^^^^

.. code-block:: text

  UUID_TO_BIN(string_uuid[, swap_flag])

Turns a UUID in its text form into 16 bytes.

No equivalent.

VALUES
^^^^^^

.. code-block:: text

  VALUES(col_name)

In the ON DUPLICATE KEY UPDATE of an INSERT, returns the value the INSERT would have put in a column.

No equivalent.
