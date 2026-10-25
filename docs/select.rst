SELECT
======

A ``SELECT`` statement is used to retrieve rows from one or more tables.

.. contents::

Syntax
------

.. code-block:: text

  SELECT [ ALL | DISTINCT ] { * | { <expression> [ AS <name> ] | <table_name>.* } , ... }
  FROM <table_reference>
  [ [ INNER | { LEFT | RIGHT } [ OUTER ] ] JOIN <table_reference> ON <condition> ] ...
  [ WHERE <condition> ]
  [ GROUP BY <column_name> , ... ]
  [ HAVING <condition> ]
  [ ORDER BY <expr> [ ASC | DESC ] , ... ]
  [ OFFSET <integer> { ROW | ROWS } ]
  [ FETCH FIRST [ <integer> ] { ROW | ROWS } ONLY ]

  <table_reference> := { <table_name> | ( <query> ) }
                       [ [ AS ] <name> [ ( <column_name> , ... ) ] ]

  <query> { UNION | EXCEPT } [ ALL | DISTINCT ] <query>
  [ ORDER BY <expr> [ ASC | DESC ] , ... ]
  [ OFFSET <integer> { ROW | ROWS } ]
  [ FETCH FIRST [ <integer> ] { ROW | ROWS } ONLY ]

A ``<query>`` is a ``SELECT``, ``VALUES``, ``UNION`` or ``EXCEPT``. It can be in
parentheses, such as ``(SELECT ... FETCH FIRST 1 ROW ONLY)``.

``AS <name>`` gives the table a *correlation name*. The table must then be
referred to by that name instead (such as ``p.price``). The optional list of
column names renames each of the table's columns, in order.

A ``SELECT`` must have a ``FROM``. To calculate expressions without a table,
use :doc:`values` (such as ``VALUES 1 + 2``).

A subquery can also be used in an expression, such as ``EXISTS``, ``IN``,
``ALL`` and ``SOME``, or as a value. See :doc:`expressions`.

A subquery can refer to the columns of the query that contains it (a correlated
subquery).

Not supported yet: ``INTERSECT``. See :doc:`sql-compliance`.

SELECT
------

For each *expression*, the naming convention follows:

1. If ``name`` is provided, that will be used.
2. If ``expression`` referred to a column, the column name will be used.
3. Otherwise, the name ``COL<number>`` will be used where *number* is the position of the column (starting at 1).

``*`` selects every column of every table in the ``FROM`` clause. It must be
the only item in the list, so use ``<table_name>.*`` to select every column of a
table along with other expressions:

.. code-block:: sql

  SELECT products.*, price * (1 + tax) AS total
  FROM products;

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

Any number of tables can be joined. Each ``JOIN`` uses the result of the joins
before it as its *left* table, unless parentheses are used to change the order:

.. code-block:: sql

  SELECT * FROM t1
  LEFT JOIN t2 ON t1.a = t2.b
  LEFT JOIN t3 ON t1.a = t3.c;

  SELECT * FROM t1
  LEFT JOIN (t2 JOIN t3 ON t2.b = t3.c) ON t1.a = t2.b;

The same table name cannot be used more than once in a ``FROM`` clause. Use
correlation names to join a table to itself:

.. code-block:: sql

  SELECT child.name, parent.name
  FROM categories AS child
  JOIN categories AS parent ON child.parent_id = parent.id;

WHERE
-----

If ``WHERE`` is not provided all rows are returned.

GROUP BY
--------

The ``GROUP BY`` clause is used to group rows such that aggregation functions
such as ``COUNT``, ``MIN``, ``MAX``, etc can be performed against them.

If an aggregate function is used in the ``SELECT`` expressions it will cause
*all* rows to be included in a single set. For example:

.. code-block:: sql

  SELECT min(price) FROM products;

Otherwise, aggregation expressions are calculated from each set defined by the
``GROUP BY`` columns. For example, to find the average price in each city:

.. code-block:: sql

  SELECT city, AVG(price) FROM products GROUP BY city;

Each column in the ``SELECT`` expressions must be one of the ``GROUP BY``
columns, or only be used in an aggregate function. Otherwise, a ``42803``
error is returned because there could be more than one value for the column in
each set. ``*`` counts as every column, so it can only be used when all of the
columns are grouped.

See full list of :doc:`functions`.

DISTINCT
--------

``SELECT DISTINCT`` removes duplicate rows from the result. Rows are duplicates
when every column is equal, and ``NULL`` is equal to ``NULL`` for this:

.. code-block:: sql

  SELECT DISTINCT city FROM products;

