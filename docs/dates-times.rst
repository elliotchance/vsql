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

Intervals of the same kind can be compared, and ``SUM``, ``AVG``, ``MIN``,
``MAX`` and ``ABS`` accept an interval. ``EXTRACT`` returns one field of an
interval, such as ``EXTRACT(HOUR FROM INTERVAL '25' HOUR)`` (25).

An interval can be cast to another interval of the same kind, to and from a
character string (the string is the interval literal, or just the part in
quotes), and to and from an exact number when it has one field, which is the
number of that field:

.. code-block:: sql

  VALUES CAST(INTERVAL '-1-02' YEAR TO MONTH AS VARCHAR(50));
  -- COL1: INTERVAL '-1-02' YEAR(2) TO MONTH

  VALUES CAST('3 04' AS INTERVAL DAY TO HOUR);
  -- COL1: 3 04

  VALUES CAST(90 AS INTERVAL MINUTE);
  -- COL1: 90

A string that isn't a valid interval is a ``22006`` error.

Datetime Arithmetic
-------------------

An interval can be added to or subtracted from a datetime, which keeps the type
of the datetime. The interval can only have the fields of the datetime, so a
``DATE`` can't have an ``INTERVAL HOUR`` added to it (cast it to a ``TIMESTAMP``
first). A year-month interval keeps the day of the month, and it's a ``22008``
error if that day doesn't exist (such as ``DATE '2021-01-31' + INTERVAL '1'
MONTH``), or if the year isn't between 1 and 9999. The hours of a ``TIME`` wrap
around midnight. A datetime with a time zone keeps its time zone, and the
interval is added to its UTC time.

.. code-block:: sql

  VALUES DATE '2020-01-31' + INTERVAL '1' DAY;
  -- COL1: 2020-02-01

  VALUES TIMESTAMP '2020-01-31 10:00:00' - INTERVAL '1 02:30' DAY TO MINUTE;
  -- COL1: 2020-01-30T07:30:00

  VALUES TIME '23:00:00' + INTERVAL '2' HOUR;
  -- COL1: 01:00:00

Intervals of the same kind can be added and subtracted, and an interval can be
multiplied or divided by a number, or negated. The result is truncated to the
last field of the interval, and it has a leading field precision of 8:

.. code-block:: sql

  VALUES INTERVAL '1' DAY + INTERVAL '2' HOUR;
  -- COL1: 1 02

  VALUES INTERVAL '1-06' YEAR TO MONTH * 3;
  -- COL1: 4-06

  VALUES INTERVAL '1' DAY / 3;
  -- COL1: 0

  VALUES -INTERVAL '1' DAY;
  -- COL1: -1

The difference of two datetimes is an interval with the fields that follow it,
and the subtraction must be in parentheses. Each datetime is converted to a
number of the last field first, so the difference in days between
``2020-01-01 23:00`` and ``2020-01-02 01:00`` is 1 day. A datetime with a time
zone is in the time zone of the connection first. The difference of two
``TIME`` values is less than 24 hours.

.. code-block:: sql

  VALUES (DATE '2020-03-01' - DATE '2020-02-01') DAY;
  -- COL1: 29

  VALUES (TIMESTAMP '2020-03-01 10:30:00' - TIMESTAMP '2020-02-01 00:00:00') DAY TO MINUTE;
  -- COL1: 29 10:30

  VALUES (DATE '2020-03-01' - DATE '2019-02-15') YEAR TO MONTH;
  -- COL1: 1-01

Any of the results is a ``22015`` error if it doesn't fit in the interval
type.

Subtracting Without Interval Fields
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The difference of two datetimes can also be written without the interval
fields (and without the parentheses), like PostgreSQL, Oracle and DuckDB. The
fields are chosen from the types of the datetimes:

.. list-table::
  :header-rows: 1

  * - Operands
    - Result type

  * - ``DATE - DATE``
    - ``INTERVAL DAY(8)``

  * - ``TIME - TIME`` (with or without a time zone)
    - ``INTERVAL HOUR(2) TO SECOND(f)``

  * - ``TIMESTAMP - TIMESTAMP`` (with or without a time zone)
    - ``INTERVAL DAY(8) TO SECOND(f)``

*f* is the larger fractional seconds precision of the two datetimes. ``DAY(8)``
is enough for any two dates, and ``HOUR(2)`` for any two times. Apart from the
type, it's the same as writing the fields, so the result is an ordinary
interval that can be cast, compared, extracted from and used in interval
arithmetic:

