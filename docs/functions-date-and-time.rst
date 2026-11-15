Date and Time Functions
=======================

.. contents::
   :local:
   :depth: 1

These functions return the current date and time (see :doc:`dates-times` for
the types), except for ``EXTRACT``, which returns a part of a date or time.
The time is taken once for each statement, so every use in the same statement
has the same value, even if the statement takes a while. Each execution of a
prepared statement has a new time.

The time zone is the time zone of the session.

.. _function-current_date:

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

.. _function-current_time:

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

.. _function-current_timestamp:

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

.. _function-extract:

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

They aren't keywords, so any other name is a ``42601`` error when the statement
is compiled.

.. code-block:: sql

  VALUES EXTRACT(DOW FROM DATE '2026-11-15');
  -- COL1: 0

  VALUES EXTRACT(WEEK FROM DATE '2027-01-01');
  -- COL1: 53

There are no intervals, so the source can't be an ``INTERVAL``.

**Compatibility**

- **SQL standard:** F052 (intervals and datetime arithmetic), and F411 (time
  zone specification) for ``TIMEZONE_HOUR`` and ``TIMEZONE_MINUTE``. vsql
  doesn't support all of F052, which is mostly intervals.
- **vsql:** ``DOW``, ``ISODOW``, ``DOY``, ``WEEK``, ``ISOYEAR``, ``QUARTER``
  and ``EPOCH`` are ``V402-02`` to ``V402-08`` (see :doc:`sql-flagging`).
- **Other databases:**

  - PostgreSQL, MySQL and Oracle: ``EXTRACT``. PostgreSQL returns a
    ``NUMERIC`` for every field, and has more fields. MySQL doesn't keep the
    fraction of ``SECOND``.
  - SQL Server: ``DATEPART(year, d)``.
  - SQLite: ``STRFTIME('%Y', d)``, as a string.

.. _function-localtime:

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

.. _function-localtimestamp:

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

.. _function-now:

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
