Binary
======

.. contents::

Binary Types
------------

A binary string is a sequence of octets (bytes), rather than characters.

.. list-table::
  :header-rows: 1

  * - Type
    - Size
    - Description

  * - ``BINARY VARYING(n)``
    - 4 bytes, plus the octets of the value. [1]_
    - Can store up to *n* octets.

  * - ``VARBINARY(n)``
    - See ``BINARY VARYING(n)``.
    - Is an alias for ``BINARY VARYING(n)``. [2]_

  * - ``BINARY(n)``
    - 4 bytes, plus the octets of the value. [1]_
    - Always has *n* octets. A shorter value is padded with ``X'00'``.

  * - ``BINARY``
    - See ``BINARY(n)``.
    - Is an alias for ``BINARY(1)``.

  * - ``BINARY LARGE OBJECT(n)``
    - 4 bytes, plus the octets of the value. [1]_
    - Can store up to *n* octets, like ``BINARY VARYING(n)``. Without a length,
      it can store a value of any length that fits in a row.

  * - ``BLOB(n)``
    - See ``BINARY LARGE OBJECT(n)``.
    - Is an alias for ``BINARY LARGE OBJECT(n)``. [2]_

The length *n* must be from 1 to 10485760 (or 2147483647 for a ``BINARY LARGE
OBJECT``). A ``BINARY VARYING`` must have a length.

A value that's too long for a column is an error ``22001``, unless the extra
octets at the end are all ``X'00'``, which are removed. A binary string can only
be stored in a binary string type, and a character string can't be stored in
one.

Like a character string, a binary string that's longer than a quarter of a page
is stored outside of its row (see :doc:`text`). A ``BINARY LARGE OBJECT`` is
only read when it's used, and ``SUBSTRING`` and ``OCTET_LENGTH`` only read the
part of it that they need.

A ``BINARY LARGE OBJECT`` can't be in a ``PRIMARY KEY``, a ``UNIQUE`` or
``FOREIGN KEY`` constraint or an index, and it can only be compared for
equality (such as with ``=``, ``<>`` or ``IN``), not with ``<``, ``BETWEEN``,
``GREATEST`` or ``LEAST``.

Literals
--------

A binary string literal is ``X`` followed by two hexadecimal digits for each
octet in single quotes, such as ``X'CAFE'``. It's a ``BINARY`` with the number
of octets in it, and it's shown the same way (in upper case).

.. code-block:: sql

  VALUES X'0a1B';
  -- COL1: 0A1B

There's no ``CAST`` between a binary string and a character string.
``BINARY_TO_HEX`` converts a binary string to its hexadecimal digits, and
``HEX_TO_BINARY`` converts them back. ``UUID_TO_BINARY`` and ``BINARY_TO_UUID`` store a
UUID as a ``BINARY(16)`` (see :doc:`functions`).

.. code-block:: sql

  VALUES BINARY_TO_HEX(X'CAFE');
  -- COL1: CAFE

  VALUES HEX_TO_BINARY('cafe');
  -- COL1: CAFE

Operations
----------

Binary strings are compared octet by octet. When one is the start of the other,
the shorter one is less, even if the rest of the longer one is all ``X'00'``.
So ``X'01' < X'0100'``, and a ``BINARY(3)`` with ``X'010000'`` isn't equal to
``X'01'``.

``||`` concatenates two binary strings. The result is a ``BINARY`` if both are,
otherwise a ``BINARY VARYING`` (or a ``BINARY LARGE OBJECT`` if either one is)
with the combined length. A ``BINARY VARYING`` result that's longer than
10485760 octets is an error ``22001``, unless the extra octets are all
``X'00'``.

``SUBSTRING``, ``TRIM``, ``OVERLAY``, ``POSITION`` and ``OCTET_LENGTH`` work
on binary strings, and count octets (see :doc:`functions`). Without a trim
octet, ``TRIM`` removes ``X'00'``.

``LIKE`` matches binary strings octet by octet, where ``X'25'`` (``%``) is any
number of octets and ``X'5F'`` (``_``) is any one octet. The ``ESCAPE`` must be
one octet, otherwise it's an error ``2200D``.

.. code-block:: sql

  VALUES X'0102' || X'03';
  -- COL1: 010203

  VALUES SUBSTRING(X'0102030405' FROM 2 FOR 3);
  -- COL1: 020304

  VALUES TRIM(X'0000010200');
  -- COL1: 0102

  VALUES POSITION(X'0304' IN X'0102030403');
  -- COL1: 3

  VALUES OCTET_LENGTH(X'010203');
  -- COL1: 3

  VALUES OVERLAY(X'0102030405' PLACING X'AABB' FROM 2);
  -- COL1: 01AABB0405

  VALUES X'010203' LIKE X'0125';
  -- COL1: TRUE

Notes
-----

.. [1] A type that allows for ``NULL`` uses 1 extra byte, and a ``NULL`` value
   only uses that byte.

.. [2] When an alias is used, the type will always show as the original type.
