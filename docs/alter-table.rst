ALTER TABLE
===========

.. contents::

Syntax
------

.. code-block:: text

  ALTER TABLE <table_name> <action>

  <action> :=
      ADD [ COLUMN ] <column_definition>
    | ALTER [ COLUMN ] <column_name> SET DEFAULT <default>
    | ALTER [ COLUMN ] <column_name> DROP DEFAULT

  <column_definition> := <column_name> <data_type> [ DEFAULT <default> ]
                         [ [ CONSTRAINT <constraint_name> ] <column_constraint> ... ]

ADD COLUMN
----------

Adds a column to a table, after its other columns. The column is defined the
same way as a column of a :doc:`create-table`, with the same rules for its
name, ``DEFAULT`` and constraints.

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
- A ``REFERENCES`` column with a ``DEFAULT`` (that isn't ``NULL``) is an
  error ``23503`` if the default doesn't reference a row, unless the table is
  empty.

ALTER COLUMN
------------

``SET DEFAULT`` sets (or replaces) the ``DEFAULT`` of a column. It's checked
the same way as the ``DEFAULT`` of a column of a :doc:`create-table`, such as
``DEFAULT 'x'`` not being valid for an ``INTEGER`` (an error ``42601``).

``DROP DEFAULT`` removes the ``DEFAULT`` of a column, so its default is
``NULL``. It's an error ``42601`` if the column doesn't have a ``DEFAULT``,
although ``DEFAULT NULL`` can be dropped.

Only the definition of the table is changed. The existing rows keep their
values, and the new default is used by the rows that are inserted after it.
Changing the type of a column, or whether it's ``NOT NULL``, isn't supported
yet.

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

.. code-block:: sql

  CREATE TABLE products (name VARCHAR(50), quantity INTEGER);
  INSERT INTO products (name) VALUES ('Bread');
  ALTER TABLE products ALTER COLUMN quantity SET DEFAULT 1;
  INSERT INTO products (name) VALUES ('Milk');
  SELECT * FROM products;
  -- msg: CREATE TABLE 1
  -- msg: INSERT 1
  -- msg: ALTER TABLE 1
  -- msg: INSERT 1
  -- NAME: Bread QUANTITY: NULL
  -- NAME: Milk QUANTITY: 1

See Also
--------

- :doc:`create-table`
- :doc:`drop-table`
