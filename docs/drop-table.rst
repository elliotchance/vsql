DROP TABLE
==========

.. contents::

Syntax
------

.. code-block:: text

  DROP TABLE <table_name> [ CASCADE | RESTRICT ]

Deletes a table, including all of its rows.

``RESTRICT`` returns an error ``2BP01`` (and takes no action) if any other
object depends on the table. ``CASCADE`` also drops the objects that depend on
the table. The only objects that can depend on a table are the
``FOREIGN KEY`` constraints of other tables that reference it (see
:doc:`create-table`), so ``CASCADE`` drops those constraints, but not the
other tables or their rows.

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
