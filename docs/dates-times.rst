Dates and Times
===============

.. contents::

SQL Types
---------

DATE
^^^^

A ``DATE`` holds a year-month-day value, such as ``2010-10-25``.

A ``DATE`` value can be created with the ``DATE '2010-10-25'`` literal
expression.

Valid date ranges are between ``0001-01-01`` and ``9999-12-31``. The year must
be four digits and the month and day must be two digits. The date must be valid
in the Gregorian calendar, so ``DATE '2022-02-30'`` is a syntax error.

A ``DATE`` is stored as 8 bytes.

TIME(n) WITH TIME ZONE
^^^^^^^^^^^^^^^^^^^^^^

Holds a time as hour-minute-second-timezone (without respect to a date),
for example: ``15:12:47+05:30``.

The hours, minutes and seconds must be two digits each. Seconds may be ``60`` or
``61`` to allow for leap seconds, but these will roll over into the next minute
(so ``TIME '23:59:60'`` is ``00:00:00``).
The time zone must be between ``-14:00`` and ``+14:00`` (the SQL standard leaves
the range for each database to choose, as long as it reaches ``-12:00`` and
``+14:00``).

The ``(n)`` describes the sub-second resolution to be stored. It must be
inclusively between 0 (whole seconds) and 6 (microseconds). If omitted, 0 is
used.

A ``TIME(n) WITH TIME ZONE`` value is created with the ``TIME 'VALUE'`` literal
expression. The ``VALUE`` itself will determine whether the time has a time zone
and its precision. For example:

.. list-table::
  :header-rows: 1

  * - Expr
    - Type

  * - ``TIME '15:12:47'``
    - ``TIME(0) WITHOUT TIME ZONE``

  * - ``TIME '15:12:47.123'``
    - ``TIME(3) WITHOUT TIME ZONE``

  * - ``TIME '15:12:47+05:30'``
    - ``TIME(0) WITH TIME ZONE``

  * - ``TIME '15:12:47.000000+05:30'``
    - ``TIME(6) WITH TIME ZONE``

A ``TIME WITH TIME ZONE`` (with any precision) is stored as 10 bytes.

TIME(n) WITHOUT TIME ZONE
^^^^^^^^^^^^^^^^^^^^^^^^^

This works the same way as ``TIME(n) WITH TIME ZONE`` except there is no
time zone component.

A ``TIME WITHOUT TIME ZONE`` (with any precision) is stored as 8 bytes.

TIMESTAMP(n) WITH TIME ZONE
^^^^^^^^^^^^^^^^^^^^^^^^^^^

Holds a timestamp as year-month-day-hour-minute-second-timezone, for example:
``2010-10-25 15:12:47+05:30``.

The ``(n)`` describes the sub-second resolution to be stored. It must be
inclusively between 0 (whole seconds) and 6 (microseconds). If omitted, 6 is
used. This is different from the behavior of ``TIME`` that uses 0 by default.

A ``TIMESTAMP(n) WITH TIME ZONE`` value is created with the
``TIMESTAMP 'VALUE'`` literal expression. The ``VALUE`` itself will determine
whether the timestamp has a time zone and its precision. For example:

.. list-table::
  :header-rows: 1

  * - Expr
    - Type

  * - ``TIMESTAMP '2010-10-25 15:12:47'``
    - ``TIMESTAMP(0) WITHOUT TIME ZONE``

  * - ``TIMESTAMP '2010-10-25 15:12:47.123'``
    - ``TIMESTAMP(3) WITHOUT TIME ZONE``

  * - ``TIMESTAMP '2010-10-25 15:12:47+05:30'``
    - ``TIMESTAMP(0) WITH TIME ZONE``

  * - ``TIMESTAMP '2010-10-25 15:12:47.000000+05:30'``
    - ``TIMESTAMP(6) WITH TIME ZONE``

A ``TIMESTAMP WITH TIME ZONE`` (with any precision) is stored as 10 bytes.

TIMESTAMP(n) WITHOUT TIME ZONE
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

This works the same way as ``TIMESTAMP(n) WITH TIME ZONE`` except there is no
time zone component.

A ``TIMESTAMP WITHOUT TIME ZONE`` (with any precision) is stored as 8 bytes.

INTERVAL
^^^^^^^^

An interval is a length of time. It has one or more fields, from the start
field to the end field, in this order: ``YEAR``, ``MONTH``, ``DAY``, ``HOUR``,
``MINUTE`` and ``SECOND``. An interval of ``YEAR`` and ``MONTH`` fields is a
year-month interval, and any other interval is a day-time interval:

