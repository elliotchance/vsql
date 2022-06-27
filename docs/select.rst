SELECT
======

A ``SELECT`` statement is used to retrieve rows from one or more tables.

.. contents::

Syntax
------

.. code-block:: text

  SELECT <expression> [ AS <name> ] , ...
  FROM <table_name>
  [ [ INNER | { LEFT | RIGHT } [ OUTER ] ] JOIN <table_name> ON <condition> ]
  [ WHERE <condition> ]
  [ GROUP BY <column_name> , ... ]
  [ ORDER BY <expr> [ ASC | DESC ] , ... ]
  [ OFFSET <integer> { ROW | ROWS } ]
  [ FETCH FIRST <integer> { ROW | ROWS } ONLY ]

SELECT
------

For each *expression*, the naming convention follows:

1. If ``name`` is provided, that will be used.
2. If ``expression`` refered to a column, the column name will be used.
3. Otherwise, the name ``COL<number>`` will be used where *number* is the position of the column (starting at 1).

JOIN
----

vsql supports three types of JOIN operations:

1. ``INNER JOIN`` (or, more simply: ``JOIN``).
2. ``LEFT OUTER JOIN`` (or, more simply: ``LEFT JOIN``).
3. ``RIGHT OUTER JOIN`` (or, more simply: ``RIGHT JOIN``).

For an ``INNER JOIN``, only records that satisfy the ``<condition>`` in *both*
tables will be included.

Whereas ``LEFT OUTER JOIN`` and ``RIGHT OUTER JOIN`` will always include all
records from the *left* or *right* table respectively. Any record that does not
match the other side will be given all ``NULL`` values. The *left* table is that
defined by the ``FROM`` expressions and the *right* table is that used in the
``JOIN`` clause.

WHERE
-----

If ``WHERE`` is not provided all rows are returned.

GROUP BY
--------

The ``GROUP BY`` clause is used to group rows such that aggregation functions
such as `count`, `min`, `max`, etc can be performed against them.

If an aggregate function is used is the ``SELECT`` expressions it will cause
*all* rows to be included in a single set. For example:

.. code-block:: sql

  SELECT min(price) FROM products;

Otherwise, aggregation expressions are calculated from each set defined by the
``GROUP BY`` columns. For example, to find the average price in each city:

.. code-block:: sql

  SELECT city, AVG(price) FROM products GROUP BY city;

See full list of :doc:`functions`.

ORDER BY
--------

The ``ORDER BY`` clause can be used to sort records.

Without an ``ORDER BY`` clause the rows might come out in a predictable order,
such as the order or insertion or the order of the PRIMARY KEY. However, you
should never depend on this since it's subject to change either through
deliberate or emergent behavior. If you need the rows to be returned in a
specific order you should always specify an appropriate ``ORDER BY`` clause.

The ``ORDER BY`` contains one or more expressions. Each specifying an ``ASC`` or
``DESC`` for ascending or descending respectively. If no qualifier is specified
then ``ASC`` is used.

The SQL standard doesn't define if ``NULL`` should be always be ordered first or
last. In vsql, ``NULL`` is always considered to be less than any other non
``NULL`` value.

OFFSET
------

If ``OFFSET`` is provided, that number of rows will be skipped. If the
``OFFSET`` rows is greater than whole result set zero rows will be returned.

Using ``ROW`` or ``ROWS`` has no functional difference and either can be used
with any value. Both words are provided soley for grammatical benefit.

FETCH
-----

``FETCH`` can be used to limit the number of rows returned. ``FETCH`` can be
used in combination with ``OFFSET`` for further control.

If the ``FETCH`` rows is greater than the total set, all rows will be returned.

Using ``ROW`` or ``ROWS`` has no functional difference and either can be used
with any value. Both words are provided soley for grammatical benefit.

EXPLAIN
-------

The query planner will decide the best strategy to execute the ``SELECT``. You
can see this plan by using the ``EXPLAIN`` prefix. See :doc:`explain`.

Examples
--------

.. code-block:: sql

  SELECT * FROM products;

  SELECT price * (1 + tax) AS total
  FROM products;

  SELECT * FROM products ORDER BY price;
