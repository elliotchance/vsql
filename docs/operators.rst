Operators
=========

.. contents::

For the tables below:

- ``number`` is any of the number types: ``INTEGER``, ``DOUBLE PRECISION``, etc.
- ``text`` is any of the character types: ``CHARACTER VARYING``, ``CHARACTER``, etc.
- ``any`` is any data type.

If any operand is ``NULL`` the result is also ``NULL`` (or ``UNKNOWN`` for
comparisons, ``LIKE`` and ``SIMILAR TO``). The exceptions are ``IS NULL``,
``IS NOT NULL`` and the logical operators (``AND``, ``OR``, etc).

``!=`` is the same as ``<>`` everywhere that a comparison operator is allowed.
It's a vsql extension and not standard SQL, so it's flagged with ``V009-01`` (see
:doc:`sql-flagging`). A ``CHECK`` constraint or generated column that's written
with ``!=`` is stored, shown in ``INFORMATION_SCHEMA`` and dumped with ``<>``.

Binary Operations
-----------------

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

   * - ``any != any``
     - 4
     - Not equal (a vsql extension, the same as ``<>``)

   * - ``number > number``
     - 4
     - Greater than

   * - ``text > text``
     - 4
     - Greater than

   * - ``number < number``
     - 4
     - Less than

   * - ``text < text``
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

   * - ``boolean AND boolean``
     - 6
     - Logical and

   * - ``boolean OR boolean``
     - 7
     - Logical or

Dates and times can also be compared with each other (see :doc:`dates-times`),
and so can ``BOOLEAN`` values.

The *Precedence* dictates the order of operations. For example ``2 + 3 * 5`` is
evaluated as ``2 + (3 * 5)`` because ``*`` has a lower precedence so it happens
first. You can control the order of operations with parenthesis, like
``(2 + 3) * 5``.

Dividing by zero will result in ``SQLSTATE 22012`` error.

Unary Operations
----------------

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
