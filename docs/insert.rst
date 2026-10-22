INSERT
======

.. contents::

Syntax
------

.. code-block:: text

  INSERT INTO <table_name> ( <column_name> , ... )
  VALUES ( <value> , ... ) , ...

Each row in ``VALUES`` must have the same number of values as there are
columns. Columns that aren't listed are ``NULL``, which is an error ``23502``
for a ``NOT NULL`` column.

The values are converted to the types of the columns. For example, a number
that's too large for the column is an error ``22003``, and a string that's too
long is an error ``22001``.

The result (such as ``INSERT 2``) contains the number of rows inserted.

Examples
--------

.. code-block:: sql

  CREATE TABLE products (title VARCHAR(50), price NUMERIC(10, 2));
  INSERT INTO products (title, price) VALUES ('Instant Pot', 144.89);
  INSERT INTO products (title, price) VALUES ('Kettle', 30), ('Toaster', 25.5);
  SELECT * FROM products;
  -- msg: CREATE TABLE 1
  -- msg: INSERT 1
  -- msg: INSERT 2
  -- TITLE: Instant Pot PRICE: 144.89
  -- TITLE: Kettle PRICE: 30.00
  -- TITLE: Toaster PRICE: 25.50

See Also
--------

- :doc:`delete`
- :doc:`update`
