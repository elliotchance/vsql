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

Updatable Views
^^^^^^^^^^^^^^^

A view can be changed by :doc:`insert`, :doc:`update` and :doc:`delete` (and
through a cursor, see :doc:`cursors`) when it's updatable, which is when
its query:

- reads one table, which is a base table or another updatable view,
- has each column of the view as a different column of that table (not an
  expression),
- doesn't have ``DISTINCT``, ``GROUP BY``, ``HAVING``, an aggregate function,
  ``UNION``, ``EXCEPT``, ``INTERSECT``, ``OFFSET`` or ``FETCH FIRST``, and
- doesn't read the same table in a subquery of its ``WHERE``.

The change is made to the base table that the view reads (through any other
views). ``INSERT`` adds the rows to the table, and the columns of the table that
aren't in the view get their default. ``UPDATE`` and ``DELETE`` only change the
rows that are seen through the view:

.. code-block:: sql

  CREATE TABLE products (name VARCHAR(20), price DECIMAL(10, 2), stock INT DEFAULT 0);
  CREATE VIEW cheap (product, price) AS SELECT name, price FROM products WHERE price < 5;
  INSERT INTO cheap VALUES ('Bread', 2.50), ('Caviar', 99.00);
  UPDATE cheap SET price = price * 2;
  DELETE FROM cheap WHERE product = 'Caviar';
  SELECT * FROM products;
  -- msg: CREATE TABLE 1
  -- msg: CREATE VIEW 1
  -- msg: INSERT 2
  -- msg: UPDATE 1
  -- warning 02000: no data
  -- msg: DELETE 0
  -- NAME: Bread PRICE: 5.00 STOCK: 0
  -- NAME: Caviar PRICE: 99.00 STOCK: 0

A new row doesn't have to be seen through the view (``Caviar`` above), because
``WITH CHECK OPTION`` isn't supported yet.

Limitations
-----------

- A view of a derived table or a ``WITH`` query isn't updatable, nor is a view of
  a join or a ``UNION`` (Feature T111).
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
