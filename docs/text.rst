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

The length *n* must be from 1 to 10485760. A ``CHARACTER VARYING`` must have a
length.

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

See :doc:`functions` for the string functions, such as ``UPPER`` and
``SUBSTRING``, and ``||`` to concatenate strings.

Notes
-----

.. [1] When an alias is used, the type will always show as the original type.

.. [2] A character uses 1 to 4 bytes in UTF-8. A type that allows for ``NULL``
   uses 1 extra byte, and a ``NULL`` value only uses that byte.
