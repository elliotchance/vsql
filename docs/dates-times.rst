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

Valid date ranges are between ``0000-01-01`` and ``9999-12-31``.

A ``DATE`` is stored as 8 bytes.

TIME(n) WITH TIME ZONE
^^^^^^^^^^^^^^^^^^^^^^

Holds a time as hour-minute-second-timezone (without respect to a date),
for example: ``15:12:47+05:30``.

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

Current Date and Time
---------------------

CURRENT_DATE
^^^^^^^^^^^^

Provides the current date (eg. ``2022-03-24``) within the time zone of the
session as a ``DATE`` type.

CURRENT_TIME(p)
^^^^^^^^^^^^^^^

Provides the time with the timezone (eg. ``15:45:55+05:00``) within the time
zone of the session as a ``TIME(p) WITH TIME ZONE`` type.

The ``(p)`` is optional and if not provided will use a value of ``0``.
Otherwise, the value of ``p`` must be between ``0`` and ``6`` and controls both
the subsecond accuracy and result type.

``CURRENT_TIME`` differs from ``LOCALTIME`` which returns the same time
component, but without the time zone.

CURRENT_TIMESTAMP(p)
^^^^^^^^^^^^^^^^^^^^

Provides the date and time with the timezone (eg. ``2022-03-24 15:45:55+05:00``)
within the time zone of the session as a ``TIMESTAMP WITH TIME ZONE`` type.

The ``(p)`` is optional and if not provided will use a value of ``6``.
Otherwise, the value of ``p`` must be between ``0`` and ``6`` and controls both
the subsecond accuracy and result type.

``CURRENT_TIMESTAMP`` differs from ``LOCALTIMESTAMP`` which returns the same
date and time component, but without the time zone.

LOCALTIME(p)
^^^^^^^^^^^^

Provides the time with the time zone (eg. ``15:45:55``) within the time zone
of the session as a ``TIME(p) WITHOUT TIME ZONE`` type.

The ``(p)`` is optional and if not provided will use a value of ``0``.
Otherwise, the value of ``p`` must be between ``0`` and ``6`` and controls both
the subsecond accuracy and result type.

``LOCALTIME`` differs from ``CURRENT_TIME`` which returns the same time
component, but also includes the time zone.

LOCALTIMESTAMP(p)
^^^^^^^^^^^^^^^^^

Provides the date and time without the time zone (eg. ``2022-03-24 15:45:55``)
within the time zone of the session as a ``TIMESTAMP WITHOUT TIME ZONE`` type.

The ``(p)`` is optional and if not provided will use a value of ``6``.
Otherwise, the value of ``p`` must be between ``0`` and ``6`` and controls both
the subsecond accuracy and result type.

``LOCALTIMESTAMP`` differs from ``CURRENT_TIMESTAMP`` which returns the same
date and time component, but includes the time zone.
