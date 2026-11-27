NULL
====

.. contents::

``NULL`` is a value that means unknown or missing. A column of any type can be
``NULL`` unless it's ``NOT NULL`` (or part of a ``PRIMARY KEY``), and inserting
a ``NULL`` into a ``NOT NULL`` column is a ``23502`` error:

.. code-block:: sql

  CREATE TABLE products (id INT NOT NULL, price INT);
  INSERT INTO products (id, price) VALUES (1, NULL);
  INSERT INTO products (id, price) VALUES (NULL, 5);
  -- msg: CREATE TABLE 1
  -- msg: INSERT 1
  -- error 23502: violates non-null constraint: column ID

Writing NULL
------------

A ``NULL`` on its own has no type, so ``NULL`` can only be written where the
type comes from somewhere else: a value of ``INSERT ... VALUES``, the new value
of an ``UPDATE ... SET``, a ``DEFAULT`` and the result of a ``CASE``. Anywhere
else, such as an operand of an operator or an argument of a function, use
``CAST`` to give it a type:

.. code-block:: sql

  VALUES CAST(NULL AS INT);
  -- COL1: NULL

  VALUES NULL;
  -- error 42601: syntax error: unexpected $end at line 1, column 12 near "VALUES NULL", expecting "::"

``NULL::INT`` is the same as ``CAST(NULL AS INT)`` (see
:doc:`compatibility-postgresql`).

Comparisons
-----------

Since ``NULL`` is unknown, comparing it with any value, even another ``NULL``,
gives ``UNKNOWN`` rather than ``TRUE`` or ``FALSE``. Use ``IS NULL`` or
``IS NOT NULL`` (see :ref:`expressions:IS NULL`) to test for ``NULL``, and
``IS [ NOT ] DISTINCT FROM`` to compare two values where ``NULL`` is the same as
``NULL``:

.. code-block:: sql

  VALUES ROW(CAST(NULL AS INT) = 1, CAST(NULL AS INT) = CAST(NULL AS INT));
  -- COL1: UNKNOWN COL2: UNKNOWN

  VALUES ROW(CAST(NULL AS INT) IS NULL, 1 IS NOT NULL);
  -- COL1: TRUE COL2: TRUE

  VALUES ROW(CAST(NULL AS INT) IS NOT DISTINCT FROM CAST(NULL AS INT), 1 IS DISTINCT FROM CAST(NULL AS INT));
  -- COL1: TRUE COL2: TRUE

``x = NULL`` is a syntax error, since ``NULL`` doesn't have a type there, which
catches the common mistake of writing it instead of ``x IS NULL``.

Three-Valued Logic
------------------

``UNKNOWN`` is the ``NULL`` of the ``BOOLEAN`` type, so a condition is ``TRUE``,
``FALSE`` or ``UNKNOWN``. ``NOT UNKNOWN`` is ``UNKNOWN``. ``AND`` and ``OR`` are
only ``UNKNOWN`` when the result depends on the unknown value, so ``TRUE OR
UNKNOWN`` is ``TRUE`` and ``FALSE AND UNKNOWN`` is ``FALSE`` (see
:ref:`booleans:Logical Operations` for the full tables):

.. code-block:: sql

  VALUES ROW(TRUE OR UNKNOWN, FALSE AND UNKNOWN, NOT UNKNOWN, UNKNOWN IS UNKNOWN);
  -- COL1: TRUE COL2: FALSE COL3: UNKNOWN COL4: TRUE

``IN`` is ``TRUE`` when the value is equal to one of the list, ``FALSE`` when
it's not equal to any of them, and otherwise ``UNKNOWN``. So when the list has a
``NULL``, ``NOT IN`` can never be ``TRUE``:

.. code-block:: sql

  VALUES ROW(1 IN (1, CAST(NULL AS INT)), 2 IN (1, CAST(NULL AS INT)), 2 NOT IN (1, CAST(NULL AS INT)));
  -- COL1: TRUE COL2: UNKNOWN COL3: UNKNOWN

A ``WHERE`` (or ``HAVING``, or ``ON`` of a join) only keeps the rows where the
condition is ``TRUE``, so a row where it's ``UNKNOWN`` is left out, the same as
``FALSE``. A ``CHECK`` constraint is the other way around: it's only violated
when the condition is ``FALSE``, so a ``NULL`` passes it:

.. code-block:: sql

  CREATE TABLE products (id INT, price INT CHECK (price > 0));
  INSERT INTO products (id, price) VALUES (1, NULL), (2, 5);
  SELECT id FROM products WHERE price > 1;
  SELECT id FROM products WHERE price IS NULL;
  -- msg: CREATE TABLE 1
  -- msg: INSERT 2
  -- ID: 2
  -- ID: 1

Operators and Functions
-----------------------

Most operators and functions are ``NULL`` when any argument is ``NULL``. That
includes arithmetic, ``||``, ``LIKE`` and ``SIMILAR TO`` (which are
``UNKNOWN``) and functions such as ``UPPER`` and ``ABS``. The ``NULL`` is
returned before the operation is checked, so dividing a ``NULL`` by zero is
``NULL`` and not an error:

.. code-block:: sql

  VALUES ROW(1 + CAST(NULL AS INT), 'a' || CAST(NULL AS VARCHAR(10)), CAST(NULL AS INT) / 0);
  -- COL1: NULL COL2: NULL COL3: NULL

