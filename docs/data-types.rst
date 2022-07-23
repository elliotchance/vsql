Data Types
==========

.. contents::

Boolean Types
-------------

See :doc:`booleans`.

Numeric Types
-------------

See :doc:`numbers`.

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

See :doc:`dates-times`.

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
