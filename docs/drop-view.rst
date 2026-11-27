DROP VIEW
=========

.. contents::

Syntax
------

.. code-block:: text

  DROP VIEW <view_name> [ CASCADE | RESTRICT ]

Delete a view. The tables that it reads aren't changed.

``RESTRICT`` returns an error ``2BP01`` (and takes no action) if any other
object depends on the view. ``CASCADE`` also drops the objects that depend on
the view. The only objects that can depend on a view are the views that read it
(see ``VIEW_TABLE_USAGE`` in :doc:`information-schema`), so ``CASCADE`` drops
those, and the views that read them.

The SQL standard requires one of ``CASCADE`` or ``RESTRICT``, but vsql also
allows neither, which is the same as ``RESTRICT``. That's flagged as
``V119-01`` (see :doc:`sql-flagging`).

Use :doc:`drop-table` for a table. ``DROP SCHEMA ... CASCADE`` (see
:doc:`drop-schema`) also drops the views in the schema.

Examples
--------

.. code-block:: sql

   CREATE TABLE products (name VARCHAR(20));
   CREATE VIEW names AS SELECT name FROM products;
   DROP VIEW names RESTRICT;
   -- msg: CREATE TABLE 1
   -- msg: CREATE VIEW 1
   -- msg: DROP VIEW 1

See Also
--------

- :doc:`create-view`