.. list-table::
  :header-rows: 1

  * - Type
    - Example Literal

  * - ``INTERVAL YEAR(p)``
    - ``INTERVAL '3' YEAR``

  * - ``INTERVAL YEAR(p) TO MONTH``
    - ``INTERVAL '1-2' YEAR TO MONTH``

  * - ``INTERVAL MONTH(p)``
    - ``INTERVAL '15' MONTH``

  * - ``INTERVAL DAY(p)``
    - ``INTERVAL '3' DAY``

  * - ``INTERVAL DAY(p) TO HOUR``
    - ``INTERVAL '3 04' DAY TO HOUR``

  * - ``INTERVAL DAY(p) TO MINUTE``
    - ``INTERVAL '3 04:05' DAY TO MINUTE``

  * - ``INTERVAL DAY(p) TO SECOND(f)``
    - ``INTERVAL '3 04:05:06.5' DAY TO SECOND``

  * - ``INTERVAL HOUR(p)``
    - ``INTERVAL '4' HOUR``

  * - ``INTERVAL HOUR(p) TO MINUTE``
    - ``INTERVAL '4:05' HOUR TO MINUTE``

  * - ``INTERVAL HOUR(p) TO SECOND(f)``
    - ``INTERVAL '4:05:06' HOUR TO SECOND``

  * - ``INTERVAL MINUTE(p)``
    - ``INTERVAL '5' MINUTE``

  * - ``INTERVAL MINUTE(p) TO SECOND(f)``
    - ``INTERVAL '5:06.123' MINUTE TO SECOND``

  * - ``INTERVAL SECOND(p, f)``
    - ``INTERVAL '6.25' SECOND``

