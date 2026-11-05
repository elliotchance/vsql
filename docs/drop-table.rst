DROP TABLE
==========

.. contents::

Syntax
------

.. code-block:: text

  DROP TABLE [ IF EXISTS ] <table_name> [ CASCADE | RESTRICT ]

Deletes a table, including all of its rows.

``RESTRICT`` returns an error ``2BP01`` (and takes no action) if any other
object depends on the table. ``CASCADE`` also drops the objects that depend on
the table. The only objects that can depend on a table are the
``FOREIGN KEY`` constraints of other tables that reference it (see
:doc:`create-table`), so ``CASCADE`` drops those constraints, but not the
other tables or their rows.

The SQL standard requires one of ``CASCADE`` or ``RESTRICT``, but vsql also
allows neither, which is the same as ``RESTRICT``.

With ``IF EXISTS``, a table that doesn't exist isn't an error. Nothing changes,
and the result is ``DROP TABLE 0``. That includes a table in a schema that doesn't
exist, but a catalog that doesn't exist is still an error. If the table exists,
it's the same as ``DROP TABLE``, including ``CASCADE``, ``RESTRICT`` and their
errors.

``IF EXISTS`` is a vsql extension, not standard SQL. It's flagged as ``V104-02``
(see :doc:`sql-flagging`).

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