The exceptions are the ones that are about ``NULL``, such as ``IS NULL``,
``IS DISTINCT FROM``, ``CASE``, ``COALESCE``, ``NULLIF`` and ``IF`` (see
:doc:`functions-conditional`):

.. code-block:: sql

  VALUES COALESCE(CAST(NULL AS INT), 0);
  -- COL1: 0

  VALUES IF(CAST(NULL AS BOOLEAN), 'yes', 'no');
  -- COL1: no

Aggregate Functions
-------------------

``COUNT(*)`` counts every row. The other aggregate functions (such as
``COUNT(x)``, ``SUM``, ``AVG``, ``MIN`` and ``MAX``) skip the ``NULL`` values,
and give a ``01003`` warning (null value eliminated in set function) when they
do. When there are no values left, ``COUNT`` is ``0`` and the others are
``NULL``:

.. code-block:: sql

  CREATE TABLE products (id INT, price INT);
  INSERT INTO products (id, price) VALUES (1, 10), (2, NULL), (3, 20);
  SELECT COUNT(*), COUNT(price), SUM(price) FROM products;
  SELECT COUNT(price), SUM(price) FROM products WHERE price IS NULL;
  -- msg: CREATE TABLE 1
  -- msg: INSERT 3
  -- warning 01003: null value eliminated in set function
  -- COL1: 3 COL2: 2 COL3: 30
  -- warning 01003: null value eliminated in set function
  -- COL1: 0 COL2: NULL

GROUP BY, DISTINCT and Set Operations
-------------------------------------

Although ``NULL = NULL`` is ``UNKNOWN``, ``NULL`` values aren't distinct from
each other when rows are grouped or duplicates are removed. So all of the
``NULL`` values are one group in a ``GROUP BY``, and ``SELECT DISTINCT``,
``UNION``, ``EXCEPT`` and ``INTERSECT`` treat two ``NULL`` values as the same:

.. code-block:: sql

  CREATE TABLE products (id INT, price INT);
  INSERT INTO products (id, price) VALUES (1, NULL), (2, NULL), (3, 5);
  SELECT price, COUNT(*) FROM products GROUP BY price;
  SELECT DISTINCT price FROM products;
  -- msg: CREATE TABLE 1
  -- msg: INSERT 3
  -- PRICE: NULL COL2: 2
  -- PRICE: 5 COL2: 1
  -- PRICE: NULL
  -- PRICE: 5

UNIQUE
------

In a ``UNIQUE`` constraint (see :ref:`create-table:Unique Constraints`) and the
``UNIQUE`` predicate (see :ref:`expressions:UNIQUE`), by default (``NULLS
DISTINCT``) a row that has a ``NULL`` is never a duplicate of another
row, so any number of rows can have a ``NULL`` in a ``UNIQUE`` column. With
``NULLS NOT DISTINCT``, a ``NULL`` is the same as another ``NULL``:

.. code-block:: sql

  CREATE TABLE t (a INT UNIQUE, b INT, UNIQUE NULLS NOT DISTINCT (b));
  INSERT INTO t (a, b) VALUES (NULL, 1);
  INSERT INTO t (a, b) VALUES (NULL, NULL);
  INSERT INTO t (a, b) VALUES (NULL, NULL);
  -- msg: CREATE TABLE 1
  -- msg: INSERT 1
  -- msg: INSERT 1
  -- error 23505: violates unique constraint: UNIQUE (B) on ":memory:".PUBLIC.T

Ordering
--------

``NULL`` is less than any other value when sorting, so it's first for ``ASC``
and last for ``DESC`` (the SQL standard leaves this up to each database).
``NULLS FIRST`` or ``NULLS LAST`` after a sort key puts them first or last,
whatever the direction (see :ref:`select:ORDER BY`):

.. code-block:: sql

  CREATE TABLE products (id INT, price INT);
  INSERT INTO products (id, price) VALUES (1, 10), (2, NULL), (3, 20);
  SELECT id FROM products ORDER BY price;
  SELECT id FROM products ORDER BY price NULLS LAST;
  -- msg: CREATE TABLE 1
  -- msg: INSERT 3
  -- ID: 2
  -- ID: 1
  -- ID: 3
  -- ID: 1
  -- ID: 3
  -- ID: 2

Nullable Result Columns
-----------------------

Each column of a result is either known to never be ``NULL`` (``NOT NULL``) or
can be ``NULL``. This is what a client sees as the nullability of a column,
such as the ``NULLABLE`` of ``DESCRIBE`` (see :doc:`language-c`), and
:doc:`explain` shows it too.

A result column is ``NOT NULL`` only when it's a reference to a ``NOT NULL``
column (including a ``PRIMARY KEY`` column, a grouping column and a column of a
derived table), however it's named. Any other expression can be ``NULL``, even
one that never is, such as ``id + 1`` or ``COALESCE(x, 0)``. After an outer
join, a column of the side that doesn't keep all of its rows can be ``NULL``
(see :ref:`select:JOIN`).

.. code-block:: sql

  CREATE TABLE products (id INT NOT NULL, price INT);
  EXPLAIN SELECT id, price, id + 1 FROM products;
  -- msg: CREATE TABLE 1
  -- EXPLAIN: TABLE ":memory:".PUBLIC.PRODUCTS (ID INTEGER NOT NULL, PRICE INTEGER)
  -- EXPLAIN: EXPR (ID INTEGER NOT NULL, PRICE INTEGER, COL3 INTEGER)
