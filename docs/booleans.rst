Booleans
========

.. contents::

BOOLEAN type
------------

The ``BOOLEAN`` type allows for a ``TRUE`` or ``FALSE`` value. If the value
allows for ``NULL`` it will also allow for ``NULL`` or ``UNKNOWN`` (these are
aliases that mean the same thing).

A ``BOOLEAN`` is stored as a single byte, even if it permits ``UNKNOWN``.

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
