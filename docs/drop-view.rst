DROP VIEW
=========

.. contents::

Syntax
------

.. code-block:: text

  DROP VIEW <view_name> [ CASCADE | RESTRICT ]

Deletes a view (see :doc:`create-view`). The tables that it reads aren't
changed.

``RESTRICT`` returns an error ``2BP01`` (and takes no action) if another view
reads the view. ``CASCADE`` also drops those views (and the views that read
them).

The SQL standard requires one of ``CASCADE`` or ``RESTRICT``, but vsql also
allows neither, which is the same as ``RESTRICT``. That's a vsql extension,
flagged as ``V120-01`` (see :doc:`sql-flagging`).

A base table can't be dropped with ``DROP VIEW``, and a view can't be dropped
with ``DROP TABLE``.

Examples
--------

.. code-block:: sql

  CREATE TABLE products (name VARCHAR(50));
  CREATE VIEW product_names AS SELECT name FROM products;
  DROP VIEW product_names RESTRICT;
  SELECT * FROM product_names;
  -- msg: CREATE TABLE 1
  -- msg: CREATE VIEW 1
  -- msg: DROP VIEW 1
  -- error 42P01: no such table: ":memory:".PUBLIC.PRODUCT_NAMES

See Also
--------

- :doc:`create-view`
- :doc:`drop-table`
