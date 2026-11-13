SELECT
======

A ``SELECT`` statement is used to retrieve rows from one or more tables.

.. contents::

Syntax
------

.. code-block:: text

  SELECT [ ALL | DISTINCT ] { * | { <expression> [ AS <name> ] | <table_name>.* } , ... }
  [ FROM <from_item> , ...
    [ WHERE <condition> ]
    [ GROUP BY <column_name> , ... ]
    [ HAVING <condition> ] ]
  [ ORDER BY <expr> [ ASC | DESC ] , ... ]
  [ OFFSET <integer> { ROW | ROWS } ]
  [ FETCH { FIRST | NEXT } [ <integer> ] { ROW | ROWS } ONLY ]

  <from_item> := <table_reference>
                 [ [ INNER | { LEFT | RIGHT } [ OUTER ] ] JOIN <table_reference>
                   { ON <condition> | USING ( <column_name> , ... ) } ] ...

  <table_reference> := { <table_name> | ( <query> ) | <data_change_delta_table> }
                       [ [ AS ] <name> [ ( <column_name> , ... ) ] ]

  TABLE <table_name>
  [ ORDER BY <expr> [ ASC | DESC ] , ... ]
  [ OFFSET <integer> { ROW | ROWS } ]
  [ FETCH { FIRST | NEXT } [ <integer> ] { ROW | ROWS } ONLY ]

  <query> { UNION | EXCEPT | INTERSECT } [ ALL | DISTINCT ] <query>
  [ ORDER BY <expr> [ ASC | DESC ] , ... ]
  [ OFFSET <integer> { ROW | ROWS } ]
  [ FETCH { FIRST | NEXT } [ <integer> ] { ROW | ROWS } ONLY ]

``LIMIT`` can be used instead of ``FETCH`` in either of these (see `LIMIT`_):

.. code-block:: text

  [ ORDER BY <expr> [ ASC | DESC ] , ... ]
  { LIMIT <integer> [ OFFSET <integer> [ ROW | ROWS ] ]
  | OFFSET <integer> [ ROW | ROWS ] LIMIT <integer>
  | LIMIT <offset>, <count> }

A ``<query>`` is a ``SELECT``, ``TABLE``, ``VALUES``, ``UNION``, ``EXCEPT`` or
``INTERSECT``. It can be in parentheses, such as ``(SELECT ... FETCH FIRST 1 ROW ONLY)``.

``AS <name>`` gives the table a *correlation name*. The table must then be
referred to by that name instead (such as ``p.price``). The optional list of
column names renames each of the table's columns, in order.

More than one item in ``FROM``, separated by commas, produces every combination
of their rows. ``WHERE`` can be used as the join condition:

.. code-block:: sql

  SELECT products.name, categories.name
  FROM products, categories
  WHERE products.category_id = categories.id;

The columns of ``*`` are in the order of the items. A ``JOIN`` belongs to the
item it's written in, so its ``ON`` can't refer to the other items (``t1`` in
``FROM t1, t2 JOIN t3 ON ...``), and neither can a subquery in ``FROM``.

A ``SELECT`` without a ``FROM`` produces exactly one row, so it can calculate
expressions without a table:

.. code-block:: sql

  SELECT 1 + 2 AS x, 'a';
  -- X: 3 COL2: a

This is a vsql extension and not standard SQL, where a ``SELECT`` must have a
``FROM``. It's flagged as ``V201-01`` (see :doc:`sql-flagging`). The standard
form is ``VALUES`` (see :doc:`values`), such as ``VALUES 1 + 2``.

It can be used anywhere that a query can, and aggregate functions see the one
row, so ``SELECT COUNT(*)`` is 1. There are no columns, so ``*`` and a column
reference are errors, unless it's a subquery that refers to a column of the query
that contains it. ``WHERE``, ``GROUP BY`` and ``HAVING`` need a ``FROM``.

A subquery can also be used in an expression, such as ``EXISTS``, ``IN``,
``ALL`` and ``SOME``, or as a value. See :doc:`expressions`.

