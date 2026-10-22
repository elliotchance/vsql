DROP TABLE
==========

.. contents::

Syntax
------

.. code-block:: text

  DROP TABLE <table_name>

Deletes a table, including all of its rows.

Examples
--------

.. code-block:: sql

  CREATE TABLE products (name VARCHAR(50));
  DROP TABLE products;
  SELECT * FROM products;
  -- msg: CREATE TABLE 1
  -- msg: DROP TABLE 1
  -- error 42P01: no such table: ":memory:".PUBLIC.PRODUCTS

See Also
--------

- :doc:`create-table`
