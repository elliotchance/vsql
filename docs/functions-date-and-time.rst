Date and Time Functions
=======================

.. contents::
   :local:
   :depth: 1

These functions return the current date and time (see :doc:`dates-times` for
the types), build one from its fields (``MAKE_DATE``, ``MAKE_TIME``,
``MAKE_TIMESTAMP`` and ``MAKE_TIMESTAMPTZ``), return a part of one
(``EXTRACT``), or round one down to the start of a unit (``DATE_TRUNC``). The current time is taken once for each statement, so every use
in the same statement has the same value, even if the statement takes a while
(except ``NOW()``). Each execution of a prepared statement has a new time.

The time zone is the time zone of the session.

CURRENT_DATE
^^^^^^^^^^^^

.. code-block:: sql

   CURRENT_DATE DATE

Provides the current date (eg. ``2022-03-24``) within the time zone of the
session. There are no parentheses (``CURRENT_DATE()`` is a syntax error).

**Compatibility**

- **SQL standard:** Core SQL (F051-06).
- **Other databases:**

  - PostgreSQL, MySQL (also ``CURDATE()``) and SQLite: ``CURRENT_DATE``. The
    SQLite date is a string in UTC.
  - SQL Server: ``CAST(GETDATE() AS DATE)``.
  - Oracle: ``CURRENT_DATE``, but it also has the time, use
    ``TRUNC(CURRENT_DATE)``.

CURRENT_TIME
^^^^^^^^^^^^

.. code-block:: sql

   CURRENT_TIME TIME(0) WITH TIME ZONE
   CURRENT_TIME(p) TIME(p) WITH TIME ZONE

Provides the time with the time zone (eg. ``15:45:55+05:00``) within the time
zone of the session.

The precision is optional and if not provided will use a value of ``0``.
Otherwise, it must be an integer between ``0`` and ``6`` (a ``42601`` error
otherwise) and controls both the subsecond accuracy and result type.

``CURRENT_TIME`` differs from ``LOCALTIME`` which returns the same time, but
without the time zone.

**Compatibility**

- **SQL standard:** F411 (time zone specification).
- **Other databases:**

  - PostgreSQL: ``CURRENT_TIME``.
  - MySQL (also ``CURTIME()``) and SQLite: ``CURRENT_TIME``, but without a time
    zone. The SQLite time is a string in UTC.
  - SQL Server: ``CAST(SYSDATETIMEOFFSET() AS TIME)``, but without a time
    zone.
  - Oracle has no ``TIME`` type.

CURRENT_TIMESTAMP
^^^^^^^^^^^^^^^^^

.. code-block:: sql

   CURRENT_TIMESTAMP TIMESTAMP(6) WITH TIME ZONE
   CURRENT_TIMESTAMP(p) TIMESTAMP(p) WITH TIME ZONE

Provides the date and time with the time zone (eg.
``2022-03-24 15:45:55.123456+05:00``) within the time zone of the session.

The precision is optional and if not provided will use a value of ``6``.
Otherwise, it must be an integer between ``0`` and ``6`` (a ``42601`` error
otherwise) and controls both the subsecond accuracy and result type.

``CURRENT_TIMESTAMP`` can be the ``DEFAULT`` of a column (see
:doc:`create-table`).

``CURRENT_TIMESTAMP`` differs from ``LOCALTIMESTAMP`` which returns the same
date and time, but without the time zone.

**Compatibility**

- **SQL standard:** F411 (time zone specification).
- **Other databases:**

  - PostgreSQL and Oracle: ``CURRENT_TIMESTAMP``. In PostgreSQL it's the time
    the transaction started, not the statement.
  - MySQL, SQL Server and SQLite: ``CURRENT_TIMESTAMP``, but without a time
    zone. The SQLite timestamp is a string in UTC. SQL Server has
    ``SYSDATETIMEOFFSET()`` for the time zone.

DATE_TRUNC
^^^^^^^^^^

.. code-block:: sql

   DATE_TRUNC(field CHARACTER VARYING, source DATE) DATE
   DATE_TRUNC(field CHARACTER VARYING, source TIME(p)) TIME(p)
   DATE_TRUNC(field CHARACTER VARYING, source TIMESTAMP(p)) TIMESTAMP(p)