A subquery can refer to the columns of the query that contains it (a correlated
subquery).

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

``USING`` joins on the equality of each named column, which must be the name of
exactly one column on each side, and those columns must be comparable. Each
named column is only in the result once:

.. code-block:: sql

  CREATE TABLE t (x INTEGER, a INTEGER);
  CREATE TABLE u (x INTEGER, b INTEGER);

  SELECT * FROM t LEFT JOIN u USING (x);
  -- X, A, B

The named columns are first (in the order of the left side), then the other
columns of the left side, then the other columns of the right side. Each named
column has the value of the left side if that isn't ``NULL``, otherwise the
right side, so it's only ``NULL`` when both are.

Refer to a named column without a table (``x``). ``t.x`` and ``u.x`` no longer
exist, and ``t.*`` doesn't include ``x``.

The same table name cannot be used more than once in a ``FROM`` clause. Use
correlation names to join a table to itself:

.. code-block:: sql

  SELECT child.name, parent.name
  FROM categories AS child
  JOIN categories AS parent ON child.parent_id = parent.id;

FINAL TABLE, NEW TABLE and OLD TABLE
------------------------------------

A *data change delta table* runs an ``INSERT``, ``UPDATE`` or ``DELETE`` (see
:doc:`insert`, :doc:`update` and :doc:`delete`) and returns the rows that it
changed, so that a statement can change rows and return them at the same time:

.. code-block:: text

  <data_change_delta_table> :=
    { FINAL | NEW | OLD } TABLE ( { <insert> | <update> | <delete> } )

.. code-block:: sql

  CREATE TABLE products (
    id INT GENERATED ALWAYS AS IDENTITY,
    name VARCHAR(50),
    price INT DEFAULT 0
  );

  SELECT id, price FROM FINAL TABLE (INSERT INTO products (name) VALUES ('Bread'));
  -- ID: 1 PRICE: 0

  SELECT p.name FROM OLD TABLE (DELETE FROM products WHERE price = 0) AS p;
  -- NAME: Bread

The columns are the columns of the table that's changed. ``OLD TABLE`` is each
row as it was before an ``UPDATE`` or ``DELETE``, and ``NEW TABLE`` is each row
as it is after an ``INSERT`` or ``UPDATE``. A row that an ``UPDATE`` identifies
is included even if none of its values change. So ``OLD TABLE`` can't be used
with an ``INSERT``, and ``NEW TABLE`` can't be used with a ``DELETE``.

``FINAL TABLE`` is the same as ``NEW TABLE``, except that nothing else can
change the table while the statement runs. The only thing that could is a
referential action of a ``FOREIGN KEY`` that references the same table (such
as ``ON UPDATE CASCADE``, see :doc:`create-table`), which is then an error
(``27001``).

It must be the only item in the ``FROM`` of a query that's a whole statement,
or the query of a cursor (see :doc:`cursors`). It can't be joined to another
table, and it can't be in a subquery, a ``UNION`` (or ``EXCEPT`` or
``INTERSECT``) or the query of an ``INSERT``. The query is a statement that
changes the database, so it can't be used in a ``READ ONLY`` transaction, and a
cursor runs the statement each time it's opened. ``MERGE`` isn't supported.

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

TABLE
-----

``TABLE <table_name>`` is a shorter way to write ``SELECT * FROM
<table_name>``. It can be used anywhere a query can, such as in a subquery:

.. code-block:: sql

  TABLE products ORDER BY price;

  SELECT COUNT(*) FROM (TABLE products) AS p;

UNION, EXCEPT and INTERSECT
---------------------------

``UNION``, ``EXCEPT`` and ``INTERSECT`` combine the rows of two queries:

- ``UNION ALL`` returns the rows of both queries.
- ``UNION`` (or ``UNION DISTINCT``) returns each distinct row of both queries.
- ``EXCEPT ALL`` returns the rows of the left query, with one fewer of each
  row for every time that row is in the right query.
- ``EXCEPT`` (or ``EXCEPT DISTINCT``) returns each distinct row of the left
  query that is not in the right query.
