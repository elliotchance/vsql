Data Types
==========

.. contents::

Boolean Types
-------------

``BOOLEAN``
^^^^^^^^^^^

A ``BOOLEAN`` may only store a ``TRUE``, ``FALSE`` or ``UNKNOWN`` value (not
including a possible ``NULL``).

Numeric Types
-------------

``BIGINT``
^^^^^^^^^^

``BIGINT`` is an integer type.

``DOUBLE PRECISION``
^^^^^^^^^^^^^^^^^^^^

``DOUBLE PRECISION`` is a 64-bit floating point number.

The ``FLOAT(n)`` and ``FLOAT`` are aliases.

**TODO**

1. The *n* in ``FLOAT(n)`` does not have any affect.

``INTEGER``
^^^^^^^^^^^

The type ``INT`` is an alias for ``INTEGER``.

**TODO**

1. The range of possible values is not enforced.

``REAL``
^^^^^^^^

A ``REAL`` is a 32bit floating-point number.

``SMALLINT``
^^^^^^^^^^^^

**TODO**

1. The range of possible values is not enforced.

Text Types
----------

``CHARACTER VARYING(n)``
^^^^^^^^^^^^^^^^^^^^^^^^

A ``CHARACTER VARYING(n)`` can store up to *n* characters.

The types ``CHAR VARYING(n)`` and ``VARCHAR(n)`` are aliases for
``CHARACTER VARYING(n)``.

**TODO**

1. The *n* limit is not yet enforced.

``CHARACTER(n)``
^^^^^^^^^^^^^^^^

A ``CHARACTER(n)`` can store up to *n* characters. ``CHARACTER(n)`` differs from
``CHARACTER VARYING(n)`` in that a ``CHARACTER(n)`` will always be a length of
*n*. For values that have a lesser length, the value will be padded with spaces.

The types ``CHAR(n)`` are an alias. ``CHARACTER`` and ``CHAR`` (without a size)
is an alias for ``CHARACTER(1)``.

**TODO**

1. The *n* limit is not yet enforced.
2. Values are not actually space padded.

Date and Time Types
-------------------

``DATE``
^^^^^^^^

A ``DATE`` holds a year-month-day value, such as ``2010-10-25``.

A ``DATE`` value can be created with the ``DATE '2010-10-25'`` literal
expression.

Valid date ranges are between ``0000-01-01`` and ``9999-12-31``.

A ``DATE`` is stored as 8 bytes.

``TIME(n) WITH TIME ZONE``
^^^^^^^^^^^^^^^^^^^^^^^^^^

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

``TIME(n) WITHOUT TIME ZONE``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

This works the same way as ``TIME(n) WITH TIME ZONE`` except there is no
time zone component.

A ``TIME WITHOUT TIME ZONE`` (with any precision) is stored as 8 bytes.

``TIMESTAMP(n) WITH TIME ZONE``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

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

``TIMESTAMP(n) WITHOUT TIME ZONE``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

This works the same way as ``TIMESTAMP(n) WITH TIME ZONE`` except there is no
time zone component.

A ``TIMESTAMP WITHOUT TIME ZONE`` (with any precision) is stored as 8 bytes.

Unsupported Data Types
----------------------

<character large object type>
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

1. ``CHARACTER LARGE OBJECT``
2. ``CHAR LARGE OBJECT``
3. ``CLOB``

<national character string type>
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

1. ``NATIONAL CHARACTER``
2. ``NATIONAL CHAR``
3. ``NCHAR``
4. ``NATIONAL CHARACTER VARYING``
5. ``NATIONAL CHAR VARYING``
6. ``NCHAR VARYING``

<national character large object type>
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

1. ``NATIONAL CHARACTER LARGE OBJECT``
2. ``NCHAR LARGE OBJECT``
3. ``NCLOB``

<binary string type>
^^^^^^^^^^^^^^^^^^^^

1. ``BINARY``
2. ``BINARY VARYING``
3. ``VARBINARY``

<binary large object string type>
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

1. ``BINARY LARGE OBJECT``
2. ``BLOB``

<exact numeric type>
^^^^^^^^^^^^^^^^^^^^

Some are supported, but the remaining ones that are not supported:

1. ``NUMERIC``
2. ``DECIMAL``
3. ``DEC``

<decimal floating-point type>
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

1. ``DECFLOAT``

<interval type>
^^^^^^^^^^^^^^^

1. ``INTERVAL``

<row type>
^^^^^^^^^^

1. ``ROW``

<reference type>
^^^^^^^^^^^^^^^^

1. ``REF``

<array type>
^^^^^^^^^^^^

1. ``ARRAY``

<multiset type>
^^^^^^^^^^^^^^^

1. ``MULTISET``
