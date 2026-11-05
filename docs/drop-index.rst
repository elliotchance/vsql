DROP INDEX
==========

.. contents::

Syntax
------

.. code-block:: text

  DROP INDEX [ IF EXISTS ] <index_name>

Delete an index. The name can be qualified by the schema (and catalog) of the
index, which is the schema of its table.

An index is also dropped with its table (including by ``DROP SCHEMA ...
CASCADE``). A column that's in an index can only be dropped with ``ALTER TABLE
... DROP COLUMN ... CASCADE``, which drops the index.

The index of a ``UNIQUE`` constraint can't be dropped, it's dropped with the
constraint. Neither can the only index that a ``FOREIGN KEY`` can use (see
:doc:`create-index`). Both are a ``2BP01`` error.

With ``IF EXISTS``, an index that doesn't exist isn't an error. Nothing
changes, and the result is ``DROP INDEX 0``. That includes an index in a schema
that doesn't exist, but a catalog that doesn't exist is still an error.

``DROP INDEX`` is a vsql extension, not standard SQL. It's flagged as
``V003-01``, and ``IF EXISTS`` as ``V003-02`` (see :doc:`sql-flagging`).

Examples
--------

.. code-block:: sql

   CREATE TABLE products (id INT PRIMARY KEY, name VARCHAR(50));
   CREATE INDEX products_name ON products (name);
   DROP INDEX products_name;
   DROP INDEX IF EXISTS products_name;
   -- msg: CREATE TABLE 1
   -- msg: CREATE INDEX 1
   -- msg: DROP INDEX 1
   -- msg: DROP INDEX 0

See Also
--------

- :doc:`create-index`
