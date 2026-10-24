Booleans
========

.. contents::

BOOLEAN type
------------

The ``BOOLEAN`` type allows for a ``TRUE`` or ``FALSE`` value. If the value
allows for ``NULL`` it will also allow for ``NULL`` or ``UNKNOWN`` (these are
aliases that mean the same thing).

A ``BOOLEAN`` is stored as a single byte, even if it permits ``UNKNOWN``.

Casting
-------

A character string can be cast to a ``BOOLEAN`` if it's ``TRUE``, ``FALSE`` or
``UNKNOWN`` (in any case), once leading and trailing spaces are removed.
Anything else is an error (``22018``). A ``BOOLEAN`` cast to a character string
is ``'TRUE'`` or ``'FALSE'``, which must fit without being truncated:

.. code-block:: sql

  VALUES CAST(' true ' AS BOOLEAN);
  -- COL1: TRUE

  VALUES CAST('yes' AS BOOLEAN);
  -- error 22018: invalid character value for cast

  VALUES CAST(FALSE AS VARCHAR(10));
  -- COL1: FALSE

  VALUES CAST(FALSE AS VARCHAR(4));
  -- error 22018: invalid character value for cast

Logical Operations
------------------

.. list-table::
  :header-rows: 1

  * - AND
    - TRUE
    - FALSE
    - UNKNOWN

  * - **TRUE**
    - TRUE
    - FALSE
    - UNKNOWN

  * - **FALSE**
    - FALSE
    - FALSE
    - FALSE

  * - **UNKNOWN**
    - UNKNOWN
    - FALSE
    - UNKNOWN

.. list-table::
  :header-rows: 1

  * - OR
    - TRUE
    - FALSE
    - UNKNOWN

  * - **TRUE**
    - TRUE
    - TRUE
    - TRUE

  * - **FALSE**
    - TRUE
    - FALSE
    - UNKNOWN

  * - **UNKNOWN**
    - TRUE
    - UNKNOWN
    - UNKNOWN

.. list-table::
  :header-rows: 1

  * - IS
    - TRUE
    - FALSE
    - UNKNOWN

  * - **TRUE**
    - TRUE
    - FALSE
    - FALSE

  * - **FALSE**
    - FALSE
    - TRUE
    - FALSE

  * - **UNKNOWN**
    - FALSE
    - FALSE
    - TRUE
