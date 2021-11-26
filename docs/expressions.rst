Expressions
===========

.. contents::

BETWEEN
-------

.. code-block:: text

  X [ NOT ] BETWEEN [ ASYMMETRIC | SYMMETRIC ] Y AND Z

A ``BETWEEN`` expression returns ``TRUE`` if ``X`` is inclusively between
``Y`` and ``Z``. Or, put another way ``X >= Y AND Z <= Z``.

If ``SYMMETRIC`` is provided, the orders of ``Y`` and ``Z`` are irrelevant. Such
that they will be swapped if ``Y > Z``.

If neither ``ASYMMETRIC`` or ``SYMMETRIC`` is provided then ``ASYMMETRIC`` is
assumed.

*Examples*

.. code-block:: sql

  30 BETWEEN 25 AND 45             -- TRUE
  30 BETWEEN 45 AND 32             -- FALSE
  30 NOT BETWEEN 25 AND 45         -- FALSE
  30 BETWEEN SYMMETRIC 45 AND 32   -- TRUE

IS NULL
-------

.. code-block:: text

  X IS [ NOT ] NULL

Tests if ``X`` is (or is not) ``NULL``.

LIKE
----

.. code-block:: text

  X [ NOT ] LIKE Y

Tests if ``X`` matches the like-expression of ``Y``. Apart from simple regexp
matching, this is very useful for testing the prefix or suffix of a string.

Matching is always against the entire string (not a partial match) and is
case-sensitive. You can use the following characters in ``Y``:

- ``_`` matches any single character.
- ``%`` matches zero, one or more characters.

*Examples*

.. code-block:: sql

  'a' LIKE 'a'          -- TRUE
  'a' LIKE 'A'          -- FALSE
  'ab' LIKE 'a_'        -- TRUE
  'abc' LIKE 'a_'       -- FALSE
  'acdeb' LIKE 'a%b'    -- TRUE
  'abc' NOT LIKE 'a%'   -- FALSE
