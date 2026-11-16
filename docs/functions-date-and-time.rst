Date and Time Functions
=======================

.. contents::
   :local:
   :depth: 1

These functions return the current date and time (see :doc:`dates-times` for
the types). The time is taken once for each statement, so every use in the
same statement has the same value, even if the statement takes a while. Each
execution of a prepared statement has a new time.

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
