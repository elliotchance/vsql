DROP INDEX
==========

.. contents::

Syntax
------

.. code-block:: text

  DROP INDEX <index_name>

Delete an index. The name can be qualified by the schema (and catalog) of the
index, which is the schema of its table.

An index is also dropped with its table (including by ``DROP SCHEMA ...
CASCADE``). A column that's in an index can only be dropped with ``ALTER TABLE
... DROP COLUMN ... CASCADE``, which drops the index.

``DROP INDEX`` is a vsql extension, not standard SQL. It's flagged as
``V003-01`` (see :doc:`sql-flagging`).

Examples
--------

.. code-block:: sql

   CREATE TABLE products (id INT PRIMARY KEY, name VARCHAR(50));
   CREATE INDEX products_name ON products (name);
   DROP INDEX products_name;
   -- msg: CREATE TABLE 1
   -- msg: CREATE INDEX 1
   -- msg: DROP INDEX 1

See Also
--------

- :doc:`create-index`