Rounds a date, time or timestamp (with or without a time zone) down to the
start of a unit, and resets every smaller field to its lowest value. The result
has the same type as the source, including its precision and time zone.

The field is a character string, in any case, that must be a constant (usually
a literal), so that it's checked when the statement is compiled. It's one of:

- ``'microseconds'``, ``'milliseconds'``, ``'second'``, ``'minute'`` and
  ``'hour'``: for a ``TIME`` or ``TIMESTAMP``.
- ``'day'``: for a ``DATE`` or ``TIMESTAMP``.
- ``'week'``: the Monday of the ISO 8601 week (the same as
  ``EXTRACT(WEEK ...)``), which can be in the month or year before.
- ``'month'``, ``'quarter'`` (January 1, April 1, July 1 or October 1) and
  ``'year'``.
- ``'decade'``: the start of the year divisible by 10 (``2020-01-01`` for
  2026). There's no year 0, so the years 1 to 9 have no decade, which is a
  ``22008`` error (datetime field overflow).
- ``'century'`` and ``'millennium'``: they start in a year ending in 1, the same
  as ``EXTRACT(CENTURY ...)``, so ``2000`` is in the century that starts in
  ``1901``.

``'week'`` and larger are for a ``DATE`` or ``TIMESTAMP``. A field that the
source doesn't have (such as ``'hour'`` of a ``DATE``) is a ``42804`` error, and
a field that isn't one of these is a ``42601`` error. A field smaller than the
precision of the source returns it unchanged. A NULL source is NULL, and a NULL
field is an error.

**Examples**

.. code-block:: sql

  VALUES DATE_TRUNC('month', TIMESTAMP '2026-11-17 14:35:21.5');
  -- COL1: 2026-11-01T00:00:00.0

  VALUES DATE_TRUNC('hour', TIMESTAMP '2026-11-17 14:35:21.5');
  -- COL1: 2026-11-17T14:00:00.0

  VALUES DATE_TRUNC('week', DATE '2026-11-17');
  -- COL1: 2026-11-16

  VALUES DATE_TRUNC('quarter', DATE '2026-11-17');
  -- COL1: 2026-10-01

It's the usual way to group rows by a period, or to filter a range:

.. code-block:: sql

  SELECT first_day, COUNT(*)
  FROM (SELECT DATE_TRUNC('month', created_at) AS first_day FROM orders) AS t
  GROUP BY first_day
  ORDER BY first_day;

  SELECT * FROM orders
  WHERE created_at >= DATE_TRUNC('month', CURRENT_TIMESTAMP);

**Pitfalls**

``DATE_TRUNC`` is in many databases, but the details differ:

- **The first day of the week** is always a Monday (ISO 8601), like in
  PostgreSQL. Snowflake (``WEEK_START``), BigQuery (``WEEK(SUNDAY)``) and SQL
  Server (``DATEFIRST``) can start a week on another day, so ``'week'`` can be a
  different date there. A week that starts on a Sunday is:

  .. code-block:: sql

    VALUES DATE_TRUNC('week', DATE '2026-11-17' + INTERVAL '1' DAY) - INTERVAL '1' DAY;
    -- COL1: 2026-11-15

- **Time zones.** A value ``WITH TIME ZONE`` is truncated in its own time zone,
  which it keeps, so ``DATE_TRUNC('day', TIMESTAMP '2026-11-17 01:30:00+11:00')``
  is ``2026-11-17T00:00:00+1100``. PostgreSQL truncates in the time zone of the
  session, so the same query can group rows differently in different sessions.
  Two values for the same instant with different time zones can truncate to
  different days in vsql, so convert them to one time zone first (with
  ``AT TIME ZONE``) when grouping.
- **Daylight saving time.** vsql time zones are fixed offsets, so a truncated
  value always exists and is never ambiguous. With named time zones, local
  midnight can be in an hour that's skipped or repeated.
- **The result type.** PostgreSQL's ``date_trunc('month', d)`` of a ``date`` is
  a timestamp, so code ported from PostgreSQL that relies on that might need a
  ``CAST``. In vsql it stays a ``DATE``.
- **Century and millennium boundaries** are in a year ending in 1, so
  ``DATE_TRUNC('century', DATE '2000-06-01')`` is ``1901-01-01``, not
  ``2000-01-01``.
