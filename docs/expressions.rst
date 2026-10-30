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
  X [ NOT ] IN ( <query> )

An ``IN`` expression returns ``TRUE`` if ``X`` is equal to any of the values in
the list, or any of the rows of the subquery (which must have one column). Or,
put another way ``X = Y1 OR X = Y2 ...``, which is the same as
``X = ANY (...)``. ``X NOT IN (...)`` is the same as ``NOT (X IN (...))``.

This means that if ``X`` is ``NULL``, or none of the values are equal but at
least one of them is ``NULL``, the result is ``UNKNOWN``. So ``NOT IN`` is never
``TRUE`` when a subquery returns a ``NULL``. A subquery without any rows is
``FALSE`` for ``IN`` (and ``TRUE`` for ``NOT IN``), even when ``X`` is ``NULL``.

*Examples*

.. code-block:: sql

  30 IN (25, 30, 45)               -- TRUE
  30 IN (45)                       -- FALSE
  30 NOT IN (25, 30, 45)           -- FALSE
  30 IN (45, CAST(NULL AS INT))    -- UNKNOWN
  30 IN (SELECT price FROM products)
  30 IN (VALUES 25, 30)            -- TRUE

ALL, SOME and ANY
-----------------

.. code-block:: text

  X <op> ALL ( <query> )
  X <op> { SOME | ANY } ( <query> )

Compares ``X`` with each row of the subquery (which must have one column), where
``<op>`` is ``=``, ``<>``, ``<``, ``>``, ``<=`` or ``>=``. ``SOME`` and ``ANY``
are the same.

``ALL`` is ``TRUE`` if the comparison is ``TRUE`` for every row (or there are no
rows), and ``FALSE`` if it's ``FALSE`` for any row. ``SOME`` is ``TRUE`` if the
comparison is ``TRUE`` for any row, and ``FALSE`` if it's ``FALSE`` for every row
(or there are no rows). Otherwise, because of a ``NULL``, the result is
``UNKNOWN``.

*Examples*

.. code-block:: sql

  4 > ALL (VALUES 1, 2, 3)                     -- TRUE
  2 > ALL (VALUES 1, 2, 3)                     -- FALSE
  2 > SOME (VALUES 1, 2, 3)                    -- TRUE
  1 = ANY (VALUES 2, CAST(NULL AS INT))        -- UNKNOWN
  1 = ALL (SELECT x FROM t WHERE x > 100)      -- TRUE (no rows)

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

EXISTS
------

.. code-block:: text

  EXISTS ( <query> )

Returns ``TRUE`` if the subquery returns any rows, otherwise ``FALSE``. It's
never ``UNKNOWN``, and the subquery can have any number of columns.

*Examples*

.. code-block:: sql

  EXISTS (SELECT * FROM products WHERE price > 100)
  EXISTS (VALUES 1)                                    -- TRUE
  NOT EXISTS (SELECT * FROM products)

IS NULL
-------

.. code-block:: text

  X IS [ NOT ] NULL
  ( X1 , X2 [ , X3 ... ] ) IS [ NOT ] NULL
  ROW ( X1 [ , X2 ... ] ) IS [ NOT ] NULL

Tests if ``X`` is (or is not) ``NULL``.

For a row, ``IS NULL`` is ``TRUE`` only if every value is ``NULL``, and
``IS NOT NULL`` is ``TRUE`` only if none of the values are ``NULL``. So a row
that contains some ``NULL`` values is neither, and ``NOT (... IS NULL)`` isn't
the same as ``... IS NOT NULL``.

*Examples*

.. code-block:: sql

  (1, 2) IS NOT NULL                                   -- TRUE
  (CAST(NULL AS INT), CAST(NULL AS INT)) IS NULL       -- TRUE
  (1, CAST(NULL AS INT)) IS NULL                       -- FALSE
  (1, CAST(NULL AS INT)) IS NOT NULL                   -- FALSE

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

``NEXT VALUE FOR`` can't be used in a subquery (such as in ``EXISTS``), or on
either side of a ``UNION`` or ``EXCEPT``, since the number of times it's
evaluated depends on the query that contains it.

*Examples*

.. code-block:: sql

  CREATE SEQUENCE my_sequence;
  VALUES NEXT VALUE FOR my_sequence, NEXT VALUE FOR my_sequence;
  VALUES ROW(NEXT VALUE FOR my_sequence, NEXT VALUE FOR my_sequence);
  -- msg: CREATE SEQUENCE 1
  -- COL1: 1
  -- COL1: 2
  -- COL1: 3 COL2: 3

Scalar Subquery
---------------

.. code-block:: text

  ( <query> )

A subquery can be used as a value anywhere an expression can, such as in a
comparison (``x = (SELECT MAX(x) FROM t)``), the select list or the ``SET`` of an
``UPDATE``. It must have one column, and it's the value of that column in its
only row. It's ``NULL`` if there are no rows, and a 21000 cardinality violation
error if there is more than one row.

A subquery can't be used in a ``CHECK`` constraint, or in the argument of an
aggregate function (such as ``MAX``).

Correlated Subqueries
^^^^^^^^^^^^^^^^^^^^^

Any subquery (including in ``EXISTS``, ``IN``, ``ALL`` and ``SOME``) can refer
to the columns of the queries that contain it, such as ``t1.x`` in:

.. code-block:: sql

  SELECT * FROM t1 WHERE EXISTS (SELECT * FROM t2 WHERE t2.x = t1.x)

The subquery is evaluated for each row of the outer query. A column name is
found in the innermost query that has it, so ``x`` would be ``t2.x`` above. Use
a correlation name to tell apart the same table, such as
``SELECT * FROM t AS a WHERE EXISTS (SELECT * FROM t AS b WHERE b.x > a.x)``.

In a grouped query (or ``HAVING``), a column of the outer query must be one of
its ``GROUP BY`` columns. An aggregate function of only outer columns (such as
``SELECT (SELECT MAX(t1.x) FROM t2) FROM t1``) is an aggregate of the outer
query, so the outer query is grouped (like any other aggregate function in its
select list) and the subquery uses the result. It can't be in the ``WHERE`` of
the outer query. An aggregate function that also uses a column of the subquery
(such as ``MAX(t2.z + t1.x)``) is an aggregate of the subquery.

*Examples*

.. code-block:: sql

  SELECT * FROM products WHERE price = (SELECT MAX(price) FROM products)
  VALUES (SELECT COUNT(*) FROM products) + 1
  VALUES (SELECT x FROM t WHERE x > 100)               -- NULL (no rows)

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
