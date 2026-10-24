Expressions
===========

.. contents::

BETWEEN
-------

.. code-block:: text

  X [ NOT ] BETWEEN [ ASYMMETRIC | SYMMETRIC ] Y AND Z

A ``BETWEEN`` expression returns ``TRUE`` if ``X`` is inclusively between
``Y`` and ``Z``. Or, put another way ``X >= Y AND X <= Z``.

If ``SYMMETRIC`` is provided, the orders of ``Y`` and ``Z`` are irrelevant. Such
that they will be swapped if ``Y > Z``.

If neither ``ASYMMETRIC`` nor ``SYMMETRIC`` is provided then ``ASYMMETRIC`` is
assumed.

*Examples*

.. code-block:: sql

  30 BETWEEN 25 AND 45             -- TRUE
  30 BETWEEN 45 AND 32             -- FALSE
  30 NOT BETWEEN 25 AND 45         -- FALSE
  30 BETWEEN SYMMETRIC 45 AND 25   -- TRUE

IN
--

.. code-block:: text

  X [ NOT ] IN ( Y1 [ , Y2 ... ] )

An ``IN`` expression returns ``TRUE`` if ``X`` is equal to any of the values in
the list. Or, put another way ``X = Y1 OR X = Y2 ...``. ``X NOT IN (...)`` is the
same as ``NOT (X IN (...))``.

This means that if ``X`` is ``NULL``, or none of the values are equal but at
least one of them is ``NULL``, the result is ``UNKNOWN``.

*Examples*

.. code-block:: sql

  30 IN (25, 30, 45)               -- TRUE
  30 IN (45)                       -- FALSE
  30 NOT IN (25, 30, 45)           -- FALSE
  30 IN (45, CAST(NULL AS INT))    -- UNKNOWN

CASE
----

.. code-block:: text

  CASE X WHEN Y1 THEN R1 [ WHEN Y2 THEN R2 ... ] [ ELSE R ] END

  CASE WHEN C1 THEN R1 [ WHEN C2 THEN R2 ... ] [ ELSE R ] END

The first form (a simple ``CASE``) returns the result for the first ``WHEN``
value that is equal to ``X``. ``X`` is only evaluated once. ``NULL`` is never
equal to anything, so ``CASE NULL WHEN NULL ...`` does not match.

The second form (a searched ``CASE``) returns the result for the first ``WHEN``
condition that is ``TRUE``. Conditions that are ``FALSE`` or ``UNKNOWN`` are
skipped.

If nothing matches, the ``ELSE`` result is returned, or ``NULL`` if there is no
``ELSE``. A result can be ``NULL``, but at least one of them must be something
else. The results must have compatible types, and the ``CASE`` has a type that
can hold any of them, like ``COALESCE``.

``NEXT VALUE FOR`` can't be used in a ``CASE`` (or ``NULLIF`` or ``COALESCE``),
since whether it's evaluated depends on the other values.

*Examples*

.. code-block:: sql

  CASE 2 WHEN 1 THEN 10 WHEN 2 THEN 20 ELSE 0 END               -- 20
  CASE 3 WHEN 1 THEN 'one' END                                 -- NULL
  CASE WHEN 5 > 10 THEN 'big' ELSE 'small' END                 -- 'small'

IS NULL
-------

.. code-block:: text

  X IS [ NOT ] NULL

Tests if ``X`` is (or is not) ``NULL``.

LIKE
----

.. code-block:: text

  X [ NOT ] LIKE Y [ ESCAPE Z ]

Tests if ``X`` matches the pattern ``Y``. This is very useful for testing the
prefix or suffix of a string.

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

``ESCAPE`` sets an escape character ``Z``, which must be exactly one character
(otherwise a 22019 invalid escape character error). In ``Y``, the escape
character followed by ``%``, ``_`` or the escape character itself matches that
character literally. Any other use of the escape character in ``Y`` is a 22025
invalid escape sequence error.

