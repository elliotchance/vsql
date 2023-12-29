Numbers
=======

.. contents::

There are two categories of numbers in vsql: **approximate** and **exact**. Each
category has its own distinct SQL types, literals, functions and pros/cons.

Numbers are never implicitly cast from one category to another. Operations
containing mixed categories (such as arithmetic) are not allowed because the
result category would be ambiguous. This means that sometimes you will need to
explicitly cast between categories.

Approximate Numbers
-------------------

Approximate (inexact) numbers are by definition approximations and are stored in
a 32 or 64bit native floating-point type. While it's possible that these
representations can give very close approximations for most numbers we use
day-to-day the accuracy cannot be guaranteed in storage or string
representation.

Advantages and Disadvantages
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Advantages** over exact numbers:

1. Generally, they are very space efficient (4 or 8 bytes) regardless of
magnitude.

2. Can represent extremely large and extremely tiny values while maintaining a
certain amount of significant figures.

3. Operations (arithmetic, etc) are extremely fast because floating-point values
are implemented directly in the CPU.

**Disadvantages** over exact numbers:

1. They are not reliable to compare equality to exact values. For example,
``0.1 + 0.2 = 0.3`` is an operation that might return ``FALSE`` on some systems
where the left hand side is computed as ``0.30000000000000004``. **This point
cannot be stressed enough, especially since floating-point values are rendered
with a maximum of 6 places for ``REAL`` or 12 places for ``DOUBLE PRECISION``
after the decimal.** See formatting notes below.

2. They are subject to rounding errors when values cannot be represented closely
enough, or the result of operations between approximate numbers. For the same
reason described in the previous point, but this can occur for individual
numbers that are converted from base 10 (decimal).

3. The string representation may truncate part of the value. For example,
``0.30000000000000004`` may be shown as ``3e-1`` which is very close but not
exactly equal.

Literals and Formatting
^^^^^^^^^^^^^^^^^^^^^^^

Literals for approximate numbers will always be ``DOUBLE PRECISION`` and must be
provided in scientific notation, in the form:

.. code-block:: text

   [ + | - ] digit... { e | E } [ + | - ] digit...

Examples:

.. code-block:: sql

   1e2         -- ~= 100.0
   1.23456e4   -- ~= 12345.6
   7E-5        -- ~= 0.00007

Since scientific notation isn't a very friendly format to use, you can append
``e0`` to any number to have it represented as scientific notation:

.. code-block:: sql

   1e0          -- ~= 1.0
   -1.23456e0   -- ~= -1.23456
   0.000123e0   -- ~= 0.000123

When approximate numbers are displayed (formatted as strings) they are always
represented as scientific notation **with a maximum of 6 places for ``REAL`` or
12 places for ``DOUBLE PRECISION`` after the decimal.** This means that the
displayed value may not be the fully approximated value. This is partially to
combat encoding and rounding errors (such as ``0.30000000000000004``) but also
to reduce the string length as 6 or 12 places after the decimal is more than
enough for general use.