- ``INTERSECT ALL`` returns each row that is in both queries, as many times as
  it is in the query that has fewer of it.
- ``INTERSECT`` (or ``INTERSECT DISTINCT``) returns each distinct row that is in
  both queries.

Rows are the same when each of their values are equal, and two ``NULL`` values
are considered the same. For example:

.. code-block:: sql

  SELECT city FROM customers
  UNION
  SELECT city FROM suppliers;

  SELECT id FROM products
  EXCEPT
  SELECT product_id FROM orders;

  SELECT city FROM customers
  INTERSECT
  SELECT city FROM suppliers;

Both queries must have the same number of columns, and each column must have
compatible types (such as ``INTEGER`` and ``BIGINT``, or ``CHAR`` and
``VARCHAR``). Each column of the result has a type that fits the values of
both queries, and the name of that column in the left query.

``INTERSECT`` is evaluated before ``UNION`` and ``EXCEPT``, so ``a UNION b
INTERSECT c`` is ``a UNION (b INTERSECT c)``. Otherwise, the operators are
evaluated left to right. Use parentheses to change the order.

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

A name in an expression of the ``ORDER BY`` is a column of the result if there
is one with that name, otherwise it's a column of a table. So the alias of a
``SELECT`` expression can be used, including as part of a larger expression, and
it hides a column of a table with the same name. Use a qualified name for the
column of the table:

.. code-block:: sql

  -- Ordered by the negative price (highest first).
  SELECT -price AS price FROM products ORDER BY price;

  -- Ordered by the original price (lowest first).
  SELECT -price AS price FROM products ORDER BY products.price;

If the result has more than one column with that name, it's a ``42702``
(ambiguous column) error. An alias can't be used by a subquery or the argument of
an aggregate function in the ``ORDER BY``.

An expression can only contain an aggregate function if the query is grouped (it
has a ``GROUP BY``, a ``HAVING`` or an aggregate function in the ``SELECT``
expressions). The aggregate function doesn't need to be in the ``SELECT``
expressions, for example:

.. code-block:: sql

  SELECT city FROM products GROUP BY city ORDER BY MAX(price);

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

LIMIT
-----

``LIMIT <integer>`` is the same as ``FETCH FIRST <integer> ROWS ONLY``. This is a
vsql extension, not standard SQL, and it's flagged by ``V203-01`` (see
:doc:`sql-flagging`). ``FETCH FIRST`` should be used if the SQL needs to be
portable. It's accepted anywhere that ``FETCH FIRST`` is and has the same rules
for the row count, including the same 2201W error, and it produces the same plan.

An ``OFFSET`` can be before or after the ``LIMIT``:

.. code-block:: sql

  SELECT * FROM products ORDER BY price LIMIT 10;

  SELECT * FROM products ORDER BY price LIMIT 10 OFFSET 20;

  SELECT * FROM products ORDER BY price OFFSET 20 LIMIT 10;

The ``ROW`` or ``ROWS`` of any ``OFFSET`` can be left out, with or without a
``LIMIT`` or ``FETCH``. This is flagged by ``V203-02``:

.. code-block:: sql

  SELECT * FROM products ORDER BY price OFFSET 20;

``LIMIT <offset>, <count>`` is the same as ``LIMIT <count> OFFSET <offset>``, the
offset is first. This is flagged by ``V203-03``, and it can't be used with
another ``OFFSET``:

.. code-block:: sql

  SELECT * FROM products ORDER BY price LIMIT 20, 10;

A query can't have both ``LIMIT`` and ``FETCH``. There's no ``LIMIT ALL``.

``LIMIT`` isn't a reserved word, so it can still be the name of a table or a
column, or an alias with or without ``AS``. It only starts the clause when it's
followed by a row count: in ``SELECT * FROM t LIMIT 5`` it's the clause and in
``SELECT * FROM t limit`` it's an alias. ``SELECT limit - 1 FROM t`` subtracts
from a column named ``LIMIT``, but ``SELECT * FROM t LIMIT -1`` is the clause.

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