.. code-block:: sql

  VALUES DATE '2026-11-17' - DATE '2026-01-01';
  -- COL1: 320

  VALUES TIME '08:00:00' - TIME '09:15:30';
  -- COL1: -1:15:30

  VALUES TIMESTAMP '2026-11-17 14:30:00' - TIMESTAMP '2026-11-16 12:00:00';
  -- COL1: 1 02:30:00

  VALUES CAST(DATE '2026-11-17' - DATE '2026-01-01' AS INTEGER);
  -- COL1: 320

A year-month interval is never chosen, since it counts calendar months, which
is a different calculation. ``(a - b) YEAR TO MONTH`` still needs its fields.

Subtracting without the interval fields isn't in the SQL standard, so it's
flagged by ``V305-01`` (``DATE``), ``V305-02`` (``TIME``) or ``V305-03``
(``TIMESTAMP``) (see :doc:`sql-flagging`). PostgreSQL returns an
``INTEGER`` number of days for ``DATE - DATE``, and vsql returns an
``INTERVAL DAY`` (cast it to an ``INTEGER`` for the number of days).

Days, Leap Days and Time Zones
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

A day-time interval doesn't have a calendar, so these behave differently to
what you might expect:

- **A day is always exactly 24 hours.** ``INTERVAL '1' DAY`` is 86400 seconds,
  not "one calendar day". Leap seconds aren't supported, so a minute is always
  60 seconds.

- **Leap days are counted by subtraction**, since it uses the real dates:

  .. code-block:: sql

    VALUES DATE '2028-03-01' - DATE '2028-02-28';
    -- COL1: 2

    VALUES DATE '2027-03-01' - DATE '2027-02-28';
    -- COL1: 1

- **Leap days and the ends of months are a problem for year-month arithmetic,
  not subtraction.** ``DATE '2028-02-29' + INTERVAL '1' YEAR`` and ``DATE
  '2026-01-31' + INTERVAL '1' MONTH`` are a ``22008`` error (datetime field
  overflow), as in the SQL standard. PostgreSQL and MySQL use the last day of
  the month instead. To do that, add the months to the first of the month, and
  then the days, up to the last day of the month:

  .. code-block:: sql

    VALUES CASE
      WHEN EXTRACT(DAY FROM DATE '2026-01-31') > EXTRACT(DAY FROM DATE '2026-01-01' + INTERVAL '2' MONTH - INTERVAL '1' DAY)
      THEN DATE '2026-01-01' + INTERVAL '2' MONTH - INTERVAL '1' DAY
      ELSE DATE '2026-01-01' + INTERVAL '1' MONTH + INTERVAL '1' DAY * (EXTRACT(DAY FROM DATE '2026-01-31') - 1)
    END;
    -- COL1: 2026-02-28

- **A TIMESTAMP WITHOUT TIME ZONE is a wall clock time.** It has no time zone,
  so the difference is the difference of the wall clock times, as if every day
  were 24 hours. Across a daylight saving change, ``02:00`` to ``02:00`` the
  next day is ``1 00:00:00``, even though 23 or 25 hours really passed. Use
  values ``WITH TIME ZONE`` for the time that really passed.

- **A TIMESTAMP WITH TIME ZONE is subtracted in UTC**, so the difference is the
  exact time that passed, and the same instant with different time zones is a
  difference of zero:

  .. code-block:: sql

    VALUES TIMESTAMP '2026-11-17 14:30:00+05:00' - TIMESTAMP '2026-11-17 09:30:00+00:00';
    -- COL1: 0 00:00:00

- **Adding a day to a value WITH TIME ZONE adds exactly 24 hours and keeps its
  time zone.** A vsql time zone is a fixed offset from UTC (like the SQL
  standard), with no daylight saving rules, so across a daylight saving change
  the result still has the old offset, and its local time can be an hour
  different to "the same time tomorrow". PostgreSQL, which has named time
  zones, keeps the wall clock time for ``+ INTERVAL '1 day'``, but not for ``+
  INTERVAL '24 hours'``.

Other databases count the difference in other ways: MySQL's ``TIMEDIFF``
returns a ``TIME`` (up to ``838:59:59``), MySQL's ``TIMESTAMPDIFF`` and SQL
Server's ``DATEDIFF`` count a number of units (or unit boundaries) with the
arguments in the order ``b, a``, and PostgreSQL's ``age()`` returns years,
months and days.

A dynamic parameter added to a ``DATE`` is an ``INTERVAL YEAR TO MONTH``, one
added to a ``TIME`` is an ``INTERVAL HOUR TO SECOND`` and one added to a
``TIMESTAMP`` is an ``INTERVAL DAY TO SECOND``. A dynamic parameter followed by
interval fields (such as ``? DAY``) is an interval of that type.

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