Approximate numbers that are whole numbers will be have the ```.0`` trimmed for
readability and if the number isn't large or small enough to have an exponent,
``e0`` will be appended to ensure the formatted value is guaranteed to always be
scientific notation:

.. code-block:: sql

   VALUES 100.0e0;
   -- COL1: 100e0

Approximate Types
^^^^^^^^^^^^^^^^^

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

Exact Numbers
-------------

Exact numbers retain all precision of a number. SQL types for exact numbers that
do not have predefined ranges need to explicitly specify the scale (the maximum
size) and the precision (the accuracy) that an exact number must conform to.

Advantages and Disadvantages
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Advantages** over approximate numbers:

1. The value is always guaranteed to contain the scale and precision specified.

2. They can be any arbitrary size of precision desired.

3. Values can be bound to a maximum and minimum size (based on the scale).
Literals and operations that would result in an overflow will raise an error,
rather than implicitly truncating.

**Disadvantages** over approximate numbers:

1. Storage costs are higher, based on the scale of the number. Even if that
scale is not entirely used.

2. Operations (arithmetic, etc) are significantly slower than approximate
numbers because the operations are not natively supported by the CPU.

3. Can only represent numbers in the given precision, any extra precision will
be truncated by operations.

Literals and Formatting
^^^^^^^^^^^^^^^^^^^^^^^

The SQL type of an exact number depends on it's form and size:

.. code-block:: text

   [ + | - ] [ . ] digit...
   [ + | - ] digit... [ . [ digit... ] ]

Any number that contains a ``.`` will be treated as a ``NUMERIC``, even in the
case of whole numbers such as ``123.``. Otherwise, the smallest integer type
will be chosen that can contain the value. So ``100`` would be a ``SMALLINT``,
``-1000000`` would be an ``INTEGER``, etc. If the integer does not fit into the
range of ``BIGINT`` then it is treated as a ``NUMERIC`` with zero precision.

The precision of a ``NUMERIC`` is taken directly from the literal, so ``1.0``
and ``1.00`` are equal in value but have different types.

Formatting integers (representing as a string) are always shown as integers (of
any size) and ``NUMERIC`` will always be shown with the precision specified,
even if that requires padding more zeros.

Exact Types
^^^^^^^^^^^

Exact numeric types will contain any value as long as it's within the permitted
range. If a value or an expression that produced a value is beyond the possible
range a ``SQLSTATE 22003 numeric value out of range`` is raised.

.. list-table::
  :header-rows: 1

  * - Type
    - Range (inclusive)
    - Size

  * - ``SMALLINT``
    - -32768 to 32767
    - 2 or 3 bytes [2]_

  * - ``INTEGER`` or ``INT`` [1]_
    - -2147483648 to 2147483647
    - 4 or 5 bytes [2]_

  * - ``BIGINT``
    - -9223372036854775808 to 9223372036854775807
    - 8 or 9 bytes [2]_

  * - ``DECIMAL(scale,prec)``
    - Variable, described below.
    - Variable based on scale

  * - ``NUMERIC(scale,prec)``
    - Variable, described below.
    - Variable based on scale

DECIMAL vs NUMERIC
^^^^^^^^^^^^^^^^^^

``DECIMAL`` and ``NUMERIC`` are both exact numeric types that require a scale
and precision. Both store their respective values as fractions. For example,
``1.23`` could be represented as ``123/100``.

The main difference between these two types comes down to the allowed
denominators. In short, a ``DECIMAL`` may have any denominator, whereas a
``NUMERIC`` must have a denominator of exactly 10^scale. This can also be
expressed as:

.. list-table::
  :header-rows: 1

  * - Type
    - Numerator
    - Denominator

  * - ``DECIMAL(scale, precision)``
    - ± 10^scale (exclusive)
    - ± 10^scale (exclusive)

  * - ``NUMERIC(scale, precision)``
    - ± 10^scale (exclusive)
    - 10^scale

When calculations are performed on a ``NUMERIC``, the result from each operation
will be normalized to always satisfy this constraint.

This means that a ``NUMERIC`` is always exact at the scale and precision
specified and casting to a higher precision will not alter the value. In
contrast, a ``DECIMAL`` promises to have *at least* the precision specified but
the value may change as to be more exact if the precision is increased. This is
best understood with some examples:

.. code-block:: sql

   VALUES CAST(1.23 AS NUMERIC(3,2)) / CAST(5 AS NUMERIC) * CAST(5 AS NUMERIC);
   -- 1.2

Because:

1. ``1.23 AS NUMERIC(3,2)`` -> ``123/100``
2. Normalize denominator -> ``123/100``
3. Divide by ``5`` -> ``123/500``
4. Normalize denominator -> ``24/100``
5. Multiply by ``5`` -> ``120/100``
6. Normalize denominator -> ``24/100``

Whereas,

.. code-block:: sql
  
  VALUES CAST(1.23 AS DECIMAL(3,2)) / 5 * 5;
  -- 1.23

Because:

1. ``1.23 AS DECIMAL(3,2)`` -> ``123/100``
2. Divide by ``5`` -> ``123/500``
3. Multiply by ``5`` -> ``615/500``

This may seem like the only difference is that ``DECIMAL`` does not normalize
the denominator, but actually they both need to normalize a denominator that
would be out of bounds. Consider the example:

.. code-block:: sql

   VALUES CAST(1.23 AS DECIMAL(3,2)) / 11;
   -- 0.11

1. ``1.23 AS DECIMAL(3,2)`` -> ``123/100``
2. Divide by ``11`` -> ``123/1100``
3. Denominator is out of bounds as it cannot be larger than 100. Highest
   precision equivalent would be -> ``11/100``

This the same process and result that a ``NUMERIC`` that the equivalent decimal
operation. Casting to higher precision might result in a different value for
``DECIMAL`` values, for example:

.. code-block:: sql

   VALUES CAST(CAST(5 AS DECIMAL(3,2)) / CAST(7 AS DECIMAL(5,4)) AS DECIMAL(5,4));
   -- 0.7142

Because:

1. ``5 AS DECIMAL(3,2)`` -> ``5/1``
2. Divide by ``7`` -> ``5/7``
3. Cast to ``DECIMAL(5,4)`` -> ``5/7``
4. Formatted result based on 4 precision -> ``0.7142``

.. code-block:: sql

   VALUES CAST(CAST(5 AS NUMERIC(3,2)) / CAST(7 AS NUMERIC) AS NUMERIC(5,4));
   -- 0.7100

Because:

1. ``5 AS NUMERIC(3,2)`` -> ``500/100``
2. Divide by ``7`` -> ``500/700``
3. Normalize denominator -> ``71/100``
4. Cast to ``NUMERIC(5,4)`` -> ``7100/10000``
5. Formatted result based on 4 precision -> ``0.7100``

Operations Between Exact Types
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Arithmetic operations can only be performed when both operates are the same
fundamental types, ``DECIMAL`` or ``NUMERIC``, although they do not need to
share the same scale or precision.

.. list-table::
  :header-rows: 1

  * - Operation
    - Result Type

  * - ``T(s1, s2) + T(s2, p2)``
    - ``T(MAX(s1, s2), MIN(p1, p2))``

  * - ``T(s1, s2) - T(s2, p2)``
    - ``T(MAX(s1, s2), MIN(p1, p2))``

  * - ``T(s1, s2) * T(s2, p2)``
    - ``T(s1 * s2, p1 + p2)``

  * - ``T(s1, s2) / T(s2, p2)``
    - ``T(s1 * s2, p1 + p2)``

Examples:

.. code-block:: sql

   VALUES CAST(10.24 AS DECIMAL(4,2)) + CAST(12.123 AS DECIMAL(8,3));
   -- 22.36 as DECIMAL(32, 3)

   VALUES CAST(10.24 AS DECIMAL(4,2)) * CAST(12.123 AS DECIMAL(8,3));
   -- 124.13952 as DECIMAL(32, 5)

Casting
-------

Implicit Casting
^^^^^^^^^^^^^^^^

Implicit casting is when the value can be safely converted from one type to
another to satisfy an expression. Consider the example:

.. code-block:: sql

   VALUES 123 + 456789;
   -- 456912

This operation seems very straightforward, but the parser will read this as
``SMALLINT + INTEGER`` due to the size of the literals. However, arithmetic
operations must take in an produce the same result. Rather than forcing the user
to explicitly cast one type to another we can always safely convert a
``SMALLINT`` to an ``INTEGER`` (this is called a supertype in SQL terms). The
implicit cast results in an actual expression of ``INTEGER + INTEGER`` that also
produces an ``INTEGER``.

It's important to know that the actual result is not taken into consideration,
so it's still possible to overflow:

.. code-block:: sql

   VALUES 30000 + 30000;
   -- error 22003: numeric value out of range

Because ``SMALLINT + SMALLINT`` results in a ``SMALLINT``. If you think it will
be possible for the value to overflow you should explicitly cast any of the
values to a larger type:

.. code-block:: sql

   VALUES CAST(30000 AS INTEGER) + 30000;
   -- COL1: 60000

Implicit casting only happens in supertypes of the same category:

* Approximate: ``REAL`` -> ``DOUBLE PRECISION``

* Exact: ``SMALLINT`` -> ``INTEGER`` -> ``BIGINT``

Explicit Casting
^^^^^^^^^^^^^^^^

Explicit casting is when you want to convert a value to a specific type. This is
done with the ``CAST`` function. The ``CAST`` function works for a variety of
types outside of numeric types but if a cast happens between numeric types the
value must be valid for the result or an error is returned:

.. code-block:: sql

   VALUES CAST(30000 AS INTEGER);
   -- Safe: 30000

   VALUES CAST(60000 AS SMALLINT);
   -- Error 22003: numeric value out of range

   VALUES CAST(12345 AS VARCHAR(10));
   -- Safe: "12345"

   VALUES CAST(12345 AS VARCHAR(3));
   -- Error 22001: string data right truncation for CHARACTER VARYING(3)

   VALUES CAST(123456789 AS DOUBLE PRECISION);
   -- COL1: 1.23456789e+08

Arithmetic
----------

Arithmetic operations (sometimes called binary operations) require the same type
for both operands and return this same type. For example ``INTEGER + INTEGER``
will result in an ``INTEGER``.

When the type of the operands are different it will implicitly cast to the
supertype of both. See *Implicit Casting*.

For example ``12 * 10.5`` will result in an error because
``SMALLINT * DOUBLE PRECISION`` because there is no supertype that satisfies
both operands (since they belong to different categories). Depending on what
category of result type you're looking for:

.. code-block:: sql

   VALUES 12 * 10.5e0;
   -- error 42883: operator does not exist: SMALLINT * DOUBLE PRECISION

   VALUES CAST(12 AS DOUBLE PRECISION) * 10.5e0;
   -- COL1: 126e0
   
   VALUES 12 * CAST(10.5e0 AS INTEGER);
   -- COL1: 120

Notes
-----

.. [1] ``INT`` is an alias for ``INTEGER``. If you use ``INT`` the type will
   show as ``INTEGER``.

.. [2] A type that allows for ``NULL`` will consume 1 extra byte of storage.

.. [3] ``FLOAT`` is an alias for ``DOUBLE PRECISION``. If you use ``FLOAT`` the
   type will show as ``DOUBLE PRECISION``.
