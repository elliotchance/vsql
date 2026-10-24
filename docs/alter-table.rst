ALTER TABLE
===========

.. contents::

Syntax
------

.. code-block:: text

  ALTER TABLE <table_name> ADD [ COLUMN ] <column_definition>

  <column_definition> := <column_name> <data_type> [ DEFAULT <default> ]
                         [ <column_constraint> ... ]

Adds a column to a table, after its other columns. The column is defined the
same way as a column of a :doc:`create-table`, with the same rules for its
name, ``DEFAULT`` and constraints. ``ADD COLUMN`` is the only change that's
supported.

Every existing row gets the ``DEFAULT`` of the new column, which is ``NULL``
if the column doesn't have one. A default such as ``CURRENT_TIMESTAMP`` is
evaluated once, so all of the existing rows get the same value.

The existing rows must satisfy the constraints of the new column, otherwise the
column isn't added:

- A ``NOT NULL`` column without a ``DEFAULT`` (an error ``23502``) can only be
  added to an empty table.
- A ``CHECK`` that's ``FALSE`` for the default is an error ``23514``, unless
  the table is empty.
- A column can only be the ``PRIMARY KEY`` if the table doesn't have one yet
  (an error ``42601``). Every existing row gets the same default, so it's an
  error ``23505`` if there's more than one row.
- A ``UNIQUE`` column with a ``DEFAULT`` (that isn't ``NULL``) is an error
  ``23505`` if there's more than one row, for the same reason.

Examples
--------

.. code-block:: sql

  CREATE TABLE products (name VARCHAR(50));
  INSERT INTO products (name) VALUES ('Bread');
  ALTER TABLE products ADD COLUMN price NUMERIC(10, 2);
  ALTER TABLE products ADD COLUMN quantity INTEGER DEFAULT 1 NOT NULL;
  SELECT * FROM products;
  -- msg: CREATE TABLE 1
  -- msg: INSERT 1
  -- msg: ALTER TABLE 1
  -- msg: ALTER TABLE 1
  -- NAME: Bread PRICE: NULL QUANTITY: 1

See Also
--------

- :doc:`create-table`
- :doc:`drop-table`
