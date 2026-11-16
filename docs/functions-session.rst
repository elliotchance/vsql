Session Functions
=================

.. contents::
   :local:
   :depth: 1

Session functions return information about the current connection. There are
no parentheses after their names.

.. _function-current_catalog:

CURRENT_CATALOG
^^^^^^^^^^^^^^^

.. code-block:: sql

   CURRENT_CATALOG CHARACTER VARYING

``CURRENT_CATALOG`` is the name of the current catalog, which is the file name
up to the first ``.``. So, if the complete file path is ``/tmp/mydb.cool.vsql``
the ``CURRENT_CATALOG`` would be ``mydb``. It can be changed with
:doc:`set-catalog`.

When using in-memory databases, the ``CURRENT_CATALOG`` will be ``:memory:``.

**Examples**

.. code-block:: sql

  VALUES CURRENT_CATALOG;
  -- COL1: :memory:

**Compatibility**

- **SQL standard:** F762 (CURRENT_CATALOG).
- **Other databases:**

  - PostgreSQL: ``CURRENT_CATALOG`` or ``CURRENT_DATABASE()``.
  - SQL Server: ``DB_NAME()``.
  - MySQL, SQLite and Oracle have no catalogs.

.. _function-current_schema:

CURRENT_SCHEMA
^^^^^^^^^^^^^^

.. code-block:: sql

   CURRENT_SCHEMA CHARACTER VARYING

``CURRENT_SCHEMA`` reports the current schema. The current schema is where
objects (such as tables, sequences, etc) are located or created when their name
doesn't include a schema. The default schema is ``PUBLIC``. The current schema
can be changed with :doc:`set-schema`.

**Examples**

.. code-block:: sql

  VALUES CURRENT_SCHEMA;
  -- COL1: PUBLIC

**Compatibility**

- **SQL standard:** F763 (CURRENT_SCHEMA).
- **Other databases:**

  - PostgreSQL: ``CURRENT_SCHEMA``.
  - MySQL: ``DATABASE()`` (a MySQL database is a schema).
  - SQL Server: ``SCHEMA_NAME()``.
  - Oracle: ``SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')``.
  - SQLite has no schemas.
