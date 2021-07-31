.. contents::

Boolean Types
=============

``BOOLEAN``
-----------

A ``BOOLEAN`` may only store a ``TRUE`, ``FALSE`` or ``UNKNOWN`` value (not
including a possible ``NULL``).

**TODO**

1. A ``BOOLEAN`` is stored in memory and on disk as a 64-bit floating point
number.

Numeric Types
=============

``BIGINT``
----------

``BIGINT`` is an integer type.

**TODO**

1. ``BIGINT`` is currently in memory and on disk as a ``DOUBLE PRECISION``. Keep
in mind this may effect the precision of large values.
2. The range of possible values is not enforced.

``DOUBLE PRECISION``
--------------------

``DOUBLE PRECISION`` is a 64-bit floating point number.

The ``FLOAT(n)`` and ``FLOAT`` are aliases.

**TODO**

1. The *n* in ``FLOAT(n)`` does not have any affect.

``INTEGER``
-----------

The type ``INT`` is an alias for ``INTEGER``.

**TODO**

1. ``INTEGER`` is currently in memory and on disk as a ``DOUBLE PRECISION``.
2. The range of possible values is not enforced.

``REAL``
--------

A ``REAL`` is a 32bit floating-point number.

**TODO**

1. ``REAL`` is currently in memory and on disk as a ``DOUBLE PRECISION``.

``SMALLINT``
------------

**TODO**

1. ``SMALLINT`` is currently in memory and on disk as a ``DOUBLE PRECISION``.
2. The range of possible values is not enforced.

Text Types
==========

``CHARACTER VARYING(n)``
------------------------

A ``CHARACTER VARYING(n)`` can store up to *n* characters.

The types ``CHAR VARYING(n)`` and ``VARCHAR(n)`` are aliases for
``CHARACTER VARYING(n)``.

**TODO**

1. The *n* limit is not yet enforced.

``CHARACTER(n)``
----------------

A ``CHARACTER(n)`` can store up to *n* characters. ``CHARACTER(n)`` differs from
``CHARACTER VARYING(n)`` in that a ``CHARACTER(n)`` will always be a length of
*n*. For values that have a lesser length, the value will be padded with spaces.

The types ``CHAR(n)`` are an alias. ``CHARACTER`` and ``CHAR`` (without a size)
is an alias for ``CHARACTER(1)``.

**TODO**

1. The *n* limit is not yet enforced.
2. Values are not actually space padded.

Unsupported Data Types
======================

<character large object type>
-----------------------------

1. ``CHARACTER LARGE OBJECT``
2. ``CHAR LARGE OBJECT``
3. ``CLOB``

<national character string type>
--------------------------------

1. ``NATIONAL CHARACTER``
2. ``NATIONAL CHAR``
3. ``NCHAR``
4. ``NATIONAL CHARACTER VARYING``
5. ``NATIONAL CHAR VARYING``
6. ``NCHAR VARYING``

<national character large object type>
--------------------------------------

1. ``NATIONAL CHARACTER LARGE OBJECT``
2. ``NCHAR LARGE OBJECT``
3. ``NCLOB``

<binary string type>
--------------------

1. ``BINARY``
2. ``BINARY VARYING``
3. ``VARBINARY``

<binary large object string type>
---------------------------------

1. ``BINARY LARGE OBJECT``
2. ``BLOB``

<exact numeric type>
--------------------

Some are supported, but the remaining ones that are not supported:

1. ``NUMERIC``
2. ``DECIMAL``
3. ``DEC``

<decimal floating-point type>
-----------------------------

1. ``DECFLOAT``

<datetime type>
---------------

1. ``DATE``
2. ``TIME``
3. ``TIMESTAMP``

<interval type>
---------------

1. ``INTERVAL``

<row type>
----------

1. ``ROW``

<reference type>
----------------

1. ``REF``

<array type>
------------

1. ``ARRAY``

<multiset type>
---------------

1. ``MULTISET``
