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

.. list-table::
   :header-rows: 1

   * - Operator
     - Description

   * - ``%``
     - Matches any sequence of zero or more characters.
   * - ``_``
     - Matches any single character.

*Examples*

.. code-block:: sql

  'a' LIKE 'a'          -- TRUE
  'a' LIKE 'A'          -- FALSE
  'ab' LIKE 'a_'        -- TRUE
  'abc' LIKE 'a_'       -- FALSE
  'acdeb' LIKE 'a%b'    -- TRUE
  'abc' NOT LIKE 'a%'   -- FALSE

NEXT VALUE FOR
--------------

.. code-block:: text

  NEXT VALUE FOR X

Returns the next value for a SEQUENCE called ``X``.

*Examples*

.. code-block:: sql

  NEXT VALUE FOR my_sequence   -- 1
  NEXT VALUE FOR my_sequence   -- 2

SIMILAR TO
----------

.. code-block:: text

  X [ NOT ] SIMILAR TO Y

Tests if ``X`` matches the similar-expression of ``Y``. The pattern for ``Y`` is
a superset of the pattern for ``LIKE`` expressions that makes patterns closer to
regular expressions.

Matching is always against the entire string (not a partial match) and is
case-sensitive. You can use the following characters in ``Y``:

.. list-table::
   :header-rows: 1

   * - Operator
     - Description

   * - ``%``
     - Matches any sequence of zero or more characters.
   * - ``_``
     - Matches any single character.
   * - ``|``
     - Denotes alternation (either of two alternatives).
   * - ``*``
     - Repeat the previous item zero or more times.
   * - ``+``
     - Repeat the previous item one or more times.
   * - ``?``
     - Repeat the previous item zero or one time.
   * - ``{m}``
     - Repeat the previous item exactly m times.
   * - ``{m,}``
     - Repeat the previous item m or more times.
   * - ``{m,n}``
     - Repeat the previous item at least m and not more than n times.
   * - ``()``
     - Parentheses group items into a single logical item.
   * - ``[...]``
     - A bracket expression specifies a character class, just as in POSIX
       regular expressions.

*Examples*

.. code-block:: sql

  'abc' SIMILAR TO 'abc'                                           -- TRUE
  'abc' SIMILAR TO '_b_'                                           -- TRUE
  'abc' SIMILAR TO '_A_'                                           -- FALSE
  'abc' SIMILAR TO '%(b|d)%'                                       -- TRUE
  'abc' SIMILAR TO '(b|c)%'                                        -- FALSE
  'AbcAbcdefgefg12efgefg12' SIMILAR TO '((Ab)?c)+d((efg)+(12))+'   -- TRUE
  'aaaaaab11111xy' SIMILAR TO 'a{6}_[0-9]{5}(x|y){2}'              -- TRUE
  '$0.87' SIMILAR TO '$[0-9]+(.[0-9][0-9])?'                       -- TRUE