- **It rounds down,** never to the nearest, so ``14:59`` truncated to the hour
  is ``14:00``.

**Compatibility**

- **SQL standard:** not standard. It can be built from the fields, such as
  ``MAKE_DATE(EXTRACT(YEAR FROM d), EXTRACT(MONTH FROM d), 1)``.
- **vsql:** ``DATE_TRUNC`` is ``V402-20`` (see :doc:`sql-flagging`).
- **Other databases:**

  - PostgreSQL, Snowflake, DuckDB and Redshift: ``date_trunc``, which turns a
    ``date`` into a timestamp. PostgreSQL has no ``time`` version.
  - SQL Server 2022: ``DATETRUNC(month, d)``.
  - BigQuery: ``DATE_TRUNC`` and ``TIMESTAMP_TRUNC``.
  - Oracle: ``TRUNC(d, 'MM')``.
  - MySQL: ``DATE_FORMAT(d, '%Y-%m-01')``, as a string.
  - SQLite: ``date(d, 'start of month')``, as a string.
  - ClickHouse: ``toStartOfMonth`` and the others.

EXTRACT
^^^^^^^

.. code-block:: sql

   EXTRACT(YEAR FROM DATE or TIMESTAMP) INTEGER
   EXTRACT(MONTH FROM DATE or TIMESTAMP) INTEGER
   EXTRACT(DAY FROM DATE or TIMESTAMP) INTEGER
   EXTRACT(HOUR FROM TIME or TIMESTAMP) INTEGER
   EXTRACT(MINUTE FROM TIME or TIMESTAMP) INTEGER
   EXTRACT(SECOND FROM TIME(p) or TIMESTAMP(p)) NUMERIC(p + 2, p)
   EXTRACT(TIMEZONE_HOUR FROM TIME or TIMESTAMP WITH TIME ZONE) INTEGER
   EXTRACT(TIMEZONE_MINUTE FROM TIME or TIMESTAMP WITH TIME ZONE) INTEGER
   EXTRACT(DOW FROM DATE or TIMESTAMP) INTEGER
   EXTRACT(ISODOW FROM DATE or TIMESTAMP) INTEGER
   EXTRACT(DOY FROM DATE or TIMESTAMP) INTEGER
   EXTRACT(WEEK FROM DATE or TIMESTAMP) INTEGER
   EXTRACT(ISOYEAR FROM DATE or TIMESTAMP) INTEGER
   EXTRACT(QUARTER FROM DATE or TIMESTAMP) INTEGER
   EXTRACT(EPOCH FROM DATE or TIMESTAMP(p)) NUMERIC(p + 12, p)
   EXTRACT(JULIAN FROM DATE) NUMERIC(7)
   EXTRACT(JULIAN FROM TIMESTAMP) NUMERIC(19, 12)
   EXTRACT(CENTURY FROM DATE or TIMESTAMP) INTEGER
   EXTRACT(DECADE FROM DATE or TIMESTAMP) INTEGER
   EXTRACT(MILLENNIUM FROM DATE or TIMESTAMP) INTEGER
   EXTRACT(MILLISECONDS FROM TIME(p) or TIMESTAMP(p)) NUMERIC(5 + s, s)
   EXTRACT(MICROSECONDS FROM TIME or TIMESTAMP) INTEGER
   EXTRACT(TIMEZONE FROM TIME or TIMESTAMP WITH TIME ZONE) INTEGER

Returns one field of a date, time or timestamp, with or without a time zone.
The field must be part of the type: a ``DATE`` has no ``HOUR``, and only a
value ``WITH TIME ZONE`` has ``TIMEZONE_HOUR`` and ``TIMEZONE_MINUTE``.
Otherwise it's a ``42804`` error. The fields of a value with a time zone are its
local date and time, not UTC.

``SECOND`` keeps the fraction of a second, so its scale is the precision of the
value. The time zone fields have the sign of the time zone, so ``-05:30`` is
``-5`` hours and ``-30`` minutes.

.. code-block:: sql

  VALUES EXTRACT(YEAR FROM DATE '2022-03-24');
  -- COL1: 2022

  VALUES EXTRACT(SECOND FROM TIMESTAMP '2022-03-24 15:45:55.120');
  -- COL1: 55.120

  VALUES EXTRACT(TIMEZONE_HOUR FROM TIME '15:45:55-05:30');
  -- COL1: -5