``<expr> AT TIME ZONE <interval>`` puts a ``TIME`` or ``TIMESTAMP`` into the
time zone of an ``INTERVAL HOUR TO MINUTE`` in the same way, which must be
between ``-14:00`` and ``+14:00`` (otherwise it's a ``22009`` error). A value
without a time zone is taken to be in the time zone of the connection first:

.. code-block:: sql

  VALUES TIMESTAMP '2022-07-04 12:00:00+00:00' AT TIME ZONE INTERVAL '05:30' HOUR TO MINUTE;
  -- COL1: 2022-07-04T17:30:00+0530

``AT LOCAL`` or ``AT TIME ZONE`` on a ``DATE`` (or any other type) is a
``42804`` error.

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

Formatting and Parsing
----------------------

A ``CAST`` between a date or time and a character string can have a
``FORMAT``, which is a template of fields and delimiters (SQL feature T839):

.. code-block:: sql

  VALUES CAST(TIMESTAMP '2024-03-05 14:07:09' AS VARCHAR(16) FORMAT 'YYYY-MM-DD HH24:MI');
  -- COL1: 2024-03-05 14:07

  VALUES CAST('05/03/2024 2:07 P.M.' AS TIMESTAMP(0) FORMAT 'DD/MM/YYYY HH12:MI A.M.');
  -- COL1: 2024-03-05T14:07:00

.. list-table::
  :header-rows: 1

  * - Field
    - Meaning
  * - ``YYYY``, ``YYY``, ``YY``, ``Y``
    - The year, or its last 3, 2 or 1 digits.
  * - ``RRRR``, ``RR``
    - A rounded year. ``RR`` is read as the nearest year that ends with those
      digits, from 50 years before the current year to 49 after it.
  * - ``MM``
    - The month (01 to 12).
  * - ``DD``
    - The day of the month (01 to 31).
  * - ``DDD``
    - The day of the year (001 to 366).
  * - ``HH24``
    - The hour (00 to 23).
  * - ``HH``, ``HH12``
    - The hour on a 12-hour clock (01 to 12), which must be used with
      ``A.M.`` or ``P.M.``.
  * - ``A.M.``, ``P.M.``
    - ``A.M.`` before noon, or ``P.M.`` from noon (either can be used in the
      template).
  * - ``MI``
    - The minute (00 to 59).
  * - ``SS``
    - The second (00 to 59).
  * - ``SSSSS``
    - The second of the day (00000 to 86399).
  * - ``FF1`` to ``FF9``
    - The fraction of a second, with 1 to 9 digits.
  * - ``TZH``
    - The hour of the time zone, with a sign (such as ``+05``).
  * - ``TZM``
    - The minute of the time zone (00 to 59).

The delimiters are ``-``, ``.``, ``/``, ``,``, ``'``, ``;``, ``:`` and a
space, and there can't be two of them next to each other. The fields are upper
case, and each one can only be used once. There are no names of months or days.

When a date or time is formatted, each field is its full length, with leading
zeros. The seconds are truncated (not rounded) to the digits of ``FF1`` to
``FF9``. A ``CHAR`` is padded with spaces, and a string that's too long for
the type is a ``22001`` error.

When a string is parsed, each delimiter must match exactly, and a field
between delimiters (or at the start or end) can have fewer digits, such as
``2024-3-5`` for ``YYYY-MM-DD``. A field next to another field must have all
of its digits, such as ``20240305`` for ``YYYYMMDD``. A string that doesn't
match is a ``22007`` invalid datetime format error, and spaces aren't ignored.
The fields that are missing are from the current date: a year without all 4
digits, or no year, takes the rest from the current year, no month is the
current month, no day is the first, and a time is ``00:00:00``. A time zone
that's missing is ``+00:00``.

The fields that can be used depend on the type: a ``DATE`` can only have the
date fields, a ``TIME`` only the time fields, and only a type with a time zone
can have ``TZH`` and ``TZM``. The character string type must be at least as
long as the shortest string that the template can match, otherwise it's a
``42601`` error.

A ``FORMAT`` that can use the current date can't be used in a ``CHECK``
constraint. That's a ``DATE`` or ``TIMESTAMP`` whose template doesn't have a
month and day (or ``DDD``), or whose year can have fewer than 4 digits. A
``YYYY`` between delimiters can, since ``YYYY-MM-DD`` also reads
``24-03-05``, but ``YYYYMMDD`` can't.

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
``QUARTER``, ``EPOCH``, ``JULIAN``, ``CENTURY``, ``DECADE``, ``MILLENNIUM``,
``MILLISECONDS``, ``MICROSECONDS`` and ``TIMEZONE``. See :ref:`EXTRACT <functions-date-and-time:EXTRACT>`.

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
