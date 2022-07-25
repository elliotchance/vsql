Numbers
=======

.. contents::

Exact Numeric Types
-------------------

Exact numeric types will losslessly contain any value as long as it's within the
permitted range. If a value or an expression that produced a value is beyond the
possible range a ``SQLSTATE 22003 numeric value out of range`` is raised.

.. list-table::
  :header-rows: 1

  * - Type
    - Range (inclusive)
    - Size

  * - ``SMALLINT``
    - -32,768 to 32,767
    - 2 or 3 bytes [2]_

  * - ``INTEGER`` or ``INT`` [1]_
    - -2,147,483,648 to 2,147,483,647
    - 4 or 5 bytes [2]_

  * - ``BIGINT``
    - -9,223,372,036,854,775,808 to 9,223,372,036,854,775,807
    - 8 or 9 bytes [2]_

Approximate Numeric Types
-------------------------

Approximate types store floating-point values with a precision that is relative
to scale of the number. These types should not be used when an exact value (such
as currency) needs to be retained.

.. list-table::
  :header-rows: 1

  * - Type
    - Range
    - Size

  * - ``REAL``
    - -3.4e+38 to 3.4e+38
    - 4 or 5 bytes [2]_

  * - ``DOUBLE PRECISION`` or ``FLOAT`` [3]_
    - -1.7e+308 to +1.7e+308
    - 8 or 9 bytes [2]_

Casting
-------

.. list-table::

  * - ↓ From / To →
    - ``SMALLINT``
    - ``INTEGER``
    - ``BIGINT``
    - ``REAL``
    - ``DOUBLE PRECISION``

  * - ``SMALLINT``
    - ✅
    - ✅
    - ✅
    - ✅
    - ✅

  * - ``INTEGER``
    - ✅
    - ✅
    - ✅
    - ✅
    - ✅

  * - ``BIGINT``
    - ✅
    - ✅
    - ✅
    - ✅
    - ✅

  * - ``REAL``
    - ✅
    - ✅
    - ✅
    - ✅
    - ✅

  * - ``DOUBLE PRECISION``
    - ✅
    - ✅
    - ✅
    - ✅
    - ✅

Notes
-----

.. [1] ``INT`` is an alias for ``INTEGER``. If you use ``INT`` the type will
   show as ``INTEGER``.

.. [2] A type that allows for ``NULL`` will consume 1 extra byte of storage.

.. [3] ``FLOAT`` is an alias for ``DOUBLE PRECISION``. If you use ``FLOAT`` the
   type will show as ``DOUBLE PRECISION``.