*Examples*

.. code-block:: sql

  'a' LIKE 'a'                  -- TRUE
  'a' LIKE 'A'                  -- FALSE
  'ab' LIKE 'a_'                -- TRUE
  'abc' LIKE 'a_'               -- FALSE
  'acdeb' LIKE 'a%b'            -- TRUE
  'abc' NOT LIKE 'a%'           -- FALSE
  '100%' LIKE '%!%' ESCAPE '!'  -- TRUE
  '100' LIKE '%!%' ESCAPE '!'   -- FALSE

NEXT VALUE FOR
--------------

.. code-block:: text

  NEXT VALUE FOR X

Returns the next value for a SEQUENCE called ``X``.

All ``NEXT VALUE FOR`` expressions for the same sequence return the same value
within a row. Each new row will get the next value.

*Examples*

.. code-block:: sql

  CREATE SEQUENCE my_sequence;
  VALUES NEXT VALUE FOR my_sequence, NEXT VALUE FOR my_sequence;
  VALUES ROW(NEXT VALUE FOR my_sequence, NEXT VALUE FOR my_sequence);
  -- msg: CREATE SEQUENCE 1
  -- COL1: 1
  -- COL1: 2
  -- COL1: 3 COL2: 3

SIMILAR TO
----------

.. code-block:: text

  X [ NOT ] SIMILAR TO Y [ ESCAPE Z ]

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
     - Matches any one of the characters inside the brackets, such as
       ``[abc]``. A range of characters can be written as ``[a-z]``.
   * - ``[^...]``
     - Matches any one character that is not inside the brackets.
   * - ``[...^...]``
     - Matches any one character from before the ``^`` that is not after it,
       such as ``[a-z^x]``.
   * - ``[:ALPHA:]``
     - Inside brackets, matches a character from a class: ``ALPHA``, ``UPPER``,
       ``LOWER`` (Latin letters), ``DIGIT``, ``ALNUM``, ``SPACE`` (only the space
       character) or ``WHITESPACE``. For example, ``[[:DIGIT:]]``.

The characters ``[ ] ( ) | ^ - + * _ % ? {`` always have a special meaning. A
pattern that uses them in any other way, or that is not complete (such as
``'(a'``), is an invalid regular expression (SQLSTATE 2201B). The repeat counts
for ``{m}`` must be at least 1.

``ESCAPE`` sets an escape character ``Z``, which must be exactly one character
(otherwise a 22019 invalid escape character error). In ``Y``, the escape
character followed by one of the special characters above, or by the escape
character itself, matches that character literally (also inside brackets). Any
other use of the escape character is an invalid regular expression (2201B),
unless the escape character is itself a special character, in which case it's a
2200C invalid use of escape character error. With ``ESCAPE ':'``, a pattern
that has a class such as ``[:ALPHA:]`` is a 2200B escape character conflict.

*Examples*

.. code-block:: sql

  'abc' SIMILAR TO 'abc'                                           -- TRUE
  'abc' SIMILAR TO '_b_'                                           -- TRUE
  'abc' SIMILAR TO '_A_'                                           -- FALSE
  'abc' SIMILAR TO '%(b|d)%'                                       -- TRUE
  'abc' SIMILAR TO '(b|c)%'                                        -- FALSE
  'AbcAbcdefgefg12efgefg12' SIMILAR TO '((Ab)?c)+d((efg)+(12))+'   -- TRUE
  'aaaaaab11111xy' SIMILAR TO 'a{6}_[0-9]{5}(x|y){2}'              -- TRUE
  '1+2' SIMILAR TO '[0-9]!+[0-9]' ESCAPE '!'                       -- TRUE
  '$0.87' SIMILAR TO '$[0-9]+(.[0-9][0-9])?'                       -- TRUE
  'abab' SIMILAR TO '%a%b'                                         -- TRUE
  'A1' SIMILAR TO '[[:UPPER:]][^a-z]'                              -- TRUE
