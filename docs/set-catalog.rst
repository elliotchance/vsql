SET CATALOG
===========

.. contents::

Syntax
------

.. code-block:: text

  SET CATALOG <expr>

``SET CATALOG`` changes the currently selected catalog.

A catalog is a database file. A connection starts with the catalog of the file
that it opened, and more files can be attached as other catalogs, with
``Connection.add_catalog()`` in V or by passing more files to ``vsql cli`` (see
:doc:`cli`).

The name of a catalog is based on the file path using the path's base name up to
the first ``.``. So, if the complete file path is ``/tmp/mydb.cool.vsql`` the
catalog would be ``mydb``. The catalog of an in-memory database is
``:memory:``.

``CURRENT_CATALOG`` can be used in expressions to get the currently selected
catalog.

The catalog must exist for ``SET CATALOG`` to succeed, otherwise it's an error
``3D000``.

A table, schema or sequence in another catalog can also be used without
changing the current catalog by qualifying its name with the catalog, such as
``foo.public.products``.

Examples
--------

With ``mydb.vsql`` opened, and ``foo.vsql`` attached:

.. code-block:: text

   VALUES CURRENT_CATALOG;
   SET CATALOG 'foo';
   VALUES CURRENT_CATALOG;
   -- COL1: mydb
   -- msg: SET CATALOG 1
   -- COL1: foo

See Also
--------

- :doc:`set-schema`
- :doc:`start-transaction` (for transactions across catalogs)
