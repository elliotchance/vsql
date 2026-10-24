DROP TABLE
==========

.. contents::

Syntax
------

.. code-block:: text

  DROP TABLE <table_name> [ CASCADE | RESTRICT ]

Deletes a table, including all of its rows.

``RESTRICT`` returns an error (and takes no action) if any other object depends
on the table. ``CASCADE`` also drops the objects that depend on the table.
Nothing can depend on a table yet (such as a view or a foreign key), so they are
currently the same.

The SQL standard requires one of ``CASCADE`` or ``RESTRICT``, but vsql also
allows neither, which is the same as ``RESTRICT``.

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

- :doc:`alter-table`
- :doc:`create-table`
