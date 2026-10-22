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
