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

The value is a character string (otherwise it's ``42804``), and spaces around it
are ignored.

The SQL standard treats the value as an identifier, so ``'mydb'`` would always
mean ``MYDB``. However, a catalog name comes from a file path, so it often isn't
an identifier, such as ``:memory:`` or a lower case name. So vsql looks for a
catalog with exactly that name first, and only then treats the value as an
identifier:

- ``'mydb'`` selects ``mydb`` if it exists, otherwise ``MYDB``.
- ``'MYDB'`` and ``'"MYDB"'`` select ``MYDB``.
- ``'"mydb"'`` selects ``mydb``.

This is only different to the standard when ``mydb`` and ``MYDB`` are both
attached, where the standard would have ``'mydb'`` select ``MYDB``.

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
