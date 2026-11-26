CREATE VIEW
===========

.. contents::

Syntax
------

.. code-block:: text

  CREATE VIEW <view_name> [ ( <column_name> , ... ) ] AS <query>

Create a view, which is a query with a name. A view can be read anywhere that
a table can, such as in a ``SELECT``, a join or a subquery, and it can be read
by another view. Its rows aren't stored: the query is run each time the view is
read, so it always sees the rows of the tables as they are at that time.

The columns of the view have the names of the columns of the query, unless a
list of column names is given. Each column must have its own name, and the list
must have one name for each column of the query.

The names in the query are resolved in the schema of the view, both when the
view is created and when it's read, so a view means the same thing whatever the
current schema is. The query is kept exactly as it was written.

The columns of a view are fixed when it's created. If the query reads a table
with ``*`` and the table has columns added later, the view still only has the
columns that it was created with.

A view can also be created by a :doc:`create-schema`.

Limitations
-----------

- A view can only be read. ``INSERT``, ``UPDATE`` and ``DELETE`` on a view are
  an error.
- Nothing records which tables and views a view reads, so they can be dropped or
  changed while it uses them. The view is then an error when it's read.
- The query can't have a ``?`` parameter or ``NEXT VALUE FOR``, and it can't
  end with an ``ORDER BY``, ``OFFSET`` or ``FETCH FIRST`` (or ``LIMIT``).
- ``RECURSIVE`` and ``WITH CHECK OPTION`` aren't supported.
- Views are in the ``TABLES``, ``VIEWS`` and ``COLUMNS`` views of the
  ``INFORMATION_SCHEMA``, but not the views that describe what a view uses
  (such as ``VIEW_TABLE_USAGE``) yet.

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