These fields aren't in the standard, and have the same meaning as in
PostgreSQL:

- ``DOW``: the day of the week, from ``0`` (Sunday) to ``6`` (Saturday).
- ``ISODOW``: the ISO 8601 day of the week, from ``1`` (Monday) to ``7``
  (Sunday).
- ``DOY``: the day of the year, from ``1`` to ``366``.
- ``WEEK``: the ISO 8601 week, from ``1`` to ``53``. A week starts on a Monday
  and is in the year that has its Thursday, so ``2027-01-01`` is in week 53 of
  2026.
- ``ISOYEAR``: the ISO 8601 year that ``WEEK`` is in, which is the year before
  or after for some days at the start or end of a year.
- ``QUARTER``: the quarter of the year, from ``1`` to ``4``.
- ``EPOCH``: the seconds since ``1970-01-01 00:00:00`` UTC, with the fraction
  of a second. A ``DATE`` or a ``TIMESTAMP`` without a time zone is taken to be
  UTC.
- ``JULIAN``: the Julian Day Number, plus the fraction of the day since local
  midnight for a ``TIMESTAMP`` (cut to 12 decimal places). So
  ``2026-11-17 00:00:00`` is ``2461362`` and noon is ``2461362.5``. This isn't
  the astronomical Julian date, which starts at noon UTC (and is 0.5 less, like
  SQLite's ``julianday``).
- ``CENTURY``: the century. The years 1 to 100 are the first century, so
  ``2000`` is in the 20th century and ``2001`` starts the 21st.
- ``DECADE``: the year divided by 10, so ``2026`` is ``202``.
- ``MILLENNIUM``: the millennium. The years 1 to 1000 are the first, so
  ``2001`` starts the 3rd.
- ``MILLISECONDS``: the **whole** ``SECOND`` field (not only its fraction)
  times 1000, so ``12:30:12.5`` is ``12500``. It's a ``NUMERIC`` that keeps the
  places of the precision after the first 3 (the scale ``s`` is ``p - 3``, or
  ``0``), so ``12:30:12.123456`` is ``12123.456``.
- ``MICROSECONDS``: the whole ``SECOND`` field times 1000000, so
  ``12:30:12.5`` is ``12500000``.
- ``TIMEZONE``: the time zone in seconds, with its sign, so ``+10:30`` is
  ``37800``. Like ``TIMEZONE_HOUR``, it's only for a value ``WITH TIME ZONE``.

They aren't keywords, so any other name is a ``42601`` error when the statement
is compiled.

.. code-block:: sql

  VALUES EXTRACT(DOW FROM DATE '2026-11-15');
  -- COL1: 0

  VALUES EXTRACT(WEEK FROM DATE '2027-01-01');
  -- COL1: 53

  VALUES EXTRACT(JULIAN FROM TIMESTAMP '2026-11-17 12:00:00');
  -- COL1: 2461362.500000000000

  VALUES EXTRACT(CENTURY FROM DATE '2000-06-01');
  -- COL1: 20

  VALUES EXTRACT(MILLISECONDS FROM TIME '12:30:12.5');
  -- COL1: 12500

  VALUES EXTRACT(TIMEZONE FROM TIME '12:00:00+10:30');
  -- COL1: 37800

The source can also be an ``INTERVAL`` with that field (only ``YEAR``,
``MONTH``, ``DAY``, ``HOUR``, ``MINUTE`` and ``SECOND``). The first field of the
interval is its whole number (``EXTRACT(HOUR FROM INTERVAL '25' HOUR)`` is 25),
and the result has the sign of the interval.

**Compatibility**

- **SQL standard:** F052 (intervals and datetime arithmetic), and F411 (time
  zone specification) for ``TIMEZONE_HOUR``, ``TIMEZONE_MINUTE`` and
  ``TIMEZONE``.
- **vsql:** ``DOW``, ``ISODOW``, ``DOY``, ``WEEK``, ``ISOYEAR``, ``QUARTER``
  and ``EPOCH`` are ``V402-02`` to ``V402-08``, and ``JULIAN``, ``CENTURY``,
  ``DECADE``, ``MILLENNIUM``, ``MILLISECONDS``, ``MICROSECONDS`` and
  ``TIMEZONE`` are ``V402-13`` to ``V402-19`` (see :doc:`sql-flagging`).
- **Other databases:**

  - PostgreSQL, MySQL and Oracle: ``EXTRACT``. PostgreSQL returns a
    ``NUMERIC`` for every field. MySQL doesn't keep the
    fraction of ``SECOND``.
  - SQL Server: ``DATEPART(year, d)``.
  - SQLite: ``STRFTIME('%Y', d)``, as a string.

LOCALTIME
^^^^^^^^^

.. code-block:: sql

   LOCALTIME TIME(0) WITHOUT TIME ZONE
   LOCALTIME(p) TIME(p) WITHOUT TIME ZONE

Provides the time without the time zone (eg. ``15:45:55``) within the time zone
of the session.

The precision is optional and if not provided will use a value of ``0``.
Otherwise, it must be an integer between ``0`` and ``6`` (a ``42601`` error
otherwise) and controls both the subsecond accuracy and result type.

``LOCALTIME`` differs from ``CURRENT_TIME`` which returns the same time, but
also includes the time zone.

**Compatibility**

- **SQL standard:** Core SQL (F051-07).
- **Other databases:**

  - PostgreSQL: ``LOCALTIME``.
  - MySQL: ``CURRENT_TIME`` (``LOCALTIME`` is the date and time).
  - SQL Server: ``CAST(SYSDATETIME() AS TIME)``.
  - SQLite: ``TIME('now', 'localtime')``.
  - Oracle has no ``TIME`` type.

LOCALTIMESTAMP
^^^^^^^^^^^^^^

.. code-block:: sql

   LOCALTIMESTAMP TIMESTAMP(6) WITHOUT TIME ZONE
   LOCALTIMESTAMP(p) TIMESTAMP(p) WITHOUT TIME ZONE

Provides the date and time without the time zone (eg.
``2022-03-24 15:45:55.123456``) within the time zone of the session.

The precision is optional and if not provided will use a value of ``6``.
Otherwise, it must be an integer between ``0`` and ``6`` (a ``42601`` error
otherwise) and controls both the subsecond accuracy and result type.

``LOCALTIMESTAMP`` differs from ``CURRENT_TIMESTAMP`` which returns the same
date and time, but also includes the time zone.

**Compatibility**

- **SQL standard:** Core SQL (F051-08).
- **Other databases:**

  - PostgreSQL, MySQL and Oracle: ``LOCALTIMESTAMP``.
  - SQL Server: ``SYSDATETIME()``.
  - SQLite: ``DATETIME('now', 'localtime')``.

MAKE_DATE
^^^^^^^^^

.. code-block:: sql

   MAKE_DATE(years BIGINT, months BIGINT, days BIGINT) DATE

Builds a ``DATE`` from its year, month and day. Each one is any integer
(``SMALLINT``, ``INTEGER`` or ``BIGINT``), another number is a ``42883`` error.

Each field must be valid on its own, the year from 1 to 9999, the month from 1
to 12, and the day must be in that month (including February 29 in a leap
year). Otherwise it's a ``22007`` error (invalid datetime format), the same as
a ``CAST`` of a string that isn't a valid date. Unlike the ``DATE`` function of
a spreadsheet, a field out of range never rolls over into the next unit, so
``MAKE_DATE(2024, 13, 1)`` is an error, not January 2025.

``MAKE_DATE`` is a vsql extension flagged by ``V402-09`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES MAKE_DATE(2024, 2, 29);
  -- COL1: 2024-02-29

  VALUES MAKE_DATE(2023, 2, 29);
  -- error 22007: invalid datetime format

**Compatibility**

- **SQL standard:** not standard. ``CAST`` a string, such as
  ``CAST('2024-02-29' AS DATE)``.
- **Other databases:**

  - PostgreSQL: ``MAKE_DATE``. A negative year is BC.
  - MySQL: ``STR_TO_DATE(CONCAT_WS('-', y, m, d), '%Y-%m-%d')``
    (``MAKEDATE`` takes the day of the year).
  - SQL Server: ``DATEFROMPARTS``.
  - SQLite: ``DATE(PRINTF('%04d-%02d-%02d', y, m, d))``.
  - Oracle: ``TO_DATE``, which also has a time.

MAKE_TIME
^^^^^^^^^

.. code-block:: sql

   MAKE_TIME(hours BIGINT, minutes BIGINT, seconds NUMERIC) TIME(6) WITHOUT TIME ZONE
   MAKE_TIME(hours BIGINT, minutes BIGINT, seconds DOUBLE PRECISION) TIME(6) WITHOUT TIME ZONE

Builds a ``TIME(6) WITHOUT TIME ZONE`` from its hour, minute and second. The
hour and minute are any integer, the second is any number and can have a
fraction. A fraction past 6 digits is truncated (not rounded), the same as a
``CAST`` to ``TIME(6)``, so ``MAKE_TIME(1, 2, 3.0000009)`` is
``01:02:03.000000``.

The hour must be from 0 to 23, the minute from 0 to 59 and the second at least
0 and less than 60, otherwise it's a ``22007`` error, they never roll over.
Like a ``TIME`` literal, a leap second (60 up to, but not including, 62) is
also accepted. vsql can't store a leap second, so it becomes the next minute,
the same as ``TIME '23:59:60'`` (``00:00:00``).

``MAKE_TIME`` is a vsql extension flagged by ``V402-10`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES MAKE_TIME(12, 34, 56.789);
  -- COL1: 12:34:56.789000

  VALUES MAKE_TIME(24, 0, 0);
  -- error 22007: invalid datetime format

**Compatibility**

- **SQL standard:** not standard. ``CAST`` a string, such as
  ``CAST('12:34:56.789' AS TIME(6))``.
- **Other databases:**

  - PostgreSQL: ``MAKE_TIME``. PostgreSQL allows ``24:00:00``.
  - MySQL: ``MAKETIME``, which allows hours past 23.
  - SQL Server: ``TIMEFROMPARTS``.
  - SQLite: ``TIME(PRINTF('%02d:%02d:%02d', h, m, s))``.
  - Oracle has no ``TIME`` type.

MAKE_TIMESTAMP
^^^^^^^^^^^^^^

.. code-block:: sql

   MAKE_TIMESTAMP(years BIGINT, months BIGINT, days BIGINT, hours BIGINT, minutes BIGINT, seconds NUMERIC) TIMESTAMP(6) WITHOUT TIME ZONE
   MAKE_TIMESTAMP(years BIGINT, months BIGINT, days BIGINT, hours BIGINT, minutes BIGINT, seconds DOUBLE PRECISION) TIMESTAMP(6) WITHOUT TIME ZONE

Builds a ``TIMESTAMP(6) WITHOUT TIME ZONE`` from its fields. The date fields
are the same as ``MAKE_DATE`` and the time fields are the same as
``MAKE_TIME``, including a leap second, which can roll over into the next day
(but not past 9999-12-31, a ``22007`` error).

``MAKE_TIMESTAMP`` is a vsql extension flagged by ``V402-11`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES MAKE_TIMESTAMP(2024, 2, 29, 12, 34, 56.5e0);
  -- COL1: 2024-02-29T12:34:56.500000

  VALUES MAKE_TIMESTAMP(2016, 12, 31, 23, 59, 60);
  -- COL1: 2017-01-01T00:00:00.000000

**Compatibility**

- **SQL standard:** not standard. ``CAST`` a string, such as
  ``CAST('2024-02-29 12:34:56.5' AS TIMESTAMP(6))``.
- **Other databases:**

  - PostgreSQL: ``MAKE_TIMESTAMP``.
  - MySQL: ``TIMESTAMP(MAKEDATE(y, 1) + INTERVAL m - 1 MONTH + INTERVAL d - 1
    DAY, MAKETIME(h, mi, s))``.
  - SQL Server: ``DATETIME2FROMPARTS``.
  - SQLite: ``DATETIME(PRINTF('%04d-%02d-%02d %02d:%02d:%02d', y, m, d, h, mi, s))``.
  - Oracle: ``TO_TIMESTAMP``.

MAKE_TIMESTAMPTZ
^^^^^^^^^^^^^^^^

.. code-block:: sql

   MAKE_TIMESTAMPTZ(years BIGINT, months BIGINT, days BIGINT, hours BIGINT, minutes BIGINT, seconds NUMERIC) TIMESTAMP(6) WITH TIME ZONE
   MAKE_TIMESTAMPTZ(years BIGINT, months BIGINT, days BIGINT, hours BIGINT, minutes BIGINT, seconds NUMERIC, time_zone VARCHAR) TIMESTAMP(6) WITH TIME ZONE

(and the same with a ``DOUBLE PRECISION`` second).

Builds a ``TIMESTAMP(6) WITH TIME ZONE`` from its fields, with the same rules
as ``MAKE_TIMESTAMP``. The fields are the local time in the time zone, which is
the time zone of the session, or the ``time_zone`` string. That's an offset
from UTC written the same way as in a ``TIMESTAMP`` literal, a sign followed by
two digit hours and minutes, from ``-14:00`` to ``+14:00`` (such as
``'+05:30'``). Any other string is a ``22007`` error. Named time zones (such as
``'America/New_York'`` in PostgreSQL) aren't supported.

Without a time zone, the result depends on the time zone of the session, so it
isn't deterministic and can't be used in a ``CHECK`` constraint (a ``42601``
error).

``MAKE_TIMESTAMPTZ`` is a vsql extension flagged by ``V402-12`` (see
:doc:`sql-flagging`).

**Examples**

.. code-block:: sql

  VALUES MAKE_TIMESTAMPTZ(2024, 6, 30, 12, 34, 56, '-08:00');
  -- COL1: 2024-06-30T12:34:56.000000-0800

  VALUES MAKE_TIMESTAMPTZ(2024, 6, 30, 12, 34, 56, '+14:01');
  -- error 22007: invalid datetime format

**Compatibility**

- **SQL standard:** not standard. ``CAST`` a string, such as
  ``CAST('2024-06-30 12:34:56-08:00' AS TIMESTAMP(6) WITH TIME ZONE)``.
- **Other databases:**

  - PostgreSQL: ``MAKE_TIMESTAMPTZ``, which also accepts a named time zone.
  - SQL Server: ``DATETIMEOFFSETFROMPARTS``.
  - Oracle: ``TO_TIMESTAMP_TZ``.
  - MySQL and SQLite have no type with a time zone.

NOW
^^^

.. code-block:: sql

   NOW() TIMESTAMP(6) WITH TIME ZONE

Returns the time now, read from the wall clock each time it's called. It
doesn't take a precision (``NOW(3)`` is a ``42883`` error), use
``CAST(NOW() AS TIMESTAMP(3) WITH TIME ZONE)`` instead.

This is different from ``CURRENT_TIMESTAMP``, which is the time the statement
started and is the same everywhere in the statement, even if the statement
takes a long time. ``NOW()`` can be different each time it's called, including
in the same statement:

.. code-block:: sql

   SELECT CURRENT_TIMESTAMP AS started, NOW() AS now FROM big_table;
   -- STARTED is the same for every row, NOW moves as the rows are read.

Use ``NOW()`` when you need the actual time, such as to measure how long
something takes or to record when each row was processed. Use
``CURRENT_TIMESTAMP`` when the statement needs one consistent time.

Because it can return a different value each time, ``NOW()`` is not
deterministic, so it can't be used in a ``CHECK`` constraint (a ``42601``
error). It's also a function, not a datetime value function like
``CURRENT_TIMESTAMP``, so it can't be a ``DEFAULT`` (a syntax error). Use
``CURRENT_TIMESTAMP`` for both.

``NOW`` isn't a reserved word, so it can still be the name of a table or a
column. A custom function (see :doc:`custom-functions`) can't be registered as
``now()``, because that function already exists.

**Compatibility**

- **SQL standard:** Not standard, it's a vsql extension flagged by
  ``V402-01`` (see :doc:`sql-flagging`). The standard has no function that
  reads the clock each time it's called. ``CURRENT_TIMESTAMP`` is portable, but
  it's the time the statement started.
- **Other databases:**

  - PostgreSQL: ``CLOCK_TIMESTAMP()``. PostgreSQL's ``NOW()`` is the time the
    transaction started.
  - MySQL: ``SYSDATE(6)``, without a time zone. MySQL's ``NOW()`` is the time
    the statement started.
  - SQL Server: ``SYSDATETIMEOFFSET()``.
  - SQLite: ``DATETIME('now')``, a string in UTC.
  - Oracle: ``SYSTIMESTAMP``.
