SET CATALOG
===========

.. contents::

Syntax
------

.. code-block:: text

  SET CATALOG <expr>

``SET CATALOG`` changes the currently selected catalog.

The default catalog depends on the first database file opened and does not
change if other databases are attached.

The name of a catalog is based on the file path using the paths base name up to
the first ``.``. So, if the complete file path is ``/tmp/mydb.cool.vsql`` the
``CURRENT_CATALOG`` would be ``mydb``.

``CURRENT_CATALOG`` can be used in expressions to get the currently selected
schema.

The catalog must exists for ``SET CATALOG`` to succeed.

Examples
--------

.. code-block:: sql

   VALUES CURRENT_CATALOG;
   SET CATALOG 'foo';
   VALUES CURRENT_CATALOG;
   -- COL1: mydb
   -- msg: SET CATALOG 1
   -- COL1: foo