``SELECT ALL`` is the same as ``SELECT`` and keeps all of the rows.

With ``DISTINCT``, the ``ORDER BY`` can only use the columns in the ``SELECT``
expressions, or an expression that is also in the ``SELECT`` expressions. For
example, ``SELECT DISTINCT city FROM products ORDER BY price`` returns a
``42P10`` error because each city could have more than one price.

HAVING
------

The ``HAVING`` clause removes groups, in the same way that ``WHERE`` removes
rows. Only the groups where the condition is ``TRUE`` are kept. For example, to
find the cities with more than 10 products:

.. code-block:: sql

  SELECT city, COUNT(*) FROM products GROUP BY city HAVING COUNT(*) > 10;

The condition can use aggregate functions, even if they are not in the
``SELECT`` expressions. Like the ``SELECT`` expressions, any other column must
be one of the ``GROUP BY`` columns (or a ``42803`` error is returned).

Without a ``GROUP BY``, the whole table is a single group. So the result has at
most one row, even when the table is empty:

.. code-block:: sql

  SELECT COUNT(*) FROM products HAVING COUNT(*) = 0;

UNION and EXCEPT
----------------

``UNION`` and ``EXCEPT`` combine the rows of two queries:

- ``UNION ALL`` returns the rows of both queries.
- ``UNION`` (or ``UNION DISTINCT``) returns each distinct row of both queries.
- ``EXCEPT ALL`` returns the rows of the left query, with one fewer of each
  row for every time that row is in the right query.
- ``EXCEPT`` (or ``EXCEPT DISTINCT``) returns each distinct row of the left
  query that is not in the right query.

Rows are the same when each of their values are equal, and two ``NULL`` values
are considered the same. For example:

.. code-block:: sql

  SELECT city FROM customers
  UNION
  SELECT city FROM suppliers;

  SELECT id FROM products
  EXCEPT
  SELECT product_id FROM orders;

Both queries must have the same number of columns, and each column must have
compatible types (such as ``INTEGER`` and ``BIGINT``, or ``CHAR`` and
``VARCHAR``). Each column of the result has a type that fits the values of
both queries, and the name of that column in the left query.

The operators are evaluated left to right. Use parentheses to change the order.

The ``ORDER BY``, ``OFFSET`` and ``FETCH FIRST`` at the end apply to the whole
result, so the ``ORDER BY`` can only use the columns of the result. A query in
parentheses can have its own:

.. code-block:: sql

  (SELECT name FROM products ORDER BY price DESC FETCH FIRST 3 ROWS ONLY)
  UNION ALL
  (SELECT name FROM products ORDER BY price FETCH FIRST 3 ROWS ONLY)
  ORDER BY name;

ORDER BY
--------

The ``ORDER BY`` clause can be used to sort records.

Without an ``ORDER BY`` clause the rows might come out in a predictable order,
such as the order of insertion or the order of the ``PRIMARY KEY``. However, you
should never depend on this since it's subject to change either through
deliberate or emergent behavior. If you need the rows to be returned in a
specific order you should always specify an appropriate ``ORDER BY`` clause.

The ``ORDER BY`` contains one or more expressions. Each specifying an ``ASC`` or
``DESC`` for ascending or descending respectively. If no qualifier is specified
then ``ASC`` is used.

The SQL standard doesn't define if ``NULL`` should always be ordered first or
last. In vsql, ``NULL`` is always considered to be less than any other non
``NULL`` value.

OFFSET
------

If ``OFFSET`` is provided, that number of rows will be skipped. If the
``OFFSET`` rows is greater than whole result set zero rows will be returned.

The ``OFFSET`` must be an integer that is zero or more, otherwise a 2201X
(invalid row count in result offset clause) error is raised.

Using ``ROW`` or ``ROWS`` has no functional difference and either can be used
with any value. Both words are provided solely for grammatical benefit.

FETCH
-----

``FETCH`` can be used to limit the number of rows returned. ``FETCH`` can be
used in combination with ``OFFSET`` for further control.

If the ``FETCH`` rows is greater than the total set, all rows will be returned.

The ``FETCH`` rows must be an integer that is one or more, otherwise a 2201W
(invalid row count in fetch first clause) error is raised.

When either value is a parameter it may be any numeric value that is a whole
number, such as ``2.0``.

When the ``<integer>`` is omitted (for example ``FETCH FIRST ROW ONLY``) it
defaults to ``1``, so only the first row is returned.

Using ``ROW`` or ``ROWS`` has no functional difference and either can be used
with any value. Both words are provided solely for grammatical benefit.

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
