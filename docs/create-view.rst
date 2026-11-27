CREATE VIEW
===========

.. contents::

Syntax
------

.. code-block:: text

  CREATE VIEW <view_name> [ ( <column_name> , ... ) ] AS <query>

  CREATE RECURSIVE VIEW <view_name> ( <column_name> , ... ) AS <query>

Create a view, which is a query with a name. A view can be read anywhere that
a table can, such as in a ``SELECT``, a join or a subquery, and it can be read
by another view. Its rows aren't stored: the query is run each time the view is
read, so it always sees the rows of the tables as they are at that time.

The query can be any query, including one with a ``GROUP BY`` (a grouped view,
which can be read like any other table) or one that combines queries with
``UNION``, ``EXCEPT`` or ``INTERSECT``. It can end with an ``ORDER BY``, ``OFFSET`` and
``FETCH FIRST`` (or ``LIMIT``) to pick which rows are in the view, such as the
ten most recent. A query that reads the view needs its own ``ORDER BY`` if it
needs the rows in order.

The columns of the view have the names of the columns of the query, unless a
list of column names is given. Each column must have its own name, and the list
must have one name for each column of the query.

The names in the query are resolved in the schema of the view, both when the
view is created and when it's read, so a view means the same thing whatever the
current schema is. The query is kept exactly as it was written.

A ``RECURSIVE`` view can read itself. It's the same as a view of a
``WITH RECURSIVE`` query (see :doc:`select`) with the same name and columns, so
it must have a list of column names, and it's kept as that query:

.. code-block:: sql

  CREATE RECURSIVE VIEW countdown (n) AS
    VALUES 3 UNION ALL SELECT n - 1 FROM countdown WHERE n > 1;

  -- Is kept as:
  CREATE VIEW countdown (n) AS
    WITH RECURSIVE countdown (n) AS (VALUES 3 UNION ALL SELECT n - 1 FROM countdown WHERE n > 1)
    SELECT * FROM countdown;

The columns of a view are fixed when it's created. If the query reads a table
with ``*`` and the table has columns added later, the view still only has the
columns that it was created with.

A view can also be created by a :doc:`create-schema`.

Limitations
-----------

- A view can only be read. ``INSERT``, ``UPDATE`` and ``DELETE`` on a view are
  an error.
- The tables, views and columns that a view uses can only be dropped with
  ``CASCADE``, which drops the view too, and a column that it uses can't change
  its type. A view that can't be read (such as when a column it uses becomes
  ambiguous because another table it reads has a column with the same name)
  doesn't use anything, so they can be dropped. The view is then an error when
  it's read.
- The query can't have a ``?`` parameter or ``NEXT VALUE FOR``.
- ``WITH CHECK OPTION`` isn't supported.

Examples
--------

.. code-block:: sql

   CREATE TABLE products (name VARCHAR(20), price DECIMAL(10, 2));
   INSERT INTO products (name, price) VALUES ('Bread', 2.50), ('Cheese', 7.00);
   CREATE VIEW expensive (product) AS SELECT name FROM products WHERE price > 5;
   SELECT * FROM expensive;
   -- msg: CREATE TABLE 1
   -- msg: INSERT 2
   -- msg: CREATE VIEW 1
   -- PRODUCT: Cheese

See Also
--------

- :doc:`drop-view`
- :doc:`select`
