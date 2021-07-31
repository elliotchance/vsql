.. contents::

For the tables below:

- ``number`` is any of the numer types: ``FLOAT``, ``DOUBLE PRECISION``, etc.
- ``text`` is any of the character types: ``CHARACTER VARYING``, ``CHARACTER``, etc.
- ``any`` is any data type.

Binary Operations
=================

.. list-table::
    :header-rows: 1

  * - Operator
    - Precedence
    - Name

  * - ``number * number``
    - 2
    - Multiplication

  * - ``number / number``
    - 2
    - Division

  * - ``number + number``
    - 3
    - Addition

  * - ``number - number``
    - 3
    - Subtraction

  * - ``text || text``
    - 3
    - Concatenation

  * - ``any = any``
    - 4
    - Equal

  * - ``any <> any``
    - 4
    - Not equal

  * - ``number > number``
    - 4
    - Greater than

  * - ``text > text``
    - 4
    - Greater than

  * - ``number < number``
    - 4
  -   Less than

  * - ``text <= text``
    - 4
    - Less than

  * - ``number >= number``
    - 4
    - Greater than or equal

  * - ``text >= text``
    - 4
    - Greater than or equal

  * - ``number <= number``
    - 4
    - Less than or equal

  * - ``text <= text``
    - 4
    - Less than or equal

  * - ``boolean AND boolean`
    - 6
    - Logical and

  * - ``boolean OR boolean``
    - 7
    - Logical or

The _Precedence_ dictates the order of operations. For example ``2 + 3 * 5`` is
evaluated as ``2 + (3 * 5)`` because ``*`` has a lower precedence so it happens
first. You can control the order of operations with parenthesis, like
``(2 + 3) * 5``.

Dividing by zero will result in ``SQLSTATE 22012`` error.

Unary Operations
================

.. list-table::
    :header-rows: 1

  * - Operator
    - Name
  
  * - ``+number``
    - Noop
  
  * - ``-number``
    - Unary negate
  
  * - ``NOT boolean``
    - Logical negate
  
  * - ``any IS NULL``
    - NULL check
  
  * - ``any IS NOT NULL``
    - Not NULL check
