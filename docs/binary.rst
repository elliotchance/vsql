Binary
======

.. contents::

A binary string is a sequence of octets (bytes), such as an image or a hash. It
doesn't have a character set, and it's compared octet by octet.

Binary Types
------------

.. list-table::
  :header-rows: 1

  * - Type
    - Size
    - Description

  * - ``BINARY VARYING(n)``
    - 4 bytes, plus the octets of the value.
    - Can store up to *n* octets.

  * - ``VARBINARY(n)``
    - See ``BINARY VARYING(n)``.
    - Is an alias for ``BINARY VARYING(n)``.

  * - ``BINARY(n)``
    - 4 bytes, plus the octets of the value.
    - Always has *n* octets. A shorter value is padded on the right with
      ``X'00'``.

  * - ``BINARY``
    - See ``BINARY(n)``.
    - Is an alias for ``BINARY(1)``.

The length *n* must be from 1 to 10485760. A ``BINARY VARYING`` must have a
length.

Storing a value that's longer than the column is an error (``22001``), unless
the extra octets at the end are all ``X'00'``, then they're removed.

Literals
--------

A binary string is written as an ``X`` (or ``x``) and two hexadecimal digits
for each octet, in quotes. The digits can be in either case. A binary string is
shown as its hexadecimal digits in upper case:

.. code-block:: sql

  VALUES X'0aFF';
  -- COL1: 0AFF

  VALUES X'';
  -- COL1:

The type of a literal is ``BINARY VARYING`` with the length of the value.

Spaces between the digits (T024) and a literal of more than one part (T023) are
not supported yet.

Operations
----------

A binary string can only be compared with another binary string, and can't be
cast to or from any other type. ``CAST`` between binary strings pads a
``BINARY(n)`` with ``X'00'``, and truncates a value that's too long with a
warning (``01004``).

Two binary strings are equal only if they have the same octets. Otherwise, the
first octet that's different decides which one is less. If one is the start of
the other, the shorter one is less, even if the rest of the longer one is all
``X'00'``:

.. code-block:: sql

  VALUES X'AB' < X'AC', X'AB' < X'AB00';
  -- COL1: TRUE
  -- COL1: TRUE

``||`` puts two binary strings together. The result is a ``BINARY`` only if
both are:

.. code-block:: sql

  VALUES X'01' || X'FF00';
  -- COL1: 01FF00

``OCTET_LENGTH`` is the number of octets, and ``POSITION`` is the position of
the first octet of the first match (or 0 if there isn't one):

.. code-block:: sql

  VALUES OCTET_LENGTH(X'0001FF'), POSITION(X'FF' IN X'00FF00FF');
  -- COL1: 3
  -- COL1: 2

Binary strings can be used in a ``PRIMARY KEY``, ``UNIQUE``, index, ``GROUP
BY``, ``ORDER BY``, ``MIN`` and ``MAX``. The other string functions, such as
``SUBSTRING`` and ``TRIM``, don't work with binary strings yet (T022).
