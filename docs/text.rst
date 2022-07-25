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
    - No less than 1 byte, but no more than *n* + 4.
    - Can store up to *n* characters.

  * - ``CHAR VARYING(n)``
    - See ``CHARACTER VARYING(n)``.
    - Is an alias for ``CHARACTER VARYING(n)``. [1]_

  * - ``VARCHAR(n)``
    - See ``CHARACTER VARYING(n)``.
    - Is an alias for ``CHARACTER VARYING(n)``. [1]_

  * - ``CHARACTER(n)``
    - (*n* + 4) or 1 (for ``NULL``).
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

Notes
-----

.. [1] When an alias is used, the type will always show as the original type.