*p* is the number of digits of the start field, from 1 to 8 (2 if it's not
specified). Every other field has 2 digits. *f* is the number of digits after
the decimal point of the seconds, from 0 to 6 (6 if it's not specified). A
literal must have every field of its type, and nothing else. Extra digits after
the decimal point are truncated. An interval is negative with a ``-`` before or
inside the string, such as ``INTERVAL -'1-2' YEAR TO MONTH``.

An interval is stored as 8 bytes: the number of months of a year-month
interval, or the number of microseconds of a day-time interval. When an
interval is stored in a column, the fields after the end field of the column
are removed, and it's an error (``22015``) if the start field has more digits
than the column allows. An interval can only be stored in a column of the same
kind (year-month or day-time) of interval.

Intervals can only be stored, compared as a ``PRIMARY KEY`` and cast to other
intervals for now. Datetime arithmetic and the other operators that use
intervals are not supported yet.

Comparisons
-----------

Values with a time zone are compared after adjusting them to UTC, so
``TIMESTAMP '2020-01-01 10:00:00+05:00'`` is equal to
``TIMESTAMP '2020-01-01 05:00:00+00:00'``. A ``TIME`` has no date, so its time
of day in UTC is compared, which may wrap around midnight
(``TIME '00:30:00+01:00'`` is equal to ``TIME '23:30:00+00:00'``).

When a value with a time zone is compared to one without a time zone, the value
without a time zone is treated as being in the time zone of the connection.

Time Zones
----------

Each connection has a time zone, which starts as the time zone of its clock (the
local time zone of the computer, or the one returned by ``Connection.now``). It's
the time zone of ``CURRENT_TIME`` and ``CURRENT_TIMESTAMP``, and the time zone
that a value without a time zone is in when it's compared to or cast to a value
with a time zone. :doc:`set-time-zone` sets it back to the time zone of the clock.

``<expr> AT LOCAL`` puts a ``TIME`` or ``TIMESTAMP`` into the time zone of the
connection. A value with a time zone becomes the same instant in the time zone
of the connection, and a value without a time zone is taken to already be in that
time zone. The result is always ``WITH TIME ZONE``, with the same precision:

.. code-block:: sql

  -- The time zone of the connection is +05:00.
  VALUES TIMESTAMP '2022-07-04 12:00:00-03:30' AT LOCAL;
  -- COL1: 2022-07-04T20:30:00+0500

  VALUES TIME '22:30:00-03:00' AT LOCAL;
  -- COL1: 06:30:00+0500

  VALUES TIMESTAMP '2022-07-04 12:00:00' AT LOCAL;
  -- COL1: 2022-07-04T12:00:00+0500

``AT LOCAL`` on a ``DATE`` (or any other type) is a ``42804`` error.
``AT TIME ZONE`` isn't supported yet, because it needs an ``INTERVAL``.

Casting From Strings
--------------------

A character string can be cast to any of the date and time types. Leading and
trailing spaces are ignored, and the rest must be in the same format as the
literal for that type, either with or without its keyword and quotes, otherwise
an ``22007`` invalid datetime format error is raised. A time zone that's out of
range is a ``22009`` invalid time zone displacement value error instead. The
keyword must be the one for the target type, so a ``DATE`` literal can't be cast
to a ``TIMESTAMP``:

.. code-block:: sql

  VALUES CAST(' 2022-06-30 ' AS DATE);
  -- COL1: 2022-06-30

  VALUES CAST('DATE ''2022-06-30''' AS DATE);
  -- COL1: 2022-06-30

  VALUES CAST('2022-06-30 12:34:56+03:00' AS TIMESTAMP(0) WITH TIME ZONE);
  -- COL1: 2022-06-30T12:34:56+0300

  VALUES CAST('2022-06-30' AS TIMESTAMP(0));
  -- error 22007: invalid datetime format

If the string has a time zone and the target type does not, the time zone is
dropped (keeping the local time). If the target type has a time zone and the
string does not, the session time zone is used.

Current Date and Time
---------------------

The current date and time are provided by ``CURRENT_DATE``, ``CURRENT_TIME``,
``CURRENT_TIMESTAMP``, ``LOCALTIME``, ``LOCALTIMESTAMP`` and ``NOW()``. See
:doc:`functions-date-and-time`.

Fields
------

``EXTRACT`` returns one field (``YEAR``, ``MONTH``, ``DAY``, ``HOUR``,
``MINUTE``, ``SECOND``, ``TIMEZONE_HOUR`` or ``TIMEZONE_MINUTE``) of a date,
time or timestamp, such as ``EXTRACT(YEAR FROM d)``. It also has fields that
aren't in the standard: ``DOW``, ``ISODOW``, ``DOY``, ``WEEK``, ``ISOYEAR``,
``QUARTER`` and ``EPOCH``. See :ref:`EXTRACT <functions-date-and-time:EXTRACT>`.

Building a Date or Time
-----------------------

``MAKE_DATE``, ``MAKE_TIME``, ``MAKE_TIMESTAMP`` and ``MAKE_TIMESTAMPTZ``
build a value from numbers, such as ``MAKE_DATE(2024, 2, 29)``. Each field
must be in range (a ``22007`` error otherwise). Unlike the ``DATE`` function
of a spreadsheet, they don't roll over, so ``MAKE_DATE(2024, 1, 32)`` is an
error rather than February 1. See :doc:`functions-date-and-time`.

Casting
-------

.. list-table::

  * - ↓ From / To →
    - ``DATE``
    - ``TIME(n) WITHOUT TIME ZONE``
    - ``TIME(n) WITH TIME ZONE``
    - ``TIMESTAMP(n) WITHOUT TIME ZONE``
    - ``TIMESTAMP(n) WITH TIME ZONE``

  * - ``DATE``
    - ✅
    - ❌
    - ❌
    - ✅
    - ✅

  * - ``TIME(n) WITHOUT TIME ZONE``
    - ❌
    - ✅
    - ✅
    - ✅
    - ✅

  * - ``TIME(n) WITH TIME ZONE``
    - ❌
    - ✅
    - ✅
    - ✅
    - ✅

  * - ``TIMESTAMP(n) WITHOUT TIME ZONE``
    - ✅
    - ✅
    - ✅
    - ✅
    - ✅

  * - ``TIMESTAMP(n) WITH TIME ZONE``
    - ✅
    - ✅
    - ✅
    - ✅
    - ✅

When casting a ``TIME`` to a ``TIMESTAMP`` the date will be the same as
``CURRENT_DATE``.

A ``TIME`` or ``TIMESTAMP`` that has more fractional seconds than the type it's
cast to is truncated, not rounded. The same happens when a value is stored in
a column (or assigned to a host parameter) with a smaller precision:

.. code-block:: sql

  VALUES CAST(TIMESTAMP '2020-01-02 23:30:00.999' AS TIMESTAMP(1));
  -- COL1: 2020-01-02T23:30:00.9

  VALUES CAST(TIME '12:34:56.789' AS TIME(2));
  -- COL1: 12:34:56.78

  CREATE TABLE events (at TIMESTAMP(2));
  INSERT INTO events (at) VALUES (TIMESTAMP '2020-01-02 03:04:05.129');
  SELECT * FROM events;
  -- AT: 2020-01-02T03:04:05.12

Truncating means that a value never moves into the next second (or day), which
rounding ``23:59:59.999`` up would.
