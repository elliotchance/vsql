Text
====

.. contents::

Text Types
----------

.. list-table::
  :header-rows: 1

  * - Type
    - Size
    - Description

  * - ``CHARACTER VARYING(n)``
    - 4 bytes, plus the bytes of the value. [2]_
    - Can store up to *n* characters.

  * - ``CHAR VARYING(n)``
    - See ``CHARACTER VARYING(n)``.
    - Is an alias for ``CHARACTER VARYING(n)``. [1]_

  * - ``VARCHAR(n)``
    - See ``CHARACTER VARYING(n)``.
    - Is an alias for ``CHARACTER VARYING(n)``. [1]_

  * - ``CHARACTER(n)``
    - 4 bytes, plus the bytes of the value. [2]_
    - A ``CHARACTER(n)`` can store up to *n* characters. ``CHARACTER(n)`` differs from ``CHARACTER VARYING(n)`` in that a ``CHARACTER(n)`` will always be a length of *n*. For values that have a lesser length, the value will be padded with spaces.

  * - ``CHAR(n)``
    - See ``CHARACTER(n)``.
    - Is an alias for ``CHARACTER(n)``. [1]_

  * - ``CHARACTER``
    - See ``CHARACTER(n)``.
    - Is an alias for ``CHARACTER(1)``.

  * - ``CHARACTER LARGE OBJECT(n)``
    - 4 bytes, plus the bytes of the value. [2]_
    - Can store up to *n* characters, like ``CHARACTER VARYING(n)``. Without a
      length, it can store a value of any length that fits in a row.

  * - ``CHAR LARGE OBJECT(n)``, ``CLOB(n)``
    - See ``CHARACTER LARGE OBJECT(n)``.
    - Is an alias for ``CHARACTER LARGE OBJECT(n)``. [1]_

The length *n* must be from 1 to 10485760 (or 2147483647 for a ``CHARACTER
LARGE OBJECT``). It's the number of characters, but for a ``CHARACTER`` or
``CHARACTER VARYING`` it can also be the number of octets (bytes of UTF-8),
such as ``VARCHAR(10 OCTETS)``. ``VARCHAR(10 CHARACTERS)`` is the same as
``VARCHAR(10)``. A string that has more octets than that is the same as one
that's too long. A ``CHARACTER(n OCTETS)`` is padded with spaces to *n* octets,
and a cast to it never cuts a character in half. A ``CHARACTER VARYING`` (or
``CHAR VARYING`` or ``VARCHAR``) without a length is a
``CHARACTER VARYING(10485760)``, the maximum length. The length of a
``CHARACTER LARGE OBJECT`` can have a multiplier: ``K`` (1024), ``M``
(1048576) or ``G`` (1073741824), such as ``CLOB(2M)``. ``T`` and ``P`` are also
multipliers, but they're always longer than the maximum.

A string of any type that's longer than a quarter of a page (1024 bytes, with
the default page size) is stored outside of its row, so that reading the row
doesn't read it. A long ``CHARACTER LARGE OBJECT`` is only read when it's used,
such as when the result is read, and an application can read part of it at a
time instead (see ``Row.get_lob`` in :doc:`v-client-library-docs`). Other
string types are read with the row.

A ``CHARACTER LARGE OBJECT`` can't be in a ``PRIMARY KEY``, a ``UNIQUE`` or
``FOREIGN KEY`` constraint, or an index. It can be used with ``||`` and the
string functions (such as ``SUBSTRING``, ``TRIM``, ``UPPER``, ``LOWER``,
``POSITION``, ``CHAR_LENGTH`` and ``OCTET_LENGTH``), and the result of
``||``, ``SUBSTRING`` and ``TRIM`` is also a ``CHARACTER LARGE OBJECT``.
``CHAR_LENGTH`` and ``OCTET_LENGTH`` of a long value don't read it, and
``SUBSTRING`` only reads the part that's in the result when every character
is one byte (or with ``USING OCTETS``).

A ``CHARACTER LARGE OBJECT`` can only be compared for equality (such as with
``=``, ``<>``, ``IN`` or ``LIKE``), not with ``<``, ``BETWEEN``, ``GREATEST``
or ``LEAST``.

The only character set is UTF-8, which is also the national character set. So
each national character string type is the same as the character string type:
``NATIONAL CHARACTER(n)``, ``NATIONAL CHAR(n)`` and ``NCHAR(n)`` are
``CHARACTER(n)``, ``NATIONAL CHARACTER VARYING(n)``, ``NATIONAL CHAR
VARYING(n)`` and ``NCHAR VARYING(n)`` are ``CHARACTER VARYING(n)``, and
``NATIONAL CHARACTER LARGE OBJECT(n)``, ``NCHAR LARGE OBJECT(n)`` and
``NCLOB(n)`` are ``CHARACTER LARGE OBJECT(n)``. A national character string
literal (such as ``N'hello'``) is the same as a character string literal.

Literals
--------

A string is written in single quotes, such as ``'hello'``. A single quote in
the string is written twice: ``'it''s'``. Strings that are only separated by
spaces that include a new line are one string:

.. code-block:: sql

  VALUES 'Hello, '
    'World';
  -- COL1: Hello, World

A Unicode string starts with ``U&`` and can contain escapes for any character:
a backslash followed by 4 hex digits, or a backslash, a plus and 6 hex digits.
Two backslashes are one backslash. Another escape character can be chosen with
``UESCAPE``:

.. code-block:: sql

  VALUES U&'caf\00e9 \+01F600';
  -- COL1: café 😀

  VALUES U&'caf!00e9 \' UESCAPE '!';
  -- COL1: café \

Casting
-------

.. list-table::

  * - ↓ From / To →
    - ``CHARACTER VARYING(n)``
    - ``CHARACTER(n)``

  * - ``CHARACTER VARYING(n)``
    - ✅
    - ✅

  * - ``CHARACTER(n)``
    - ✅
    - ✅

Text is stored as UTF-8, and lengths (such as the *n* in ``VARCHAR(n)``) are
counted in characters, not bytes. A string that's too long for a column is an
error ``22001``, but a ``CAST`` to a shorter type only truncates it (with a
``01004`` warning).

Comparisons are case-sensitive and compare the Unicode code points of the
characters.

A string literal is normalized to Unicode Normalization Form C (NFC), so
``U&'\0065\0301'`` and ``U&'\00E9'`` are the same string with one character.
Other strings, such as the value of a parameter, are kept as they are.

See :doc:`functions-string` for the string functions, such as ``UPPER`` and
``SUBSTRING``, and ``||`` to concatenate strings.

Notes
-----

.. [1] When an alias is used, the type will always show as the original type.

.. [2] A character uses 1 to 4 bytes in UTF-8. A type that allows for ``NULL``
   uses 1 extra byte, and a ``NULL`` value only uses that byte.
